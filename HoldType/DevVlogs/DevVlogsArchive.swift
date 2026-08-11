import Foundation

struct DevVlogsArchiveWorkspace: Equatable {
    let rootURL: URL
    let cameraURL: URL
    let audioURL: URL
    let finalizedURL: URL
}

enum DevVlogsArchiveError: Error, Equatable, LocalizedError {
    case preparationFailed
    case publicationFailed

    var errorDescription: String? {
        switch self {
        case .preparationFailed:
            return "The Dev Vlogs destination could not prepare this attempt."
        case .publicationFailed:
            return "The finalized vlog clip could not be saved."
        }
    }
}

@MainActor
protocol DevVlogsArchiving {
    func prepareWorkspace(
        attemptID: UUID,
        destinationURL: URL
    ) throws -> DevVlogsArchiveWorkspace
    func stageAudio(
        from sourceURL: URL,
        into workspace: DevVlogsArchiveWorkspace
    ) throws
    func abandonWorkspaceIfEmpty(_ workspace: DevVlogsArchiveWorkspace)
    func publish(
        snapshot: DevVlogsCaptureSnapshot,
        workspace: DevVlogsArchiveWorkspace,
        media: DevVlogsFinalizedMedia
    ) throws -> DevVlogsPublishedClip
}

@MainActor
final class FileSystemDevVlogsArchive: DevVlogsArchiving {
    private struct ClipMetadata: Codable {
        let schemaVersion: Int
        let clipID: UUID
        let attemptID: UUID
        let createdAt: Date
        let triggerBundleIdentifier: String
        let triggerApplicationName: String
        let cameraID: String
        let cameraName: String
        let duration: TimeInterval
        let byteCount: Int64
        let mediaHealth: String
        let realizedVideoFormat: DevVlogsRealizedVideoFormat
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepareWorkspace(
        attemptID: UUID,
        destinationURL: URL
    ) throws -> DevVlogsArchiveWorkspace {
        let rootURL = destinationURL
            .appendingPathComponent(".holdtype-active", isDirectory: true)
            .appendingPathComponent(attemptID.uuidString.lowercased(), isDirectory: true)
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            throw DevVlogsArchiveError.preparationFailed
        }
        return DevVlogsArchiveWorkspace(
            rootURL: rootURL,
            cameraURL: rootURL.appendingPathComponent("camera.mov"),
            audioURL: rootURL.appendingPathComponent("dictation.m4a"),
            finalizedURL: rootURL.appendingPathComponent("final.mov")
        )
    }

    func stageAudio(
        from sourceURL: URL,
        into workspace: DevVlogsArchiveWorkspace
    ) throws {
        do {
            try fileManager.copyItem(at: sourceURL, to: workspace.audioURL)
        } catch {
            throw DevVlogsArchiveError.preparationFailed
        }
    }

    func abandonWorkspaceIfEmpty(_ workspace: DevVlogsArchiveWorkspace) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: workspace.rootURL,
            includingPropertiesForKeys: nil
        ),
            contents.isEmpty else {
            return
        }
        try? fileManager.removeItem(at: workspace.rootURL)
    }

    func publish(
        snapshot: DevVlogsCaptureSnapshot,
        workspace: DevVlogsArchiveWorkspace,
        media: DevVlogsFinalizedMedia
    ) throws -> DevVlogsPublishedClip {
        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: snapshot.startedAt))
        let day = Self.dayFormatter.string(from: snapshot.startedAt)
        let appFolder = "\(Self.sanitize(snapshot.triggerApplication.displayName))--\(Self.sanitize(snapshot.triggerApplication.bundleIdentifier))"
        let clipsURL = workspace.rootURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(year, isDirectory: true)
            .appendingPathComponent(day, isDirectory: true)
            .appendingPathComponent("apps", isDirectory: true)
            .appendingPathComponent(appFolder, isDirectory: true)
            .appendingPathComponent("clips", isDirectory: true)
        let clipName = "\(Self.timeFormatter.string(from: snapshot.startedAt))--\(snapshot.attemptID.uuidString.lowercased())"
        let clipDirectoryURL = clipsURL.appendingPathComponent(clipName, isDirectory: true)

        guard !fileManager.fileExists(atPath: clipDirectoryURL.path) else {
            throw DevVlogsArchiveError.publicationFailed
        }

        do {
            let clipURL = workspace.rootURL.appendingPathComponent("clip.mov")
            try fileManager.moveItem(at: media.fileURL, to: clipURL)
            try removeIntermediateIfPresent(workspace.cameraURL)
            try removeIntermediateIfPresent(workspace.audioURL)

            let metadata = ClipMetadata(
                schemaVersion: 1,
                clipID: snapshot.attemptID,
                attemptID: snapshot.attemptID,
                createdAt: snapshot.startedAt,
                triggerBundleIdentifier: snapshot.triggerApplication.bundleIdentifier,
                triggerApplicationName: snapshot.triggerApplication.displayName,
                cameraID: snapshot.preferredCamera.id,
                cameraName: snapshot.preferredCamera.label,
                duration: media.duration,
                byteCount: media.byteCount,
                mediaHealth: "playable_1v_1a",
                realizedVideoFormat: media.realizedVideoFormat
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(metadata).write(
                to: workspace.rootURL.appendingPathComponent("metadata.json"),
                options: .atomic
            )
            try fileManager.createDirectory(at: clipsURL, withIntermediateDirectories: true)
            try fileManager.moveItem(at: workspace.rootURL, to: clipDirectoryURL)
            return DevVlogsPublishedClip(
                id: snapshot.attemptID,
                fileURL: clipDirectoryURL.appendingPathComponent("clip.mov")
            )
        } catch {
            throw DevVlogsArchiveError.publicationFailed
        }
    }

    private func removeIntermediateIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return sanitized.isEmpty ? "Unknown" : sanitized
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH-mm-ss"
        return formatter
    }()
}
