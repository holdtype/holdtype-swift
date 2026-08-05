//
//  HoldTypeApp.swift
//  HoldType
//
//  Created by Eugene Potapenko on 6/20/26.
//

import AppKit
import Darwin
import HoldTypeOpenAI
import SwiftUI

@main
struct HoldTypeApp: App {
    @NSApplicationDelegateAdaptor(HoldTypeAppDelegate.self) private var appDelegate

    init() {
        let launchEnvironment = ProcessInfo.processInfo.environment
        let isInputMonitoringRecoveryLaunch = InputMonitoringPermissionLaunchRecovery.shouldRequest(
            environment: launchEnvironment
        )
        #if DEBUG
        let isDebugTranscriptionFailureLaunch = DebugTranscriptionFailurePromptLaunch.shouldRequest(
            environment: launchEnvironment
        )
        let isDebugFixesQALaunch = DebugFixesQALaunch.shouldRequest(
            environment: launchEnvironment
        )
        #else
        let isDebugTranscriptionFailureLaunch = false
        let isDebugFixesQALaunch = false
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            InputMonitoringPermissionLaunchRecovery.requestIfNeeded(environment: launchEnvironment)
        }

        if !isInputMonitoringRecoveryLaunch
            && !isDebugTranscriptionFailureLaunch
            && !isDebugFixesQALaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700)) {
                AppSetupController().presentSetupIfNeededForLaunch()
            }
        }

        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            DebugAccessibilityPermissionRecovery.requestIfNeeded()
        }
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HoldTypeMenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        SettingsScene()
        FixesEditorScene()
        TranscriptHistoryScene()
        TranscriptionFailurePromptScene()
        QuitConfirmationScene()
    }
}

private struct HoldTypeMenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Image(HoldTypeMenuBarIdentity.iconAssetName)
                .renderingMode(.template)
                .accessibilityLabel(HoldTypeMenuBarIdentity.title)
                .help(HoldTypeMenuBarIdentity.helpText)

            if let visibleTitle = HoldTypeMenuBarIdentity.visibleTitle {
                Text(visibleTitle)
            }
        }
        .onAppear {
            SettingsPresentationCoordinator.shared.install {
                AppWindowActivation.showRegularApp()
                openWindow(id: SettingsScene.identifier)
            }
            QuitConfirmationCoordinator.shared.install {
                AppWindowActivation.showRegularApp()
                openWindow(id: QuitConfirmationScene.identifier)
            }
            TranscriptionFailurePromptCoordinator.shared.install {
                AppWindowActivation.showRegularApp()
                openWindow(id: TranscriptionFailurePromptScene.identifier)
            }
        }
    }
}

#if DEBUG
@MainActor
enum DebugAccessibilityPermissionRecovery {
    static let environmentKey = "HOLDTYPE_DEBUG_REQUEST_ACCESSIBILITY"

    static func requestIfNeeded(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        permissionService: AccessibilityPermissionService = AccessibilityPermissionService()
    ) {
        guard environment[environmentKey] == "1" else {
            return
        }

        let status = permissionService.requestPermission()
        if status != .trusted {
            permissionService.openAccessibilitySettings()
        }
    }
}

@MainActor
enum DebugTranscriptionFailurePromptLaunch {
    static let environmentKey = "HOLDTYPE_DEBUG_TRANSCRIPTION_FAILURE"
    static let presentationDelay: DispatchTimeInterval = .milliseconds(500)

    static func shouldRequest(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        reason(from: environment[environmentKey]) != nil
    }

    static func requestIfNeeded(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        presentFailure: @escaping @MainActor (FailedTranscriptionReason) -> Void = { reason in
            DictationRuntime.shared.presentDebugTranscriptionFailure(reason: reason)
        },
        schedulePresentation: @escaping (@escaping @MainActor () -> Void) -> Void = { presentation in
            DispatchQueue.main.asyncAfter(deadline: .now() + presentationDelay) {
                Task { @MainActor in
                    presentation()
                }
            }
        }
    ) {
        guard let reason = reason(from: environment[environmentKey]) else {
            return
        }

        schedulePresentation {
            presentFailure(reason)
        }
    }

    static func reason(from rawValue: String?) -> FailedTranscriptionReason? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "timeout", "timed-out", "timed_out":
            return .timedOut
        case "network", "network-unavailable", "network_unavailable":
            return .networkUnavailable
        case "network-failure", "network_failure":
            return .networkFailure
        case "uncertain", "provider-outcome-uncertain", "provider_outcome_uncertain":
            return .providerOutcomeUncertain
        case "invalid-api-key", "invalid_api_key", "api-key", "api_key":
            return .invalidAPIKey
        case "transcription-settings", "settings", "bad-request", "bad_request":
            return .badRequest
        default:
            return nil
        }
    }
}
#endif

