//
//  OpenAIAPIKeySettingsViewModelTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/6/26.
//

import Foundation
import Testing
@testable import HoldType

@MainActor
struct OpenAIAPIKeySettingsViewModelTests {

    @Test func refreshAvailabilityUpdatesSavedStatusWithoutReadingSecretIntoInput() {
        let storage = FakeOpenAIAPIKeySettingsStorage(availability: .saved)
        let model = OpenAIAPIKeySettingsViewModel(apiKeyStorage: storage)

        model.refreshAvailability()

        #expect(model.status == .saved)
        #expect(model.state.input.isEmpty)
        #expect(model.apiKeyAvailability == .saved)
    }

    @Test func autosavePersistsNonEmptyInputAndClearsSecretField() {
        let storage = FakeOpenAIAPIKeySettingsStorage(availability: .missing)
        let model = OpenAIAPIKeySettingsViewModel(apiKeyStorage: storage)
        model.state.input = " sk-test-new "

        model.autosaveAPIKeyIfNeeded()

        #expect(storage.savedAPIKeys == ["sk-test-new"])
        #expect(model.status == .saved)
        #expect(model.state.input.isEmpty)
    }

    @Test func pasteFromClipboardPersistsPlainTextAndClearsSecretField() {
        let storage = FakeOpenAIAPIKeySettingsStorage(availability: .missing)
        let model = OpenAIAPIKeySettingsViewModel(
            apiKeyStorage: storage,
            pasteboardStringProvider: { " sk-test-pasted\n" }
        )

        model.pasteAPIKeyFromClipboard()

        #expect(storage.savedAPIKeys == ["sk-test-pasted"])
        #expect(model.status == .saved)
        #expect(model.state.input.isEmpty)
    }

    @Test func pasteFromClipboardIgnoresMissingOrEmptyPlainText() {
        let storage = FakeOpenAIAPIKeySettingsStorage(availability: .missing)
        let model = OpenAIAPIKeySettingsViewModel(
            apiKeyStorage: storage,
            initialState: APIKeySettingsState(input: "sk-draft", status: .missing),
            pasteboardStringProvider: { " \n" }
        )

        model.pasteAPIKeyFromClipboard()

        #expect(storage.savedAPIKeys.isEmpty)
        #expect(model.state.input == "sk-draft")
        #expect(model.status == .missing)
    }

    @Test func refreshUnavailableKeyShowsFailureStatus() {
        let storage = FakeOpenAIAPIKeySettingsStorage(
            availability: .unavailable(KeychainService.inaccessibleAPIKeyMessage)
        )
        let model = OpenAIAPIKeySettingsViewModel(apiKeyStorage: storage)

        model.refreshAvailability()

        #expect(model.status == .failure(KeychainService.inaccessibleAPIKeyMessage))
        #expect(model.apiKeyAvailability == .unavailable(KeychainService.inaccessibleAPIKeyMessage))
    }

    @Test func removeAPIKeyUsesStorageAndReportsMissingStatus() {
        let storage = FakeOpenAIAPIKeySettingsStorage(availability: .saved)
        let model = OpenAIAPIKeySettingsViewModel(apiKeyStorage: storage)
        model.refreshAvailability()

        model.removeAPIKey()

        #expect(storage.deleteCount == 1)
        #expect(model.status == .missing)
    }

    @Test func saveFailurePreservesDraftInput() {
        let storage = FakeOpenAIAPIKeySettingsStorage(
            availability: .missing,
            saveError: FakeOpenAIAPIKeySettingsStorageError.saveFailed
        )
        let model = OpenAIAPIKeySettingsViewModel(apiKeyStorage: storage)
        model.state.input = "sk-draft"

        model.autosaveAPIKeyIfNeeded()

        #expect(model.state.input == "sk-draft")
        #expect(model.status == .failure("Save failed."))
    }
}

private enum FakeOpenAIAPIKeySettingsStorageError: Error, LocalizedError {
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Save failed."
        }
    }
}

private final class FakeOpenAIAPIKeySettingsStorage: APIKeyStorage {
    private let availability: APIKeyAvailability
    private let saveError: Error?

    private(set) var savedAPIKeys: [String] = []
    private(set) var deleteCount = 0

    init(
        availability: APIKeyAvailability,
        saveError: Error? = nil
    ) {
        self.availability = availability
        self.saveError = saveError
    }

    func saveAPIKey(_ apiKey: String) throws {
        if let saveError {
            throw saveError
        }

        savedAPIKeys.append(apiKey)
    }

    func loadAPIKey() throws -> String? {
        availability.allowsTranscription ? "sk-test" : nil
    }

    func deleteAPIKey() throws {
        deleteCount += 1
    }

    func apiKeyAvailability() throws -> APIKeyAvailability {
        availability
    }
}
