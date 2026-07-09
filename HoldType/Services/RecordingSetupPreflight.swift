//
//  RecordingSetupPreflight.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import Foundation
import HoldTypeDomain

struct RecordingSetupPreflight {
    private let setupStatusProvider: AppSetupStatusProvider
    private let credentialResolver: any OpenAICredentialResolving

    init(
        setupStatusProvider: AppSetupStatusProvider = AppSetupStatusProvider(),
        credentialResolver: any OpenAICredentialResolving = OpenAICredentialResolver()
    ) {
        self.setupStatusProvider = setupStatusProvider
        self.credentialResolver = credentialResolver
    }

    init(
        setupStatusProvider: AppSetupStatusProvider = AppSetupStatusProvider(),
        apiKeyStorage: any APIKeyStorage
    ) {
        self.init(
            setupStatusProvider: setupStatusProvider,
            credentialResolver: OpenAICredentialResolver(apiKeyStorage: apiKeyStorage)
        )
    }

    func evaluate(settings: AppSettings) -> RecordingSetupPreflightResult {
        let setupStatus = setupStatusProvider.currentStatus(settings: settings)
        guard setupStatus.canStartRecording else {
            return RecordingSetupPreflightResult(
                setupStatus: setupStatus,
                requirement: .permissions(message: setupStatus.recordingBlockedMessage)
            )
        }

        do {
            let credential = try credentialResolver.resolveOpenAICredential()
            return RecordingSetupPreflightResult(
                setupStatus: setupStatus,
                requirement: .ready(credential: credential)
            )
        } catch let error as OpenAICredentialResolutionError {
            let availability = error.availability
            return RecordingSetupPreflightResult(
                setupStatus: setupStatus,
                requirement: .openAIKey(message: availability.settingsDescription)
            )
        } catch {
            return RecordingSetupPreflightResult(
                setupStatus: setupStatus,
                requirement: .openAIKey(message: error.localizedDescription)
            )
        }
    }

    func requestMicrophonePermissionIfNeeded() async -> MicrophonePermissionStatus? {
        await withCheckedContinuation { continuation in
            setupStatusProvider.requestMicrophonePermissionIfNeeded { status in
                continuation.resume(returning: status)
            }
        }
    }
}

struct RecordingSetupPreflightResult: Equatable {
    let setupStatus: AppSetupStatus
    let requirement: RecordingSetupRequirement
}

enum RecordingSetupRequirement: Equatable {
    case ready(credential: OpenAICredential)
    case permissions(message: String)
    case openAIKey(message: String)
}
