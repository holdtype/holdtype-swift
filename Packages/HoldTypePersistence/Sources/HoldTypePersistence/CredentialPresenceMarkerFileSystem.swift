import Foundation

struct CredentialPresenceMarkerReplacementOptions: Equatable, Sendable {
    enum FileProtection: Equatable, Sendable {
        case complete
    }

    let fileProtection: FileProtection
    let excludesFromBackup: Bool
}

protocol CredentialPresenceMarkerFileSystem: Sendable {
    func readFileIfPresent(at fileURL: URL) throws -> Data?

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        options: CredentialPresenceMarkerReplacementOptions
    ) throws

    func removeFileIfPresent(at fileURL: URL) throws
}

struct FoundationCredentialPresenceMarkerFileSystem: CredentialPresenceMarkerFileSystem {
    func readFileIfPresent(at fileURL: URL) throws -> Data? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try Data(contentsOf: fileURL)
    }

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        options: CredentialPresenceMarkerReplacementOptions
    ) throws {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: directoryAttributes(for: options.fileProtection)
        )

        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp",
            isDirectory: false
        )

        do {
            try data.write(to: temporaryURL, options: .withoutOverwriting)
            try fileManager.setAttributes(
                fileAttributes(for: options.fileProtection),
                ofItemAtPath: temporaryURL.path
            )

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = options.excludesFromBackup
            var protectedTemporaryURL = temporaryURL
            try protectedTemporaryURL.setResourceValues(resourceValues)

            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    func removeFileIfPresent(at fileURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    private func directoryAttributes(
        for protection: CredentialPresenceMarkerReplacementOptions.FileProtection
    ) -> [FileAttributeKey: Any] {
        fileAttributes(for: protection)
    }

    private func fileAttributes(
        for protection: CredentialPresenceMarkerReplacementOptions.FileProtection
    ) -> [FileAttributeKey: Any] {
        switch protection {
        case .complete:
            return [.protectionKey: FileProtectionType.complete]
        }
    }
}
