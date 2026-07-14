import Foundation
import HoldTypeDomain

public enum IOSAcceptedAudioCacheError: Error, Equatable, Sendable {
    case invalidAudio
    case identifierCollision
    case storageUnavailable
}

/// App-private accepted recording files, independent from text History.
public actor IOSAcceptedAudioCache {
    public static let maximumAudioByteCount = 25_000_000

    private static let filePolicy = ProtectedAtomicMetadataFilePolicy(
        maximumByteCount: maximumAudioByteCount,
        fileProtection: .complete,
        excludesFromBackup: true
    )

    private let directoryURL: URL
    private let fileSystem: any ProtectedAtomicMetadataFileSystem

    public init(applicationSupportDirectoryURL: URL) {
        directoryURL = applicationSupportDirectoryURL
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("RecordingCache", isDirectory: true)
        fileSystem = FoundationProtectedAtomicMetadataFileSystem()
    }

    init(
        directoryURL: URL,
        fileSystem: any ProtectedAtomicMetadataFileSystem =
            FoundationProtectedAtomicMetadataFileSystem()
    ) {
        self.directoryURL = directoryURL
        self.fileSystem = fileSystem
    }

    /// Returns only a regular, non-empty cache file owned by this cache.
    public func cachedAudioFileURLIfAvailable(resultID: UUID) -> URL? {
        let matches = (try? managedFiles())?.filter {
            $0.resultID == resultID
        } ?? []
        guard matches.count == 1 else { return nil }
        return matches[0].url
    }

    /// Applies the current cache policy without inspecting or changing History.
    public func reconcile(policy: RecordingCachePolicy) throws {
        try reconcileUnlocked(policy: policy.normalized)
    }

    @discardableResult
    func retainAcceptedAudio(
        _ data: Data,
        resultID: UUID,
        fileExtension: String,
        createdAt: Date,
        policy: RecordingCachePolicy
    ) throws -> URL? {
        let policy = policy.normalized
        guard policy.keepsRecordings else { return nil }
        guard !data.isEmpty,
              data.count <= Self.maximumAudioByteCount,
              Self.allowedExtensions.contains(fileExtension),
              createdAt.timeIntervalSince1970.isFinite,
              createdAt.timeIntervalSince1970 >= 0 else {
            throw IOSAcceptedAudioCacheError.invalidAudio
        }

        let existing = try managedFiles().filter {
            $0.resultID == resultID
        }
        let destination = fileURL(
            resultID: resultID,
            fileExtension: fileExtension
        )
        if let existingFile = existing.first {
            let existingData = try? fileSystem.readFileIfPresent(
                at: existingFile.url,
                policy: Self.filePolicy
            )
            guard existing.count == 1,
                  existingFile.url.lastPathComponent
                    == destination.lastPathComponent,
                  existingData == data else {
                throw IOSAcceptedAudioCacheError.identifierCollision
            }
            try applyCreationDate(createdAt, to: existingFile.url)
            try reconcileUnlocked(policy: policy)
            return try cachedAudioFileURLIfAvailableUnlocked(
                resultID: resultID
            )
        }

        do {
            try fileSystem.replaceFileAtomically(
                at: destination,
                with: data,
                policy: Self.filePolicy
            )
            try applyCreationDate(createdAt, to: destination)
            try reconcileUnlocked(policy: policy)
            return try cachedAudioFileURLIfAvailableUnlocked(
                resultID: resultID
            )
        } catch let error as IOSAcceptedAudioCacheError {
            throw error
        } catch {
            throw IOSAcceptedAudioCacheError.storageUnavailable
        }
    }

    private func reconcileUnlocked(
        policy: RecordingCachePolicy
    ) throws {
        let files = try managedFiles().sorted(by: Self.isNewer)
        let retainedCount: Int
        switch policy {
        case .deleteImmediately:
            retainedCount = 0
        case .keepLast(let count):
            retainedCount = count
        case .unlimited:
            return
        }

        for file in files.dropFirst(retainedCount) {
            do {
                try fileSystem.removeFileIfPresent(at: file.url)
            } catch {
                throw IOSAcceptedAudioCacheError.storageUnavailable
            }
        }
    }

    private func cachedAudioFileURLIfAvailableUnlocked(
        resultID: UUID
    ) throws -> URL? {
        let matches = try managedFiles().filter {
            $0.resultID == resultID
        }
        guard matches.count == 1 else { return nil }
        return matches[0].url
    }

    private func managedFiles() throws -> [ManagedFile] {
        guard FileManager.default.fileExists(atPath: directoryURL.path)
        else { return [] }
        guard let directoryValues = try? directoryURL.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ),
        directoryValues.isDirectory == true,
        directoryValues.isSymbolicLink != true else {
            throw IOSAcceptedAudioCacheError.storageUnavailable
        }
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw IOSAcceptedAudioCacheError.storageUnavailable
        }

        return urls.compactMap { url in
            guard let identity = Self.managedIdentity(
                fileName: url.lastPathComponent
            ),
            let values = try? url.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]),
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            (values.fileSize ?? 0) > 0 else { return nil }
            return ManagedFile(
                resultID: identity.resultID,
                url: url,
                modificationDate: values.contentModificationDate
                    ?? .distantPast
            )
        }
    }

    private func fileURL(
        resultID: UUID,
        fileExtension: String
    ) -> URL {
        directoryURL.appendingPathComponent(
            Self.filePrefix + resultID.uuidString.lowercased()
                + "." + fileExtension,
            isDirectory: false
        )
    }

    private func applyCreationDate(_ date: Date, to url: URL) throws {
        do {
            try FileManager.default.setAttributes(
                [.modificationDate: date],
                ofItemAtPath: url.path
            )
        } catch {
            throw IOSAcceptedAudioCacheError.storageUnavailable
        }
    }

    private static func managedIdentity(
        fileName: String
    ) -> (resultID: UUID, fileExtension: String)? {
        guard fileName.hasPrefix(filePrefix),
              let dot = fileName.lastIndex(of: ".") else { return nil }
        let idStart = fileName.index(
            fileName.startIndex,
            offsetBy: filePrefix.count
        )
        let rawID = String(fileName[idStart..<dot])
        let fileExtension = String(fileName[fileName.index(after: dot)...])
        guard allowedExtensions.contains(fileExtension),
              let resultID = UUID(uuidString: rawID),
              rawID == resultID.uuidString.lowercased() else { return nil }
        return (resultID, fileExtension)
    }

    private static func isNewer(_ lhs: ManagedFile, _ rhs: ManagedFile)
        -> Bool {
        if lhs.modificationDate != rhs.modificationDate {
            return lhs.modificationDate > rhs.modificationDate
        }
        return lhs.url.lastPathComponent < rhs.url.lastPathComponent
    }

    private static let filePrefix = "accepted-v1-"
    private static let allowedExtensions: Set<String> = ["m4a", "wav"]

    private struct ManagedFile {
        let resultID: UUID
        let url: URL
        let modificationDate: Date
    }
}
