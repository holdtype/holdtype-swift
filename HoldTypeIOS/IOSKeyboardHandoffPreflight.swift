import Foundation
import HoldTypeDomain
import HoldTypeIOSCore
import HoldTypePersistence

nonisolated enum IOSKeyboardHandoffPreflightIssue: Equatable, Sendable {
    case localDataUnavailable
    case transcriptionConfiguration
    case translationConfiguration
    case providerConsent
    case openAICredential
    case microphonePermission
    case microphoneUnavailable

    var title: String {
        switch self {
        case .localDataUnavailable:
            "HoldType data is unavailable"
        case .transcriptionConfiguration:
            "Check transcription settings"
        case .translationConfiguration:
            "Finish translation setup"
        case .providerConsent:
            "Review OpenAI processing"
        case .openAICredential:
            "Add your OpenAI key"
        case .microphonePermission:
            "Allow microphone access"
        case .microphoneUnavailable:
            "Microphone is unavailable"
        }
    }

    var detail: String {
        switch self {
        case .localDataUnavailable:
            "Close this sheet and try again after HoldType can read its local data."
        case .transcriptionConfiguration:
            "Complete the transcription language setup, then start a new keyboard dictation."
        case .translationConfiguration:
            "Choose a valid translation route, then start a new keyboard dictation."
        case .providerConsent:
            "Accept the current OpenAI processing disclosure before starting keyboard dictation."
        case .openAICredential:
            "Save a readable OpenAI API key, then start a new keyboard dictation."
        case .microphonePermission:
            "Allow HoldType to use the microphone, then start a new keyboard dictation."
        case .microphoneUnavailable:
            "HoldType could not access the microphone. Close this sheet and try again."
        }
    }
}

nonisolated enum IOSKeyboardHandoffPreflightResult: Equatable, Sendable {
    case ready
    case blocked(IOSKeyboardHandoffPreflightIssue)
}

struct IOSKeyboardHandoffPreflightClient: Sendable {
    let run: @MainActor @Sendable (
        KeyboardHandoffIntentRecord
    ) async -> IOSKeyboardHandoffPreflightResult

    nonisolated static func passThrough() -> Self {
        Self { _ in .ready }
    }

    @MainActor
    static func live(
        settingsStateOwner: IOSAppSettingsStateOwner?,
        credentialCoordinator: IOSOpenAICredentialCoordinator?,
        providerConsentCoordinator: IOSV1ProviderConsentCoordinator?,
        permission: IOSForegroundVoiceWorkflowPermissionClient
    ) -> Self {
        Self { intent in
            guard let settingsStateOwner,
                  let credentialCoordinator,
                  let providerConsentCoordinator else {
                return .blocked(.localDataUnavailable)
            }

            let settings: IOSAppSettings
            do {
                settings = try await settingsStateOwner
                    .confirmedValueForProviderAction()
            } catch {
                return .blocked(.localDataUnavailable)
            }
            guard !settings.transcriptionConfiguration
                .customLanguageCodeValidation.isInvalid else {
                return .blocked(.transcriptionConfiguration)
            }
            if intent.action.translates,
               !settings.translationConfiguration.isConfigurationReady {
                return .blocked(.translationConfiguration)
            }

            let consent = await providerConsentCoordinator.observe()
            guard consent.status == .acceptedCurrentDisclosure else {
                return .blocked(.providerConsent)
            }

            do {
                let credential = try await credentialCoordinator.resolve(
                    for: .voicePreflight
                )
                guard case .available = credential.resolution else {
                    return .blocked(.openAICredential)
                }
            } catch {
                return .blocked(.openAICredential)
            }

            switch permission.read() {
            case .granted:
                return .ready
            case .undetermined:
                switch await permission.requestIfUndetermined() {
                case .granted:
                    return permission.read() == .granted
                        ? .ready
                        : .blocked(.microphoneUnavailable)
                case .denied:
                    return .blocked(.microphonePermission)
                case .unavailable, .timedOut, .cancelled:
                    return .blocked(.microphoneUnavailable)
                }
            case .denied:
                return .blocked(.microphonePermission)
            case .unavailable:
                return .blocked(.microphoneUnavailable)
            }
        }
    }
}
