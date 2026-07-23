#if DEBUG
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

struct DebugFixesQAConfiguration:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    enum Mode: String, Equatable {
        case success
        case failure
        case timeout
        case cancel
    }

    static let enabledEnvironmentKey = "HOLDTYPE_DEBUG_FIXES_QA"
    static let modeEnvironmentKey = "HOLDTYPE_DEBUG_FIXES_QA_MODE"
    static let outputEnvironmentKey = "HOLDTYPE_DEBUG_FIXES_QA_OUTPUT"
    static let showPaletteEnvironmentKey =
        "HOLDTYPE_DEBUG_FIXES_QA_SHOW_PALETTE_ON_LAUNCH"
    static let maximumOutputByteCount = 32 * 1_024

    let mode: Mode
    let output: String?
    let showsPaletteOnLaunch: Bool

    static func resolve(
        environment: [String: String]
    ) -> DebugFixesQAConfiguration? {
        guard environment[
            KeychainInteractionPolicy.automationEnvironmentKey
        ] == "1",
        environment[
            KeychainInteractionPolicy.authenticationUIEnvironmentKey
        ] == KeychainInteractionPolicy.skipAuthenticationUIValue,
        environment[enabledEnvironmentKey] == "1",
        let rawMode = environment[modeEnvironmentKey],
        let mode = Mode(rawValue: rawMode)
        else {
            return nil
        }

        let output = environment[outputEnvironmentKey]
        switch mode {
        case .success:
            guard let output,
                  !output.trimmingCharacters(
                      in: .whitespacesAndNewlines
                  ).isEmpty,
                  output.utf8.count <= maximumOutputByteCount
            else {
                return nil
            }
        case .failure, .timeout, .cancel:
            guard output == nil else {
                return nil
            }
        }

        let showsPaletteOnLaunch: Bool
        switch environment[showPaletteEnvironmentKey] {
        case nil:
            showsPaletteOnLaunch = false
        case "1":
            showsPaletteOnLaunch = true
        default:
            return nil
        }

        return DebugFixesQAConfiguration(
            mode: mode,
            output: output,
            showsPaletteOnLaunch: showsPaletteOnLaunch
        )
    }

    var description: String {
        """
        DebugFixesQAConfiguration(mode: \(mode.rawValue), \
        output: <redacted>, showsPaletteOnLaunch: \(showsPaletteOnLaunch))
        """
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "mode": mode.rawValue,
                "output": "<redacted>",
                "showsPaletteOnLaunch": showsPaletteOnLaunch,
            ]
        )
    }
}

@MainActor
enum DebugFixesQARuntimeFactory {
    static func makeRuntimeIfRequested(
        environment: [String: String]
    ) -> FixesRuntime? {
        guard let configuration = DebugFixesQAConfiguration.resolve(
            environment: environment
        ) else {
            return nil
        }

        var settings = AppSettings.defaults
        settings.setTextFixesConsentAccepted(true)

        return FixesRuntime(
            catalogStore: MacOSTextFixCatalogStore(),
            targetService: FocusedTextTargetService(),
            replacementService: FocusedTextReplacementService(),
            executionService: DebugFixesQAExecutionService(
                configuration: configuration
            ),
            credentialResolver: DebugFixesQACredentialResolver(),
            settingsProvider: {
                settings
            },
            panelPresenter: FixesPalettePanelController(),
            hotkeyCoordinator: FixesHotkeyCoordinator()
        )
    }
}

@MainActor
struct DebugFixesQAExecutionService:
    TextFixExecuting,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    static let defaultTimeoutDelay: Duration = .milliseconds(600)
    static let defaultCancellationWindow: Duration = .seconds(10)

    private let configuration: DebugFixesQAConfiguration
    private let timeoutDelay: Duration
    private let cancellationWindow: Duration

    init(
        configuration: DebugFixesQAConfiguration,
        timeoutDelay: Duration = defaultTimeoutDelay,
        cancellationWindow: Duration = defaultCancellationWindow
    ) {
        self.configuration = configuration
        self.timeoutDelay = timeoutDelay
        self.cancellationWindow = cancellationWindow
    }

    func execute(
        action: TextFixAction,
        sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        try Task.checkCancellation()

        switch configuration.mode {
        case .success:
            guard let output = configuration.output else {
                throw DebugFixesQAExecutionError.invalidConfiguration
            }
            return output
        case .failure:
            throw DebugFixesQAExecutionError.controlledFailure
        case .timeout:
            try await Task.sleep(for: timeoutDelay)
            throw OpenAITextTransformationServiceError.timedOut
        case .cancel:
            try await Task.sleep(for: cancellationWindow)
            throw DebugFixesQAExecutionError.cancellationNotObserved
        }
    }

    func cancelActiveExecution() {
        // FixesRuntime owns and cancels the task that is sleeping above.
    }

    var description: String {
        "DebugFixesQAExecutionService(mode: \(configuration.mode.rawValue), payload: <redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "mode": configuration.mode.rawValue,
                "payload": "<redacted>",
            ]
        )
    }
}

enum DebugFixesQAExecutionError: Error, Equatable, LocalizedError {
    case invalidConfiguration
    case controlledFailure
    case cancellationNotObserved

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "The controlled Fixes QA configuration is invalid."
        case .controlledFailure:
            return "The controlled Fixes QA action failed."
        case .cancellationNotObserved:
            return "The controlled Fixes QA cancellation window expired."
        }
    }
}

struct DebugFixesQACredentialResolver:
    OpenAICredentialResolving,
    CustomStringConvertible,
    CustomDebugStringConvertible {
    func resolveOpenAICredential() throws -> OpenAICredential {
        try OpenAICredential(
            apiKey: "debug-fixes-qa-non-network-credential"
        )
    }

    var description: String {
        "DebugFixesQACredentialResolver(<redacted>)"
    }

    var debugDescription: String {
        description
    }
}

@MainActor
enum DebugFixesQALaunch {
    static let presentationDelayMilliseconds = 900

    static func shouldRequest(
        environment: [String: String]
    ) -> Bool {
        DebugFixesQAConfiguration.resolve(
            environment: environment
        )?.showsPaletteOnLaunch == true
    }

    static func requestIfNeeded(
        environment: [String: String],
        showPalette: @escaping @MainActor () -> Void,
        schedulePresentation: @escaping (
            Int,
            @escaping @MainActor () -> Void
        ) -> Void = { delayMilliseconds, presentation in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(delayMilliseconds)
            ) {
                presentation()
            }
        }
    ) {
        guard shouldRequest(environment: environment) else {
            return
        }

        schedulePresentation(
            presentationDelayMilliseconds,
            showPalette
        )
    }
}
#endif
