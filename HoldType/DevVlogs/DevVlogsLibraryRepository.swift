@preconcurrency import AVFoundation
import Foundation

actor DevVlogsLibraryRepository {
    private struct ReviewPreference: Codable {
        let schemaVersion: Int
        let clipID: UUID
        let isExcluded: Bool
    }

    private struct OwnedClipToken {
        let rootURL: URL
        let directoryURL: URL
        let mediaURL: URL
        let directoryIdentity: FileIdentity
        let mediaIdentity: FileIdentity
        let metadata: DevVlogsClipMetadata
    }

    private struct FileIdentity: Equatable {
        let resourceIdentifier: String
        let fileSize: Int?
        let creationDate: Date?
        let modificationDate: Date?
    }

    private struct GroupKey: Hashable {
        let dayKey: String
        let appFolder: String
    }

    private let fileManager: FileManager
    private var tokens: [UUID: OwnedClipToken] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(rootURL: URL, calendar: Calendar = .current) async throws -> DevVlogsLibrarySnapshot {
        let root = rootURL.standardizedFileURL
        var grouped: [GroupKey: [DevVlogsLibraryClip]] = [:]
        var refreshedTokens: [UUID: OwnedClipToken] = [:]

        for yearURL in try directoryChildren(at: root) where isYear(yearURL.lastPathComponent) {
            for dayURL in try directoryChildren(at: yearURL) where isDay(dayURL.lastPathComponent) {
                let appsURL = dayURL.appendingPathComponent("apps", isDirectory: true)
                for appURL in (try? directoryChildren(at: appsURL)) ?? [] {
                    let clipsURL = appURL.appendingPathComponent("clips", isDirectory: true)
                    for clipDirectoryURL in (try? directoryChildren(at: clipsURL)) ?? [] {
                        let key = GroupKey(
                            dayKey: dayURL.lastPathComponent,
                            appFolder: appURL.lastPathComponent
                        )
                        let result = await loadClip(
                            rootURL: root,
                            yearKey: yearURL.lastPathComponent,
                            dayKey: dayURL.lastPathComponent,
                            appFolder: appURL.lastPathComponent,
                            directoryURL: clipDirectoryURL,
                            calendar: calendar
                        )
                        grouped[key, default: []].append(result.clip)
                        if let token = result.token {
                            refreshedTokens[token.metadata.clipID] = token
                        }
                    }
                }
            }
        }

        tokens = refreshedTokens
        return DevVlogsLibrarySnapshot(days: makeDays(grouped: grouped, calendar: calendar))
    }

    func setExcluded(
        _ isExcluded: Bool,
        clipID: UUID,
        rootURL: URL
    ) throws {
        let token = try validatedToken(clipID: clipID, rootURL: rootURL)
        let reviewURL = token.directoryURL.appendingPathComponent("review.json")
        if fileManager.fileExists(atPath: reviewURL.path), !isRegularFile(reviewURL) {
            throw DevVlogsLibraryError.exclusionUpdateFailed
        }
        let preference = ReviewPreference(
            schemaVersion: 1,
            clipID: clipID,
            isExcluded: isExcluded
        )
        do {
            try encoder.encode(preference).write(to: reviewURL, options: .atomic)
        } catch {
            throw DevVlogsLibraryError.exclusionUpdateFailed
        }
    }

    func delete(clipID: UUID, rootURL: URL) throws {
        let token = try validatedToken(clipID: clipID, rootURL: rootURL)
        let allowedChildren = Set(["clip.mov", "metadata.json", "review.json"])
        let actualChildren = try Set(
            fileManager.contentsOfDirectory(
                at: token.directoryURL,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            ).map(\.lastPathComponent)
        )
        guard actualChildren.isSubset(of: allowedChildren),
              actualChildren.contains("clip.mov"),
              actualChildren.contains("metadata.json") else {
            throw DevVlogsLibraryError.identityChanged
        }

        do {
            try fileManager.removeItem(at: token.directoryURL)
            tokens.removeValue(forKey: clipID)
        } catch {
            throw DevVlogsLibraryError.deleteFailed
        }
    }

    private func loadClip(
        rootURL: URL,
        yearKey: String,
        dayKey: String,
        appFolder: String,
        directoryURL: URL,
        calendar: Calendar
    ) async -> (clip: DevVlogsLibraryClip, token: OwnedClipToken?) {
        let relativeDirectory = [yearKey, dayKey, "apps", appFolder, "clips", directoryURL.lastPathComponent]
            .joined(separator: "/")
        let metadataURL = directoryURL.appendingPathComponent("metadata.json")
        guard isDirectory(directoryURL),
              isRegularFile(metadataURL),
              let data = try? Data(contentsOf: metadataURL),
              let metadata = try? decoder.decode(DevVlogsClipMetadata.self, from: data),
              metadata.schemaVersion == 1,
              metadata.clipID == metadata.attemptID,
              yearKey == DevVlogsArchiveNaming.yearKey(for: metadata.createdAt, calendar: calendar),
              dayKey == DevVlogsArchiveNaming.dayKey(for: metadata.createdAt, calendar: calendar),
              appFolder == DevVlogsArchiveNaming.appFolder(
                displayName: metadata.triggerApplicationName,
                bundleIdentifier: metadata.triggerBundleIdentifier
              ),
              directoryURL.lastPathComponent == DevVlogsArchiveNaming.clipDirectoryName(
                startedAt: metadata.createdAt,
                clipID: metadata.clipID,
                calendar: calendar
              ) else {
            return (invalidClip(relativeDirectory: relativeDirectory, appFolder: appFolder), nil)
        }

        let mediaURL = directoryURL.appendingPathComponent("clip.mov")
        guard fileManager.fileExists(atPath: mediaURL.path) else {
            return (
                clip(from: metadata, mediaURL: nil, relativeDirectory: relativeDirectory, health: .missing),
                nil
            )
        }
        guard isRegularFile(mediaURL),
              let directoryIdentity = fileIdentity(directoryURL),
              let mediaIdentity = fileIdentity(mediaURL) else {
            return (
                clip(from: metadata, mediaURL: nil, relativeDirectory: relativeDirectory, health: .invalid),
                nil
            )
        }

        let mediaState = await validateMedia(at: mediaURL)
        guard mediaState.isPlayable else {
            return (
                clip(
                    from: metadata,
                    mediaURL: nil,
                    relativeDirectory: relativeDirectory,
                    health: .invalid,
                    actualByteCount: mediaState.byteCount
                ),
                nil
            )
        }

        let token = OwnedClipToken(
            rootURL: rootURL,
            directoryURL: directoryURL,
            mediaURL: mediaURL,
            directoryIdentity: directoryIdentity,
            mediaIdentity: mediaIdentity,
            metadata: metadata
        )
        return (
            clip(
                from: metadata,
                mediaURL: mediaURL,
                relativeDirectory: relativeDirectory,
                health: .ready,
                actualDuration: mediaState.duration,
                actualByteCount: mediaState.byteCount
            ),
            token
        )
    }

    private func clip(
        from metadata: DevVlogsClipMetadata,
        mediaURL: URL?,
        relativeDirectory: String,
        health: DevVlogsLibraryHealth,
        actualDuration: TimeInterval? = nil,
        actualByteCount: Int64? = nil
    ) -> DevVlogsLibraryClip {
        DevVlogsLibraryClip(
            id: metadata.clipID.uuidString.lowercased(),
            clipID: metadata.clipID,
            createdAt: metadata.createdAt,
            triggerBundleIdentifier: metadata.triggerBundleIdentifier,
            triggerApplicationName: metadata.triggerApplicationName,
            duration: actualDuration ?? metadata.duration,
            byteCount: actualByteCount ?? metadata.byteCount,
            health: health,
            isExcluded: exclusionPreference(in: mediaURL?.deletingLastPathComponent(), clipID: metadata.clipID),
            mediaURL: mediaURL,
            relativeDirectory: relativeDirectory
        )
    }

    private func invalidClip(relativeDirectory: String, appFolder: String) -> DevVlogsLibraryClip {
        DevVlogsLibraryClip(
            id: "invalid:\(relativeDirectory)",
            clipID: nil,
            createdAt: nil,
            triggerBundleIdentifier: nil,
            triggerApplicationName: appFolder.components(separatedBy: "--").first ?? "Unavailable",
            duration: 0,
            byteCount: 0,
            health: .invalid,
            isExcluded: true,
            mediaURL: nil,
            relativeDirectory: relativeDirectory
        )
    }

    private func makeDays(
        grouped: [GroupKey: [DevVlogsLibraryClip]],
        calendar: Calendar
    ) -> [DevVlogsLibraryDay] {
        let byDay = Dictionary(grouping: grouped.keys, by: \.dayKey)
        var days: [DevVlogsLibraryDay] = []
        for (dayKey, keys) in byDay {
            guard let date = date(from: dayKey, calendar: calendar) else { continue }
            let unsortedAppGroups: [DevVlogsLibraryAppGroup] = keys.map { key in
                let clips = (grouped[key] ?? []).sorted { left, right in
                    if let leftDate = left.createdAt, let rightDate = right.createdAt, leftDate != rightDate {
                        return leftDate < rightDate
                    }
                    return left.id < right.id
                }
                let first = clips.first
                return DevVlogsLibraryAppGroup(
                    id: key.appFolder,
                    displayName: first?.triggerApplicationName ?? key.appFolder,
                    bundleIdentifier: first?.triggerBundleIdentifier,
                    clips: clips
                )
            }
            let appGroups = unsortedAppGroups.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            days.append(DevVlogsLibraryDay(id: dayKey, date: date, appGroups: appGroups))
        }
        return days.sorted { $0.date > $1.date }
    }

    private func validatedToken(clipID: UUID, rootURL: URL) throws -> OwnedClipToken {
        guard let token = tokens[clipID],
              token.rootURL == rootURL.standardizedFileURL else {
            throw DevVlogsLibraryError.clipNotOwned
        }
        guard isDirectory(token.directoryURL), isRegularFile(token.mediaURL) else {
            throw DevVlogsLibraryError.sourceMissing
        }
        guard fileIdentity(token.directoryURL) == token.directoryIdentity,
              fileIdentity(token.mediaURL) == token.mediaIdentity else {
            throw DevVlogsLibraryError.identityChanged
        }
        let metadataURL = token.directoryURL.appendingPathComponent("metadata.json")
        guard isRegularFile(metadataURL),
              let data = try? Data(contentsOf: metadataURL),
              let metadata = try? decoder.decode(DevVlogsClipMetadata.self, from: data),
              metadata == token.metadata else {
            throw DevVlogsLibraryError.identityChanged
        }
        return token
    }

    private func exclusionPreference(in directoryURL: URL?, clipID: UUID) -> Bool {
        guard let directoryURL else { return true }
        let reviewURL = directoryURL.appendingPathComponent("review.json")
        guard !fileManager.fileExists(atPath: reviewURL.path) else {
            guard isRegularFile(reviewURL),
                  let data = try? Data(contentsOf: reviewURL),
                  let preference = try? decoder.decode(ReviewPreference.self, from: data),
                  preference.schemaVersion == 1,
                  preference.clipID == clipID else {
                return true
            }
            return preference.isExcluded
        }
        return false
    }

    private func validateMedia(at url: URL) async -> (isPlayable: Bool, duration: TimeInterval, byteCount: Int64) {
        let byteCount = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration).seconds
            return (
                playable && videoTracks.count == 1 && audioTracks.count == 1 && duration.isFinite && duration > 0,
                duration,
                byteCount
            )
        } catch {
            return (false, 0, byteCount)
        }
    }

    private func directoryChildren(at url: URL) throws -> [URL] {
        guard isDirectory(url) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter(isDirectory)
    }

    private func isDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func fileIdentity(_ url: URL) -> FileIdentity? {
        let keys: Set<URLResourceKey> = [
            .fileResourceIdentifierKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let identifier = values.fileResourceIdentifier,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return FileIdentity(
            resourceIdentifier: String(describing: identifier),
            fileSize: (attributes[.size] as? NSNumber)?.intValue,
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }

    private func isYear(_ value: String) -> Bool {
        value.count == 4 && value.allSatisfy(\.isNumber)
    }

    private func isDay(_ value: String) -> Bool {
        value.count == 10 && value.enumerated().allSatisfy { index, character in
            index == 4 || index == 7 ? character == "-" : character.isNumber
        }
    }

    private func date(from dayKey: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
