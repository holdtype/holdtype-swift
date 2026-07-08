//
//  DebugAPIKeyFileStorage.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

#if DEBUG
import Foundation

struct DebugAPIKeyFileStorage: APIKeyStorage {
    static let keySourceEnvironmentKey = "HOLDTYPE_KEY_SOURCE"
    static let debugFileSourceValue = "debug-file"
    static let debugAPIKeyFileEnvironmentKey = "HOLDTYPE_DEBUG_API_KEY_FILE"

    private let fileURL: URL?
    private let stringLoader: (URL) throws -> String

    init(
        fileURL: URL?,
        stringLoader: @escaping (URL) throws -> String = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
    ) {
        self.fileURL = fileURL
        self.stringLoader = stringLoader
    }

    static func storageIfEnabled(environment: [String: String]) -> DebugAPIKeyFileStorage? {
        guard environment[keySourceEnvironmentKey]?.lowercased() == debugFileSourceValue else {
            return nil
        }

        guard let path = environment[debugAPIKeyFileEnvironmentKey],
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return DebugAPIKeyFileStorage(fileURL: nil)
        }

        return DebugAPIKeyFileStorage(fileURL: URL(fileURLWithPath: path))
    }

    func saveAPIKey(_ apiKey: String) throws {
        throw DebugAPIKeyFileStorageError.readOnly
    }

    func loadAPIKey() throws -> String? {
        try loadAPIKeyWithoutUI()
    }

    func loadAPIKeyWithoutUI() throws -> String? {
        guard let fileURL else {
            throw DebugAPIKeyFileStorageError.missingFilePath
        }

        let contents: String
        do {
            contents = try stringLoader(fileURL)
        } catch {
            throw DebugAPIKeyFileStorageError.unreadableFile
        }

        return Self.firstAPIKeyLine(in: contents)
    }

    func deleteAPIKey() throws {
        throw DebugAPIKeyFileStorageError.readOnly
    }

    func apiKeyAvailability() throws -> APIKeyAvailability {
        guard let apiKey = try loadAPIKeyWithoutUI(),
              !apiKey.isEmpty else {
            return .missing
        }

        return .saved
    }

    private static func firstAPIKeyLine(in contents: String) -> String? {
        contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty && !line.hasPrefix("#")
            }
    }
}

enum DebugAPIKeyFileStorageError: Error, Equatable, LocalizedError {
    case missingFilePath
    case unreadableFile
    case readOnly

    var errorDescription: String? {
        switch self {
        case .missingFilePath:
            return "Set HOLDTYPE_DEBUG_API_KEY_FILE to use debug API key file mode."
        case .unreadableFile:
            return "The debug API key file could not be read."
        case .readOnly:
            return "Debug API key file mode is read-only."
        }
    }
}
#endif
