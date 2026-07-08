//
//  OpenAICredentialResolverTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import Security
import Testing
@testable import HoldType

struct OpenAICredentialResolverTests {
    @Test func resolvesAndNormalizesCredentialFromStorage() throws {
        let storage = FakeOpenAICredentialAPIKeyStorage(apiKey: "  sk-resolved-key \n")
        let resolver = OpenAICredentialResolver(apiKeyStorage: storage)

        let credential = try resolver.resolveOpenAICredential()

        #expect(credential.apiKey == "sk-resolved-key")
        #expect(storage.loadCount == 1)
    }

    @Test func missingAPIKeyThrowsMissingWithoutAvailabilityProbe() {
        let storage = FakeOpenAICredentialAPIKeyStorage(apiKey: nil)
        let resolver = OpenAICredentialResolver(apiKeyStorage: storage)

        #expect(throws: OpenAICredentialResolutionError.missingAPIKey) {
            _ = try resolver.resolveOpenAICredential()
        }
        #expect(storage.loadCount == 1)
        #expect(storage.availabilityCount == 0)
    }

    @Test func keychainInteractionDeniedThrowsUnavailableCredential() {
        let storage = FakeOpenAICredentialAPIKeyStorage(
            loadError: KeychainServiceError.unhandledKeychainStatus(errSecInteractionNotAllowed)
        )
        let resolver = OpenAICredentialResolver(apiKeyStorage: storage)

        #expect(
            throws: OpenAICredentialResolutionError.apiKeyUnavailable(
                KeychainService.inaccessibleAPIKeyMessage
            )
        ) {
            _ = try resolver.resolveOpenAICredential()
        }
        #expect(storage.loadCount == 1)
        #expect(storage.availabilityCount == 0)
    }
}

private final class FakeOpenAICredentialAPIKeyStorage: APIKeyStorage {
    private let apiKey: String?
    private let loadError: Error?

    private(set) var loadCount = 0
    private(set) var availabilityCount = 0

    init(apiKey: String? = "sk-test", loadError: Error? = nil) {
        self.apiKey = apiKey
        self.loadError = loadError
    }

    func saveAPIKey(_ apiKey: String) throws {}

    func loadAPIKey() throws -> String? {
        loadCount += 1
        if let loadError {
            throw loadError
        }

        return apiKey
    }

    func deleteAPIKey() throws {}

    func apiKeyAvailability() throws -> APIKeyAvailability {
        availabilityCount += 1
        return apiKey == nil ? .missing : .saved
    }
}
