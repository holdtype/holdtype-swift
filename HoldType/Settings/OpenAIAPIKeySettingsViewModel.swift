//
//  OpenAIAPIKeySettingsViewModel.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class OpenAIAPIKeySettingsViewModel: ObservableObject {
    @Published var state: APIKeySettingsState

    private let apiKeyStorage: any APIKeyStorage
    private let pasteboardStringProvider: () -> String?

    init(
        apiKeyStorage: any APIKeyStorage = APIKeyCredentialProvider.shared,
        initialState: APIKeySettingsState = APIKeySettingsState(),
        pasteboardStringProvider: @escaping () -> String? = {
            NSPasteboard.general.string(forType: .string)
        }
    ) {
        self.apiKeyStorage = apiKeyStorage
        self.state = initialState
        self.pasteboardStringProvider = pasteboardStringProvider
    }

    var status: APIKeySettingsStatus {
        state.status
    }

    var apiKeyAvailability: APIKeyAvailability {
        state.apiKeyAvailability
    }

    func refreshAvailability() {
        do {
            state.applyAvailability(try apiKeyStorage.apiKeyAvailability())
        } catch {
            state.applyFailure(error.localizedDescription)
        }
    }

    func autosaveAPIKeyIfNeeded() {
        guard state.shouldAutosaveInput else {
            return
        }

        do {
            try apiKeyStorage.saveAPIKey(state.normalizedInput)
            state.applySavedInput()
        } catch {
            state.applyFailure(error.localizedDescription)
        }
    }

    func pasteAPIKeyFromClipboard() {
        guard let clipboardText = pasteboardStringProvider(),
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        state.input = clipboardText
        autosaveAPIKeyIfNeeded()
    }

    func removeAPIKey() {
        do {
            try apiKeyStorage.deleteAPIKey()
            state.applyDeletedAPIKey()
        } catch {
            state.applyFailure(error.localizedDescription)
        }
    }
}
