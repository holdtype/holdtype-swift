//
//  APIKeyCredentialProvider.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import Foundation

final class APIKeyCredentialProvider: APIKeyStorage {
    static let shared = APIKeyCredentialProvider()

    private let storage: any APIKeyStorage
    private let lock = NSLock()
    private var cachedAPIKey: String?
    private var cachedAvailability: APIKeyAvailability = .unknown

    init(storage: (any APIKeyStorage)? = nil) {
        if let storage {
            self.storage = storage
        } else {
            self.storage = Self.defaultStorage()
        }
    }

    convenience init(environment: [String: String]) {
        self.init(storage: Self.defaultStorage(environment: environment))
    }

    func saveAPIKey(_ apiKey: String) throws {
        let normalizedAPIKey = try Self.normalizedAPIKey(apiKey)
        try storage.saveAPIKey(normalizedAPIKey)
        setCachedAPIKey(normalizedAPIKey)
    }

    func loadAPIKey() throws -> String? {
        if let cachedAPIKey = lock.withLock({ cachedAPIKey }) {
            return cachedAPIKey
        }

        return try resolveAndCacheAPIKey()
    }

    func loadAPIKeyWithoutUI() throws -> String? {
        try loadAPIKey()
    }

    func deleteAPIKey() throws {
        try storage.deleteAPIKey()
        clearCachedAPIKey(availability: .missing)
    }

    func apiKeyAvailability() throws -> APIKeyAvailability {
        lock.withLock {
            if cachedAPIKey != nil {
                return .saved
            }

            return cachedAvailability
        }
    }

    private func resolveAndCacheAPIKey() throws -> String? {
        do {
            guard let apiKey = try storage.loadAPIKeyWithoutUI() else {
                clearCachedAPIKey(availability: .missing)
                return nil
            }

            let normalizedAPIKey = try Self.normalizedAPIKey(apiKey)
            setCachedAPIKey(normalizedAPIKey)
            return normalizedAPIKey
        } catch {
            let availability = Self.availability(for: error)
            clearCachedAPIKey(availability: availability)
            throw error
        }
    }

    private func setCachedAPIKey(_ apiKey: String) {
        lock.withLock {
            cachedAPIKey = apiKey
            cachedAvailability = .saved
        }
    }

    private func clearCachedAPIKey(availability: APIKeyAvailability) {
        lock.withLock {
            cachedAPIKey = nil
            cachedAvailability = availability
        }
    }

    private static func normalizedAPIKey(_ apiKey: String) throws -> String {
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw KeychainServiceError.emptyAPIKey
        }

        return normalizedAPIKey
    }

    private static func availability(for error: Error) -> APIKeyAvailability {
        if let error = error as? KeychainServiceError,
           case .unhandledKeychainStatus(let status) = error,
           KeychainService.isPermissionDeniedStatus(status) {
            return .unavailable(KeychainService.inaccessibleAPIKeyMessage)
        }

        return .unavailable(error.localizedDescription)
    }

    private static func defaultStorage(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any APIKeyStorage {
        let keychainPolicy = KeychainInteractionPolicy.currentProcessDefault(
            environment: environment
        )
        let keychainStorage = KeychainService(interactionPolicy: keychainPolicy)

        guard keychainPolicy != .disableKeychainAccess else {
            return keychainStorage
        }

        #if DEBUG
        if let debugFileStorage = DebugAPIKeyFileStorage.storageIfEnabled(
            environment: environment
        ) {
            return debugFileStorage
        }
        #endif

        return keychainStorage
    }
}
