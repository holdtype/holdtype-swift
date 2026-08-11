@preconcurrency import AVFoundation
import Foundation

nonisolated struct DevVlogsLibraryMediaProbeResult: Equatable, Sendable {
    let isPlayable: Bool
    let duration: TimeInterval
    let byteCount: Int64
}

actor DevVlogsLibraryRepository {
    private struct ReviewPreference: Codable {
        let schemaVersion: Int
        let clipID: UUID
        let isExcluded: Bool
    }

    private struct OwnedClipToken {
        let displayedClipID: String
        let resourceIdentity: DevVlogsClipResourceIdentity
        let metadata: DevVlogsClipMetadata
    }

    private struct GroupKey: Hashable {
        let dayKey: String
        let appFolder: String
    }

    private struct LoadedClip {
        let key: GroupKey
        var clip: DevVlogsLibraryClip
        var token: OwnedClipToken?
    }

    private let fileManager: FileManager
    private let maximumProbeWait: Duration
    private let mediaProbe: @Sendable (URL) async throws -> DevVlogsLibraryMediaProbeResult
    private var tokens: [String: OwnedClipToken] = [:]

    init(
        fileManager: FileManager = .default,
        maximumProbeWait: Duration = .seconds(10),
        mediaProbe: (@Sendable (URL) async throws -> DevVlogsLibraryMediaProbeResult)? = nil
    ) {
        self.fileManager = fileManager
        self.maximumProbeWait = maximumProbeWait
        self.mediaProbe = mediaProbe ?? Self.probeMedia
    }

    func load(rootURL: URL, calendar: Calendar = .current) async throws -> DevVlogsLibrarySnapshot {
        let root = rootURL.standardizedFileURL
        guard DevVlogsFileIdentity.capture(at: root, kind: .directory) != nil else {
            throw DevVlogsLibraryError.archiveUnreadable
        }
        var loaded: [LoadedClip] = []
        for yearURL in try directoryChildren(at: root) where isYear(yearURL.lastPathComponent) {
            for dayURL in try directoryChildren(at: yearURL) where isDay(dayURL.lastPathComponent) {
                guard dayURL.lastPathComponent.hasPrefix(yearURL.lastPathComponent + "-") else { continue }
                let appsURL = dayURL.appendingPathComponent("apps", isDirectory: true)
                for appURL in (try? directoryChildren(at: appsURL)) ?? [] {
                    let clipsURL = appURL.appendingPathComponent("clips", isDirectory: true)
                    for clipDirectoryURL in (try? directoryChildren(at: clipsURL)) ?? [] {
                        try Task.checkCancellation()
                        loaded.append(try await loadClip(
                            rootURL: root,
                            yearKey: yearURL.lastPathComponent,
                            dayKey: dayURL.lastPathComponent,
                            appFolder: appURL.lastPathComponent,
                            directoryURL: clipDirectoryURL
                        ))
                    }
                }
            }
        }

        let duplicateIDs = Set(
            Dictionary(grouping: loaded.compactMap { $0.token?.metadata.clipID }, by: { $0 })
                .filter { $0.value.count > 1 }
                .keys
        )
        for index in loaded.indices {
            guard let token = loaded[index].token,
                  duplicateIDs.contains(token.metadata.clipID) else { continue }
            loaded[index].clip = duplicateClip(from: loaded[index].clip)
            loaded[index].token = nil
        }

        var grouped: [GroupKey: [DevVlogsLibraryClip]] = [:]
        var refreshedTokens: [String: OwnedClipToken] = [:]
        for item in loaded {
            grouped[item.key, default: []].append(item.clip)
            if let token = item.token {
                refreshedTokens[token.displayedClipID] = token
            }
        }
        tokens = refreshedTokens
        return DevVlogsLibrarySnapshot(days: makeDays(grouped: grouped, calendar: calendar))
    }

    func setExcluded(_ isExcluded: Bool, clipID: UUID, rootURL: URL) throws {
        let token = try validatedToken(clipID: clipID, displayedClipID: nil, rootURL: rootURL)
        let reviewURL = token.resourceIdentity.reviewURL
        if fileManager.fileExists(atPath: reviewURL.path),
           DevVlogsFileIdentity.capture(
               at: reviewURL,
               kind: .regularFile,
               requireSingleLink: true
           ) == nil {
            throw DevVlogsLibraryError.exclusionUpdateFailed
        }
        let preference = ReviewPreference(schemaVersion: 1, clipID: clipID, isExcluded: isExcluded)
        do {
            try encoder.encode(preference).write(to: reviewURL, options: .atomic)
        } catch {
            throw DevVlogsLibraryError.exclusionUpdateFailed
        }
    }

    func delete(
        clipID: UUID,
        displayedClipID: String,
        resourceIdentity: DevVlogsClipResourceIdentity,
        rootURL: URL
    ) throws {
        let token = try validatedToken(
            clipID: clipID,
            displayedClipID: displayedClipID,
            rootURL: rootURL
        )
        guard token.resourceIdentity == resourceIdentity,
              resourceIdentity.validateAllExpectedChildren(fileManager: fileManager) else {
            throw DevVlogsLibraryError.identityChanged
        }

        let orderedFiles = resourceIdentity.reviewIdentity == nil
            ? [resourceIdentity.metadataURL, resourceIdentity.mediaURL]
            : [resourceIdentity.reviewURL, resourceIdentity.metadataURL, resourceIdentity.mediaURL]
        do {
            for url in orderedFiles {
                let expected: DevVlogsFileIdentity
                switch url.lastPathComponent {
                case "review.json": expected = try required(resourceIdentity.reviewIdentity)
                case "metadata.json": expected = resourceIdentity.metadataIdentity
                default: expected = resourceIdentity.mediaIdentity
                }
                guard expected.matches(url, requireSingleLink: true),
                      resourceIdentity.validateHierarchy() else {
                    throw DevVlogsLibraryError.identityChanged
                }
                try fileManager.removeItem(at: url)
            }
            guard resourceIdentity.validateHierarchy(),
                  (try fileManager.contentsOfDirectory(atPath: resourceIdentity.directoryURL.path)).isEmpty else {
                throw DevVlogsLibraryError.identityChanged
            }
            try fileManager.removeItem(at: resourceIdentity.directoryURL)
            tokens.removeValue(forKey: displayedClipID)
        } catch let error as DevVlogsLibraryError {
            throw error
        } catch {
            throw DevVlogsLibraryError.deleteFailed
        }
    }

    private func loadClip(
        rootURL: URL,
        yearKey: String,
        dayKey: String,
        appFolder: String,
        directoryURL: URL
    ) async throws -> LoadedClip {
        let relativeDirectory = [yearKey, dayKey, "apps", appFolder, "clips", directoryURL.lastPathComponent]
            .joined(separator: "/")
        let key = GroupKey(dayKey: dayKey, appFolder: appFolder)
        let metadataURL = directoryURL.appendingPathComponent("metadata.json")
        guard let metadataIdentity = DevVlogsFileIdentity.capture(
            at: metadataURL,
            kind: .regularFile,
            requireSingleLink: true
        ),
            let data = try? Data(contentsOf: metadataURL),
            metadataIdentity.matches(metadataURL, requireSingleLink: true),
            let metadata = try? decoder.decode(DevVlogsClipMetadata.self, from: data),
            metadata.schemaVersion == 1,
            metadata.clipID == metadata.attemptID,
            appFolder == DevVlogsArchiveNaming.appFolder(
                displayName: metadata.triggerApplicationName,
                bundleIdentifier: metadata.triggerBundleIdentifier
            ),
            validClipDirectoryName(directoryURL.lastPathComponent, clipID: metadata.clipID) else {
            return LoadedClip(
                key: key,
                clip: invalidClip(relativeDirectory: relativeDirectory, appFolder: appFolder),
                token: nil
            )
        }

        let mediaURL = directoryURL.appendingPathComponent("clip.mov")
        guard fileManager.fileExists(atPath: mediaURL.path) else {
            return LoadedClip(
                key: key,
                clip: clip(
                    from: metadata,
                    mediaURL: nil,
                    relativeDirectory: relativeDirectory,
                    health: .missing,
                    resourceIdentity: nil
                ),
                token: nil
            )
        }
        let reviewURL = directoryURL.appendingPathComponent("review.json")
        let reviewExists = fileManager.fileExists(atPath: reviewURL.path)
        guard let resourceIdentity = DevVlogsClipResourceIdentity.capture(
            rootURL: rootURL,
            relativeDirectory: relativeDirectory,
            reviewExists: reviewExists
        ) else {
            return LoadedClip(
                key: key,
                clip: clip(
                    from: metadata,
                    mediaURL: nil,
                    relativeDirectory: relativeDirectory,
                    health: .invalid,
                    resourceIdentity: nil
                ),
                token: nil
            )
        }

        let mediaState: DevVlogsLibraryMediaProbeResult
        do {
            mediaState = try await boundedMediaProbe(at: mediaURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return LoadedClip(
                key: key,
                clip: clip(
                    from: metadata,
                    mediaURL: nil,
                    relativeDirectory: relativeDirectory,
                    health: .invalid,
                    actualByteCount: resourceIdentity.mediaIdentity.size,
                    resourceIdentity: nil
                ),
                token: nil
            )
        }
        guard mediaState.isPlayable, resourceIdentity.validateSourceAndMetadata() else {
            return LoadedClip(
                key: key,
                clip: clip(
                    from: metadata,
                    mediaURL: nil,
                    relativeDirectory: relativeDirectory,
                    health: .invalid,
                    actualByteCount: mediaState.byteCount,
                    resourceIdentity: nil
                ),
                token: nil
            )
        }

        let displayedClipID = "clip:\(relativeDirectory)"
        let token = OwnedClipToken(
            displayedClipID: displayedClipID,
            resourceIdentity: resourceIdentity,
            metadata: metadata
        )
        return LoadedClip(
            key: key,
            clip: clip(
                from: metadata,
                mediaURL: mediaURL,
                relativeDirectory: relativeDirectory,
                health: .ready,
                actualDuration: mediaState.duration,
                actualByteCount: mediaState.byteCount,
                resourceIdentity: resourceIdentity
            ),
            token: token
        )
    }

    private func clip(
        from metadata: DevVlogsClipMetadata,
        mediaURL: URL?,
        relativeDirectory: String,
        health: DevVlogsLibraryHealth,
        actualDuration: TimeInterval? = nil,
        actualByteCount: Int64? = nil,
        resourceIdentity: DevVlogsClipResourceIdentity?
    ) -> DevVlogsLibraryClip {
        DevVlogsLibraryClip(
            id: "clip:\(relativeDirectory)",
            clipID: metadata.clipID,
            createdAt: metadata.createdAt,
            triggerBundleIdentifier: metadata.triggerBundleIdentifier,
            triggerApplicationName: metadata.triggerApplicationName,
            duration: actualDuration ?? metadata.duration,
            byteCount: actualByteCount ?? metadata.byteCount,
            health: health,
            isExcluded: exclusionPreference(in: mediaURL?.deletingLastPathComponent(), clipID: metadata.clipID),
            mediaURL: mediaURL,
            relativeDirectory: relativeDirectory,
            resourceIdentity: resourceIdentity
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
            relativeDirectory: relativeDirectory,
            resourceIdentity: nil
        )
    }

    private func duplicateClip(from clip: DevVlogsLibraryClip) -> DevVlogsLibraryClip {
        DevVlogsLibraryClip(
            id: "duplicate:\(clip.relativeDirectory)",
            clipID: nil,
            createdAt: clip.createdAt,
            triggerBundleIdentifier: clip.triggerBundleIdentifier,
            triggerApplicationName: clip.triggerApplicationName,
            duration: clip.duration,
            byteCount: clip.byteCount,
            health: .invalid,
            isExcluded: true,
            mediaURL: nil,
            relativeDirectory: clip.relativeDirectory,
            resourceIdentity: nil
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
            let groups = keys.map { key -> DevVlogsLibraryAppGroup in
                let clips = (grouped[key] ?? []).sorted(by: clipComesBefore)
                let first = clips.first
                return DevVlogsLibraryAppGroup(
                    id: key.appFolder,
                    displayName: first?.triggerApplicationName ?? key.appFolder,
                    bundleIdentifier: first?.triggerBundleIdentifier,
                    clips: clips
                )
            }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            days.append(DevVlogsLibraryDay(id: dayKey, date: date, appGroups: groups))
        }
        return days.sorted { $0.id > $1.id }
    }

    private func validatedToken(
        clipID: UUID,
        displayedClipID: String?,
        rootURL: URL
    ) throws -> OwnedClipToken {
        let candidates = tokens.values.filter {
            $0.metadata.clipID == clipID && (displayedClipID == nil || $0.displayedClipID == displayedClipID)
        }
        guard candidates.count == 1, let token = candidates.first,
              token.resourceIdentity.rootURL == rootURL.standardizedFileURL else {
            throw DevVlogsLibraryError.clipNotOwned
        }
        guard token.resourceIdentity.validateSourceAndMetadata() else {
            throw DevVlogsLibraryError.identityChanged
        }
        guard let data = try? Data(contentsOf: token.resourceIdentity.metadataURL),
              token.resourceIdentity.metadataIdentity.matches(
                  token.resourceIdentity.metadataURL,
                  requireSingleLink: true
              ),
              let metadata = try? decoder.decode(DevVlogsClipMetadata.self, from: data),
              metadata == token.metadata else {
            throw DevVlogsLibraryError.identityChanged
        }
        return token
    }

    private func boundedMediaProbe(at url: URL) async throws -> DevVlogsLibraryMediaProbeResult {
        try await DevVlogsLibraryProbeGate().wait(timeout: maximumProbeWait) { [mediaProbe] in
            try await mediaProbe(url)
        }
    }

    nonisolated private static func probeMedia(at url: URL) async throws -> DevVlogsLibraryMediaProbeResult {
        let byteCount = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        return DevVlogsLibraryMediaProbeResult(
            isPlayable: playable && videoTracks.count == 1 && audioTracks.count == 1
                && duration.isFinite && duration > 0,
            duration: duration,
            byteCount: byteCount
        )
    }

    private func exclusionPreference(in directoryURL: URL?, clipID: UUID) -> Bool {
        guard let directoryURL else { return true }
        let reviewURL = directoryURL.appendingPathComponent("review.json")
        guard fileManager.fileExists(atPath: reviewURL.path) else { return false }
        guard DevVlogsFileIdentity.capture(
            at: reviewURL,
            kind: .regularFile,
            requireSingleLink: true
        ) != nil,
            let data = try? Data(contentsOf: reviewURL),
            let preference = try? decoder.decode(ReviewPreference.self, from: data),
            preference.schemaVersion == 1,
            preference.clipID == clipID else {
            return true
        }
        return preference.isExcluded
    }

    private func directoryChildren(at url: URL) throws -> [URL] {
        guard DevVlogsFileIdentity.capture(at: url, kind: .directory) != nil else { return [] }
        return try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { DevVlogsFileIdentity.capture(at: $0, kind: .directory) != nil }
    }

    private func validClipDirectoryName(_ value: String, clipID: UUID) -> Bool {
        let suffix = "--\(clipID.uuidString.lowercased())"
        guard value.hasSuffix(suffix) else { return false }
        let time = String(value.dropLast(suffix.count))
        return time.count == 8 && time.enumerated().allSatisfy { index, character in
            index == 2 || index == 5 ? character == "-" : character.isNumber
        }
    }

    private func clipComesBefore(_ lhs: DevVlogsLibraryClip, _ rhs: DevVlogsLibraryClip) -> Bool {
        if let left = lhs.createdAt, let right = rhs.createdAt, left != right { return left < right }
        if lhs.createdAt != nil, rhs.createdAt == nil { return true }
        if lhs.createdAt == nil, rhs.createdAt != nil { return false }
        return lhs.id < rhs.id
    }

    private func required<T>(_ value: T?) throws -> T {
        guard let value else { throw DevVlogsLibraryError.identityChanged }
        return value
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
