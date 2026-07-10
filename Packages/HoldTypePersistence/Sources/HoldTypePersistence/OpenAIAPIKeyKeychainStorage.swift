import Foundation
import Security

/// The containing-app boundary for the single iOS OpenAI API-key item.
public protocol OpenAIAPIKeyStoring: Sendable {
    func saveOrReplaceAPIKey(_ candidate: String) async throws
    func loadAPIKey() async throws -> String?
    func removeAPIKey() async throws
}

public enum OpenAIAPIKeyKeychainStorageError: Error, Equatable, Sendable {
    case invalidApplicationIdentifierAccessGroup
    case emptyAPIKey
    case unavailableWhileLocked
    case invalidResult
    case invalidStoredAPIKey
    case keychainFailure
}

extension OpenAIAPIKeyKeychainStorageError:
    LocalizedError,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    public var errorDescription: String? {
        description
    }

    public var description: String {
        switch self {
        case .invalidApplicationIdentifierAccessGroup:
            "OpenAI API key storage is not configured for this signed app."
        case .emptyAPIKey:
            "Enter an OpenAI API key."
        case .unavailableWhileLocked:
            "The saved OpenAI API key is unavailable while this device is locked."
        case .invalidResult, .invalidStoredAPIKey:
            "The saved OpenAI API key could not be read."
        case .keychainFailure:
            "The OpenAI API key could not be accessed in Keychain."
        }
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .enum
        )
    }
}

/// Serializes access to the iOS app's non-synchronizable OpenAI Keychain item.
public actor OpenAIAPIKeyKeychainStorage: OpenAIAPIKeyStoring {
    public static let containingAppBundleIdentifier = "app.holdtype.HoldType.ios"
    public static let service = "app.holdtype.HoldType.ios"
    public static let account = "openai-api-key"
    public static let applicationIdentifierAccessGroupInfoKey =
        "HoldTypeApplicationIdentifierAccessGroup"

    private let client: any SecItemClient
    private let applicationIdentifierAccessGroup: String

    public init(applicationIdentifierAccessGroup: String) throws {
        self.applicationIdentifierAccessGroup = try Self.validate(
            applicationIdentifierAccessGroup: applicationIdentifierAccessGroup
        )
        client = SystemSecItemClient()
    }

    init(
        client: any SecItemClient,
        applicationIdentifierAccessGroup: String
    ) throws {
        self.client = client
        self.applicationIdentifierAccessGroup = try Self.validate(
            applicationIdentifierAccessGroup: applicationIdentifierAccessGroup
        )
    }

    public func saveOrReplaceAPIKey(_ candidate: String) async throws {
        let normalizedAPIKey = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw OpenAIAPIKeyKeychainStorageError.emptyAPIKey
        }

        let data = Data(normalizedAPIKey.utf8)
        let updateStatus = client.update(
            query: itemIdentityQuery,
            attributes: Self.updateAttributes(data: data)
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            try addAPIKey(data)
        default:
            throw Self.error(for: updateStatus)
        }
    }

    public func loadAPIKey() async throws -> String? {
        let result = client.copyMatching(query: loadQuery)

        switch result.status {
        case errSecSuccess:
            guard let data = result.value as? Data else {
                throw OpenAIAPIKeyKeychainStorageError.invalidResult
            }
            return try Self.apiKey(from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw Self.error(for: result.status)
        }
    }

    public func removeAPIKey() async throws {
        let status = client.delete(query: itemIdentityQuery)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw Self.error(for: status)
        }
    }

    private func addAPIKey(_ data: Data) throws {
        let addStatus = client.add(attributes: addAttributes(data: data))

        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let retryStatus = client.update(
                query: itemIdentityQuery,
                attributes: Self.updateAttributes(data: data)
            )
            guard retryStatus == errSecSuccess else {
                throw Self.error(for: retryStatus)
            }
        default:
            throw Self.error(for: addStatus)
        }
    }

    private var itemIdentityQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecAttrSynchronizable as String: false,
            kSecAttrAccessGroup as String: applicationIdentifierAccessGroup,
        ]
    }

    private var loadQuery: [String: Any] {
        var query = itemIdentityQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    private func addAttributes(data: Data) -> [String: Any] {
        var attributes = itemIdentityQuery
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecValueData as String] = data
        return attributes
    }

    private static func updateAttributes(data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
        ]
    }

    private static func apiKey(from data: Data) throws -> String {
        guard let value = String(data: data, encoding: .utf8) else {
            throw OpenAIAPIKeyKeychainStorageError.invalidStoredAPIKey
        }

        let normalizedAPIKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw OpenAIAPIKeyKeychainStorageError.invalidStoredAPIKey
        }

        return normalizedAPIKey
    }

    private static func validate(applicationIdentifierAccessGroup: String) throws -> String {
        let expectedSuffix = ".\(containingAppBundleIdentifier)"
        guard !applicationIdentifierAccessGroup.contains("$("),
              !applicationIdentifierAccessGroup.hasPrefix("group."),
              applicationIdentifierAccessGroup != "group.app.holdtype.HoldType.shared",
              applicationIdentifierAccessGroup.hasSuffix(expectedSuffix) else {
            throw OpenAIAPIKeyKeychainStorageError.invalidApplicationIdentifierAccessGroup
        }

        let prefix = applicationIdentifierAccessGroup.dropLast(expectedSuffix.count)
        guard !prefix.isEmpty,
              prefix.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains) else {
            throw OpenAIAPIKeyKeychainStorageError.invalidApplicationIdentifierAccessGroup
        }

        return applicationIdentifierAccessGroup
    }

    private static func error(for status: OSStatus) -> OpenAIAPIKeyKeychainStorageError {
        if status == errSecInteractionNotAllowed {
            return .unavailableWhileLocked
        }

        return .keychainFailure
    }
}

struct SecItemCopyResult {
    let status: OSStatus
    let value: Any?
}

protocol SecItemClient: Sendable {
    func add(attributes: [String: Any]) -> OSStatus
    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus
    func copyMatching(query: [String: Any]) -> SecItemCopyResult
    func delete(query: [String: Any]) -> OSStatus
}

struct SystemSecItemClient: SecItemClient {
    func add(attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func copyMatching(query: [String: Any]) -> SecItemCopyResult {
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        return SecItemCopyResult(status: status, value: value)
    }

    func delete(query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}
