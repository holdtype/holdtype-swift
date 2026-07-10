import Foundation

/// Stable app-private location for the containing app's versioned settings file.
public enum IOSAppSettingsStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-app-settings.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

struct IOSAppSettingsReplacementOptions: Equatable, Sendable {
    enum FileProtection: Equatable, Sendable {
        case complete
    }

    let fileProtection: FileProtection
    let excludesFromBackup: Bool
}

protocol IOSAppSettingsFileSystem: Sendable {
    func readFileIfPresent(at fileURL: URL) throws -> Data?

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        options: IOSAppSettingsReplacementOptions
    ) throws
}

struct FoundationIOSAppSettingsFileSystem: IOSAppSettingsFileSystem {
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
        options: IOSAppSettingsReplacementOptions
    ) throws {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: fileAttributes(for: options.fileProtection)
        )

        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp",
            isDirectory: false
        )

        do {
            try data.write(
                to: temporaryURL,
                options: [.withoutOverwriting, .completeFileProtection]
            )
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

    private func fileAttributes(
        for protection: IOSAppSettingsReplacementOptions.FileProtection
    ) -> [FileAttributeKey: Any] {
        switch protection {
        case .complete:
            return [.protectionKey: FileProtectionType.complete]
        }
    }
}
