//
//  APIKeyCredentialProviderTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import Security
import Testing
@testable import HoldType

struct APIKeyCredentialProviderTests {

    @Test func apiKeyAvailabilityDoesNotTouchBackingStorageBeforeLazyLoad() throws {
        let storage = FakeCredentialStorage(apiKey: " sk-test \n")
        let provider = APIKeyCredentialProvider(storage: storage)

        #expect(try provider.apiKeyAvailability() == .unknown)
        #expect(storage.nonInteractiveLoadCount == 0)
        #expect(storage.legacyLoadCount == 0)
    }

    @Test func loadAPIKeyLazilyStoresReadableKeyInMemoryForHotPathLoads() throws {
        let storage = FakeCredentialStorage(apiKey: " sk-test \n")
        let provider = APIKeyCredentialProvider(storage: storage)

        #expect(try provider.loadAPIKey() == "sk-test")
        #expect(storage.nonInteractiveLoadCount == 1)
        #expect(try provider.apiKeyAvailability() == .saved)

        _ = try provider.loadAPIKey()

        #expect(storage.nonInteractiveLoadCount == 1)
        #expect(storage.legacyLoadCount == 0)
    }

    @Test func nonInteractiveKeychainDenialDoesNotPopulateRuntimeCache() throws {
        let storage = FakeCredentialStorage(
            apiKey: "sk-test",
            nonInteractiveLoadError: KeychainServiceError.unhandledKeychainStatus(
                errSecInteractionNotAllowed
            )
        )
        let provider = APIKeyCredentialProvider(storage: storage)

        #expect(
            throws: KeychainServiceError.unhandledKeychainStatus(
                errSecInteractionNotAllowed
            )
        ) {
            _ = try provider.loadAPIKey()
        }
        #expect(
            try provider.apiKeyAvailability()
                == .unavailable(KeychainService.inaccessibleAPIKeyMessage)
        )
        #expect(storage.nonInteractiveLoadCount == 1)

        _ = try provider.apiKeyAvailability()

        #expect(storage.nonInteractiveLoadCount == 1)
    }

    @Test func saveAndDeleteSynchronizeRuntimeCache() throws {
        let storage = FakeCredentialStorage(apiKey: nil)
        let provider = APIKeyCredentialProvider(storage: storage)

        try provider.saveAPIKey(" sk-new ")

        #expect(storage.savedAPIKeys == ["sk-new"])
        #expect(try provider.loadAPIKey() == "sk-new")
        #expect(try provider.apiKeyAvailability() == .saved)

        try provider.deleteAPIKey()

        #expect(storage.deleteCount == 1)
        #expect(try provider.loadAPIKey() == nil)
    }

    #if DEBUG
    @Test func explicitDebugFileSourceLoadsFirstNonCommentLine() throws {
        let fileURL = try makeTemporaryDebugAPIKeyFile(
            contents: "\n# comment\n sk-debug-file \n"
        )
        let provider = APIKeyCredentialProvider(
            environment: [
                DebugAPIKeyFileStorage.keySourceEnvironmentKey:
                    DebugAPIKeyFileStorage.debugFileSourceValue,
                DebugAPIKeyFileStorage.debugAPIKeyFileEnvironmentKey: fileURL.path,
            ]
        )

        #expect(try provider.apiKeyAvailability() == .unknown)
        #expect(try provider.loadAPIKey() == "sk-debug-file")
        #expect(try provider.apiKeyAvailability() == .saved)
    }

    @Test func automationEnvironmentIgnoresDebugFileSource() throws {
        let fileURL = try makeTemporaryDebugAPIKeyFile(contents: "sk-debug-file")
        let provider = APIKeyCredentialProvider(
            environment: [
                KeychainInteractionPolicy.automationEnvironmentKey: "1",
                DebugAPIKeyFileStorage.keySourceEnvironmentKey:
                    DebugAPIKeyFileStorage.debugFileSourceValue,
                DebugAPIKeyFileStorage.debugAPIKeyFileEnvironmentKey: fileURL.path,
            ]
        )

        #expect(try provider.loadAPIKey() == nil)
        #expect(try provider.apiKeyAvailability() == .missing)
    }

    private func makeTemporaryDebugAPIKeyFile(contents: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-debug-key-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = directoryURL.appendingPathComponent("HoldTypeDebugAPIKey.local")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    #endif
}

private final class FakeCredentialStorage: APIKeyStorage {
    private var apiKey: String?
    private let nonInteractiveLoadError: Error?

    private(set) var legacyLoadCount = 0
    private(set) var nonInteractiveLoadCount = 0
    private(set) var savedAPIKeys: [String] = []
    private(set) var deleteCount = 0

    init(
        apiKey: String?,
        nonInteractiveLoadError: Error? = nil
    ) {
        self.apiKey = apiKey
        self.nonInteractiveLoadError = nonInteractiveLoadError
    }

    func saveAPIKey(_ apiKey: String) throws {
        savedAPIKeys.append(apiKey)
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
        legacyLoadCount += 1
        return apiKey
    }

    func loadAPIKeyWithoutUI() throws -> String? {
        nonInteractiveLoadCount += 1
        if let nonInteractiveLoadError {
            throw nonInteractiveLoadError
        }

        return apiKey
    }

    func deleteAPIKey() throws {
        deleteCount += 1
        apiKey = nil
    }
}