@MainActor
final class HoldTypeAppDelegate: NSObject, NSApplicationDelegate {
    private let specialClipboardHotkeyCoordinator = SpecialClipboardHotkeyCoordinator()
    private let dictationRuntime = DictationRuntime.shared
    private let fixesRuntime = FixesRuntime.shared
    private let floatingIndicatorCoordinator = FloatingIndicatorCoordinator.shared
    private let quitConfirmationRequester: any QuitConfirmationRequesting
    private let transcriptionFailurePromptCoordinator: (any TranscriptionFailurePromptCoordinating)?
    private let launchEnvironment: [String: String]
    private let startRuntimeComponentsOverride: (@MainActor () -> Void)?
    private let stopRuntimeComponentsOverride: (@MainActor () -> Void)?
    private let scheduleProviderStartupMaintenance: @MainActor () -> Void
    private let isUpdaterRelaunchInProgress: @MainActor () -> Bool
    private let repairInterruptedRecordings: @MainActor () -> Void
    private let prepareForTermination: @MainActor () async -> Void
    private let replyToTerminationRequest: @MainActor (NSApplication, Bool) -> Void
    private let requestTermination: @MainActor () -> Void
    private let terminationTimeoutNanoseconds: UInt64
    private var terminationPreparationTask: Task<Void, Never>?
    private var terminationDeadlineTask: Task<Void, Never>?
    private var isTerminationPreparationPending = false
    private var isTerminationPreparationComplete = false
    private var isQuitConfirmationPending = false
    private var hasConfirmedQuit = false
    private var isRequestingQuitConfirmation = false

