//
//  RecordingSetupPreflightTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/6/26.
//

import Foundation
import HoldTypeOpenAI
import Security
import Testing
@testable import HoldType

struct RecordingSetupPreflightTests {

    @Test func missingPermissionsTakePriorityOverMissingAPIKey() {
        let apiKeyStorage = FakeRecordingSetupAPIKeyStorage(availability: .missing)
        let preflight = RecordingSetupPreflight(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .notDetermined,
                accessibilityTrusted: false,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            apiKeyStorage: apiKeyStorage
        )

        let result = preflight.evaluate(settings: .defaults)

        #expect(result.requirement == .permissions(message: result.setupStatus.recordingBlockedMessage))
        #expect(result.setupStatus.recordingBlockers.map(\.kind) == [.microphone, .accessibility])
        #expect(apiKeyStorage.loadCount == 0)
        #expect(apiKeyStorage.availabilityCount == 0)
    }

    @Test func missingAPIKeyBlocksOnlyAfterPermissionsAreReady() {
        let apiKeyStorage = FakeRecordingSetupAPIKeyStorage(availability: .missing)
        let preflight = RecordingSetupPreflight(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            apiKeyStorage: apiKeyStorage
        )

        let result = preflight.evaluate(settings: .defaults)

        #expect(
            result.requirement == .openAIKey(
                message: APIKeyAvailability.missing.settingsDescription
            )
        )
        #expect(result.setupStatus.canStartRecording)
        #expect(apiKeyStorage.loadCount == 1)
        #expect(apiKeyStorage.availabilityCount == 0)
    }

    @Test func inaccessibleAPIKeyBlocksBeforeRecording() {
        let availability = APIKeyAvailability.unavailable(KeychainService.inaccessibleAPIKeyMessage)
        let apiKeyStorage = FakeRecordingSetupAPIKeyStorage(
            availability: availability,
            loadError: KeychainServiceError.unhandledKeychainStatus(errSecInteractionNotAllowed)
        )
        let preflight = RecordingSetupPreflight(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            apiKeyStorage: apiKeyStorage
        )

        let result = preflight.evaluate(settings: .defaults)

        #expect(result.requirement == .openAIKey(message: availability.settingsDescription))
        #expect(result.setupStatus.canStartRecording)
        #expect(apiKeyStorage.loadCount == 1)
        #expect(apiKeyStorage.availabilityCount == 0)
    }

    @Test func savedAPIKeyAndReadyPermissionsAllowRecording() {
        let apiKeyStorage = FakeRecordingSetupAPIKeyStorage(availability: .saved)
        let preflight = RecordingSetupPreflight(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            apiKeyStorage: apiKeyStorage
        )

        let result = preflight.evaluate(settings: .defaults)

        guard case .ready(let credential) = result.requirement else {
            Issue.record("Expected ready preflight requirement.")
            return
        }

        #expect(credential.apiKey == "sk-test")
        #expect(result.setupStatus.canStartRecording)
        #expect(apiKeyStorage.loadCount == 1)
        #expect(apiKeyStorage.availabilityCount == 0)
    }

    private func makeSetupStatusProvider(
        microphoneAuthorizationStatus: MicrophoneAuthorizationStatus,
        accessibilityTrusted: Bool,
        inputMonitoringAuthorizationStatus: InputMonitoringAuthorizationStatus
    ) -> AppSetupStatusProvider {
        AppSetupStatusProvider(
            microphonePermissionService: MicrophonePermissionService(
                client: FakeRecordingSetupMicrophonePermissionClient(
                    status: microphoneAuthorizationStatus
                )
            ),
            accessibilityPermissionService: AccessibilityPermissionService(
                client: FakeRecordingSetupAccessibilityPermissionClient(
                    isTrusted: accessibilityTrusted
                )
            ),
            inputMonitoringPermissionService: InputMonitoringPermissionService(
                client: FakeRecordingSetupInputMonitoringPermissionClient(
                    status: inputMonitoringAuthorizationStatus
                )
            )
        )
    }
}

private final class FakeRecordingSetupAPIKeyStorage: APIKeyStorage {
    let availability: APIKeyAvailability
    private let loadError: Error?

    private(set) var loadCount = 0
    private(set) var availabilityCount = 0

    init(
        availability: APIKeyAvailability,
        loadError: Error? = nil
    ) {
        self.availability = availability
        self.loadError = loadError
    }

    func saveAPIKey(_ apiKey: String) throws {}

    func loadAPIKey() throws -> String? {
        loadCount += 1
        if let loadError {
            throw loadError
        }

        return availability == .saved ? "sk-test" : nil
    }

    func deleteAPIKey() throws {}

    func apiKeyAvailability() throws -> APIKeyAvailability {
        availabilityCount += 1
        return availability
    }
}

private struct FakeRecordingSetupMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput = true
    let status: MicrophoneAuthorizationStatus

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        status
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        completion(status == .allowed)
    }
}

private struct FakeRecordingSetupAccessibilityPermissionClient: AccessibilityPermissionClient {
    let isTrusted: Bool

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        isTrusted
    }

    func openAccessibilitySettings() -> Bool {
        true
    }
}

private struct FakeRecordingSetupInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    let status: InputMonitoringAuthorizationStatus

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        status
    }

    func requestAccess() -> Bool {
        status == .allowed
    }

    func openInputMonitoringSettings() -> Bool {
        true
    }
}
