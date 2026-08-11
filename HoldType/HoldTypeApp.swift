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

#if !DEBUG
@main
#endif
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
        normalScenes
    }

    @SceneBuilder
    private var normalScenes: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HoldTypeMenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        SettingsScene()
        DevVlogsScene()
        FixesEditorScene()
        TranscriptHistoryScene()
        TranscriptionFailurePromptScene()
    }
}

#if DEBUG
@main
private enum HoldTypeDebugEntryPoint {
    @MainActor
    static func main() {
        let environment = ProcessInfo.processInfo.environment
        DevVlogsPhase0BStorageTestHostLaunch.startApplication(
            environment: environment,
            startStorageApplication: { DevVlogsPhase0BStorageTestHostApplication.main() },
            startExistingApplication: {
                DevVlogsPhase0BPreviewLaunch.startApplication(
                    environment: environment,
                    startPreviewApplication: { DevVlogsPhase0BPreviewApplication.main() },
                    startExistingApplication: {
                        DevVlogsPhase0BLaunch.startApplication(
                            environment: environment,
                            startNormalApplication: { HoldTypeApp.main() },
                            startHarnessApplication: { DevVlogsPhase0BHarnessApplication.main() }
                        )
                    }
                )
            }
        )
    }
}

private struct DevVlogsPhase0BHarnessApplication: App {
    @NSApplicationDelegateAdaptor(DevVlogsPhase0BLaunchDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            EmptyView()
        } label: {
            EmptyView()
        }
        .menuBarExtraStyle(.window)
    }
}
#endif

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
    private let requestTermination: @MainActor () -> Void
    private let terminationTimeoutNanoseconds: UInt64
    private var terminationPreparationTask: Task<Void, Never>?
    private var terminationDeadlineTask: Task<Void, Never>?
    private var isTerminationPreparationPending = false
    private var isTerminationPreparationComplete = false
    private var isQuitConfirmationPending = false

    override init() {
        quitConfirmationRequester = LegacyQuitConfirmationRequester(
            presenter: NativeQuitConfirmationPresenter()
        )
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
            return .terminateCancel
        }

        if isUpdaterRelaunchInProgress() {
            beginTerminationPreparation()
        } else {
            requestQuitConfirmationIfNeeded()
        }

        return .terminateCancel
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

    private func beginTerminationPreparation() {
        guard !isTerminationPreparationPending, !isTerminationPreparationComplete else {
            return
        }

        isTerminationPreparationPending = true
        terminationPreparationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.prepareForTermination()
            self.completeTerminationPreparation()
        }
        terminationDeadlineTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await Task.sleep(nanoseconds: self.terminationTimeoutNanoseconds)
            } catch {
                return
            }
            self.completeTerminationPreparation()
        }
    }

    private func requestQuitConfirmationIfNeeded() {
        guard !isQuitConfirmationPending else {
            return
        }

        isQuitConfirmationPending = true
        quitConfirmationRequester.requestQuitConfirmation { [weak self] decision in
            guard let self else {
                return
            }

            self.isQuitConfirmationPending = false
            guard decision == .quit else {
                return
            }

            self.beginTerminationPreparation()
        }
    }

    private func completeTerminationPreparation() {
        guard isTerminationPreparationPending else {
            return
        }

        isTerminationPreparationPending = false
        isTerminationPreparationComplete = true
        terminationPreparationTask?.cancel()
        terminationDeadlineTask?.cancel()
        terminationPreparationTask = nil
        terminationDeadlineTask = nil
        requestTermination()
    }

    private var isInputMonitoringRecoveryLaunch: Bool {
        InputMonitoringPermissionLaunchRecovery.shouldRequest(environment: launchEnvironment)
    }
}