    override init() {
        quitConfirmationRequester = QuitConfirmationCoordinator.shared
        transcriptionFailurePromptCoordinator = TranscriptionFailurePromptCoordinator.shared
        launchEnvironment = ProcessInfo.processInfo.environment
        startRuntimeComponentsOverride = nil
        stopRuntimeComponentsOverride = nil
        scheduleProviderStartupMaintenance = {
            OpenAIProviderStartupMaintenance.schedule()
        }
        isUpdaterRelaunchInProgress = {
            SoftwareUpdateRelaunchState.isUpdaterRelaunchInProgress
        }
        repairInterruptedRecordings = {
            DictationRuntime.shared.repairInterruptedRecordings()
        }
        prepareForTermination = {
            await DictationRuntime.shared.prepareForTermination()
        }
        replyToTerminationRequest = { application, shouldTerminate in
            application.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        requestTermination = {
            NSApplication.shared.terminate(nil)
        }
        terminationTimeoutNanoseconds = 2_500_000_000
        super.init()
    }

    init(
        quitConfirmationRequester: any QuitConfirmationRequesting,
        transcriptionFailurePromptCoordinator: (any TranscriptionFailurePromptCoordinating)? = nil,
        launchEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        startRuntimeComponents: (@MainActor () -> Void)? = nil,
        stopRuntimeComponents: (@MainActor () -> Void)? = nil,
        scheduleProviderStartupMaintenance: @escaping @MainActor () -> Void = {},
        isUpdaterRelaunchInProgress: @escaping @MainActor () -> Bool = {
            SoftwareUpdateRelaunchState.isUpdaterRelaunchInProgress
        },
        repairInterruptedRecordings: @escaping @MainActor () -> Void = {},
        prepareForTermination: @escaping @MainActor () async -> Void = {},
        replyToTerminationRequest: @escaping @MainActor (NSApplication, Bool) -> Void = { _, _ in },
        requestTermination: @escaping @MainActor () -> Void = {},
        terminationTimeoutNanoseconds: UInt64 = 2_500_000_000
    ) {
        self.quitConfirmationRequester = quitConfirmationRequester
        self.transcriptionFailurePromptCoordinator = transcriptionFailurePromptCoordinator
        self.launchEnvironment = launchEnvironment
        startRuntimeComponentsOverride = startRuntimeComponents
        stopRuntimeComponentsOverride = stopRuntimeComponents
        self.scheduleProviderStartupMaintenance = scheduleProviderStartupMaintenance
        self.isUpdaterRelaunchInProgress = isUpdaterRelaunchInProgress
        self.repairInterruptedRecordings = repairInterruptedRecordings
        self.prepareForTermination = prepareForTermination
        self.replyToTerminationRequest = replyToTerminationRequest
        self.requestTermination = requestTermination
        self.terminationTimeoutNanoseconds = terminationTimeoutNanoseconds
        super.init()
    }

    convenience init(
        quitConfirmationPresenter: any QuitConfirmationPresenting,
        transcriptionFailurePromptCoordinator: (any TranscriptionFailurePromptCoordinating)? = nil,
        launchEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        startRuntimeComponents: (@MainActor () -> Void)? = nil,
        stopRuntimeComponents: (@MainActor () -> Void)? = nil,
        scheduleProviderStartupMaintenance: @escaping @MainActor () -> Void = {},
        isUpdaterRelaunchInProgress: @escaping @MainActor () -> Bool = {
            SoftwareUpdateRelaunchState.isUpdaterRelaunchInProgress
        },
        repairInterruptedRecordings: @escaping @MainActor () -> Void = {},
        prepareForTermination: @escaping @MainActor () async -> Void = {},
        replyToTerminationRequest: @escaping @MainActor (NSApplication, Bool) -> Void = { _, _ in },
        requestTermination: @escaping @MainActor () -> Void = {},
        terminationTimeoutNanoseconds: UInt64 = 2_500_000_000
    ) {
        self.init(
            quitConfirmationRequester: LegacyQuitConfirmationRequester(
                presenter: quitConfirmationPresenter
            ),
            transcriptionFailurePromptCoordinator: transcriptionFailurePromptCoordinator,
            launchEnvironment: launchEnvironment,
            startRuntimeComponents: startRuntimeComponents,
            stopRuntimeComponents: stopRuntimeComponents,
            scheduleProviderStartupMaintenance: scheduleProviderStartupMaintenance,
            isUpdaterRelaunchInProgress: isUpdaterRelaunchInProgress,
            repairInterruptedRecordings: repairInterruptedRecordings,
            prepareForTermination: prepareForTermination,
            replyToTerminationRequest: replyToTerminationRequest,
            requestTermination: requestTermination,
            terminationTimeoutNanoseconds: terminationTimeoutNanoseconds
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isInputMonitoringRecoveryLaunch else {
            return
        }

        scheduleProviderStartupMaintenance()
        repairInterruptedRecordings()
        transcriptionFailurePromptCoordinator?.start()

        if let startRuntimeComponentsOverride {
            startRuntimeComponentsOverride()
        } else {
            floatingIndicatorCoordinator.start()
            specialClipboardHotkeyCoordinator.start()
            dictationRuntime.startHotkeyListening()
            fixesRuntime.startHotkeyListening()
        }

        #if DEBUG
        DebugTranscriptionFailurePromptLaunch.requestIfNeeded(environment: launchEnvironment)
        DebugFixesQALaunch.requestIfNeeded(
            environment: launchEnvironment,
            showPalette: { [fixesRuntime] in
                fixesRuntime.showPalette()
            }
        )
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isTerminationPreparationComplete {
            return .terminateNow
        }
        if isTerminationPreparationPending {
            return .terminateLater
        }

        if !isUpdaterRelaunchInProgress(), !hasConfirmedQuit {
            let wasConfirmedSynchronously = requestQuitConfirmationIfNeeded()
            if !wasConfirmedSynchronously {
                return .terminateCancel
            }
        }

        hasConfirmedQuit = false

        beginTerminationPreparation(for: sender)
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isInputMonitoringRecoveryLaunch else {
            return
        }

        if let stopRuntimeComponentsOverride {
            stopRuntimeComponentsOverride()
        } else {
            floatingIndicatorCoordinator.stop()
            fixesRuntime.stopHotkeyListening()
            dictationRuntime.stopHotkeyListening()
            specialClipboardHotkeyCoordinator.stop()
        }

        transcriptionFailurePromptCoordinator?.stop()
    }

    private func beginTerminationPreparation(for application: NSApplication) {
        isTerminationPreparationPending = true
        terminationPreparationTask = Task { @MainActor [weak self, weak application] in
            guard let self, let application else {
                return
            }
            await self.prepareForTermination()
            self.completeTerminationPreparation(for: application)
        }
        terminationDeadlineTask = Task { @MainActor [weak self, weak application] in
            guard let self, let application else {
                return
            }
            do {
                try await Task.sleep(nanoseconds: self.terminationTimeoutNanoseconds)
            } catch {
                return
            }
            self.completeTerminationPreparation(for: application)
        }
    }

    private func requestQuitConfirmationIfNeeded() -> Bool {
        guard !isQuitConfirmationPending else {
            return false
        }

        isQuitConfirmationPending = true
        isRequestingQuitConfirmation = true
        quitConfirmationRequester.requestQuitConfirmation { [weak self] decision in
            guard let self else {
                return
            }

            self.isQuitConfirmationPending = false
            guard decision == .quit else {
                return
            }

            self.hasConfirmedQuit = true
            guard !self.isRequestingQuitConfirmation else {
                return
            }
            Task { @MainActor [weak self] in
                self?.requestTermination()
            }
        }
        isRequestingQuitConfirmation = false
        return hasConfirmedQuit
    }

    private func completeTerminationPreparation(for application: NSApplication) {
        guard isTerminationPreparationPending else {
            return
        }

        isTerminationPreparationPending = false
        isTerminationPreparationComplete = true
        terminationPreparationTask?.cancel()
        terminationDeadlineTask?.cancel()
        terminationPreparationTask = nil
        terminationDeadlineTask = nil
        replyToTerminationRequest(application, true)
    }

    private var isInputMonitoringRecoveryLaunch: Bool {
        InputMonitoringPermissionLaunchRecovery.shouldRequest(environment: launchEnvironment)
    }
}
