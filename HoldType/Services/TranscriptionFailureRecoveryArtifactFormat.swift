import Foundation

enum TranscriptionFailureRecoveryArtifactFormat {
    enum Marker: String {
        case savedStateRepair = "SavedStateRepair-"
        case processingCheckpoint = "ProcessingCheckpoint-"
        case providerDispatch = "ProviderDispatch-"
    }

    static let metadataFileName = "Recovery.json"

    static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let applicationSupportRoot = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
            ?? fileManager.temporaryDirectory

        return applicationSupportRoot
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent(
                "TranscriptionRecovery",
                isDirectory: true
            )
    }

    static func metadataURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(
            metadataFileName,
            isDirectory: false
        )
    }

    static func recoveryAudioURL(
        in directoryURL: URL,
        sourceFileExtension: String,
        id: UUID,
        createdAt: Date,
        completionKind: TranscriptionRecoveryCompletionKind
    ) -> URL {
        let recordingPrefix = completionKind == .maximumDuration
            ? "Recording-Max-"
            : "Recording-"
        return directoryURL
            .appendingPathComponent(
                "\(recordingPrefix)\(fileTimestamp(from: createdAt))-\(id.uuidString.lowercased())"
            )
            .appendingPathExtension(
                sourceFileExtension.isEmpty ? "m4a" : sourceFileExtension
            )
    }

    static func markerURL(
        _ marker: Marker,
        in directoryURL: URL,
        id: UUID
    ) -> URL {
        directoryURL.appendingPathComponent(
            canonicalMarkerFileName(marker, id: id),
            isDirectory: false
        )
    }

    static func recoveryFileIdentity(fileName: String) -> UUID? {
        recoveryFileDescriptor(fileName: fileName)?.id
    }

    static func recoveryFileDescriptor(
        fileName: String
    ) -> (
        id: UUID,
        completionKind: TranscriptionRecoveryCompletionKind
    )? {
        let fileURL = URL(fileURLWithPath: fileName)
        guard fileURL.lastPathComponent == fileName,
              !fileURL.pathExtension.isEmpty else {
            return nil
        }

        let stem = fileURL.deletingPathExtension().lastPathComponent
        let prefix: String
        let completionKind: TranscriptionRecoveryCompletionKind
        if stem.hasPrefix("Recording-Max-") {
            prefix = "Recording-Max-"
            completionKind = .maximumDuration
        } else {
            prefix = "Recording-"
            completionKind = .standard
        }
        guard stem.hasPrefix(prefix),
              stem.count == prefix.count + 15 + 1 + 36 else {
            return nil
        }

        let timestampStart = stem.index(
            stem.startIndex,
            offsetBy: prefix.count
        )
        let timestampEnd = stem.index(timestampStart, offsetBy: 15)
        let timestamp = stem[timestampStart..<timestampEnd]
        guard timestamp[timestamp.index(
            timestamp.startIndex,
            offsetBy: 8
        )] == "-",
            timestamp.enumerated().allSatisfy({ offset, character in
                offset == 8 ? character == "-" : character.isNumber
            }),
            stem[timestampEnd] == "-" else {
            return nil
        }

        let uuidStart = stem.index(after: timestampEnd)
        guard let id = UUID(uuidString: String(stem[uuidStart...])) else {
            return nil
        }
        return (id: id, completionKind: completionKind)
    }

    static func markerIdentity(
        _ marker: Marker,
        fileName: String
    ) -> UUID? {
        let fileURL = URL(fileURLWithPath: fileName)
        guard fileURL.lastPathComponent == fileName,
              fileURL.pathExtension == "json" else {
            return nil
        }

        let stem = fileURL.deletingPathExtension().lastPathComponent
        guard stem.hasPrefix(marker.rawValue),
              let id = UUID(
                  uuidString: String(
                      stem.dropFirst(marker.rawValue.count)
                  )
              ),
              fileName == canonicalMarkerFileName(marker, id: id) else {
            return nil
        }
        return id
    }

    static func regularNonemptyFile(
        at fileURL: URL,
        fileManager: FileManager
    ) -> URLResourceValues? {
        guard let values = regularFile(
            at: fileURL,
            fileManager: fileManager
        ),
            let fileSize = values.fileSize,
            fileSize > 0 else {
            return nil
        }

        return values
    }

    static func regularFile(
        at fileURL: URL,
        fileManager: FileManager
    ) -> URLResourceValues? {
        guard fileManager.fileExists(atPath: fileURL.path),
              let values = try? fileURL.resourceValues(forKeys: [
                  .isRegularFileKey,
                  .isSymbolicLinkKey,
                  .fileSizeKey,
                  .creationDateKey,
                  .contentModificationDateKey,
              ]),
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            return nil
        }

        return values
    }

    private static func canonicalMarkerFileName(
        _ marker: Marker,
        id: UUID
    ) -> String {
        "\(marker.rawValue)\(id.uuidString.lowercased()).json"
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
