import AppKit
import HoldTypeOpenAI
import Testing
@testable import HoldType
struct QuitConfirmationTests {

    @Test func quitCopyWarnsWhenLaunchAtLoginIsNotEnabled() {
        let informativeText = QuitConfirmationCopy.informativeText(launchAtLoginStatus: .disabled)

        #expect(informativeText.contains("will stop listening"))
        #expect(informativeText.contains("will not be available after restart"))
    }

    @Test func quitCopyDoesNotAddRestartWarningWhenLaunchAtLoginIsEnabled() {
        let informativeText = QuitConfirmationCopy.informativeText(launchAtLoginStatus: .enabled)

        #expect(informativeText.contains("will stop listening"))
        #expect(informativeText.contains("will not be available after restart") == false)
    }

    @MainActor
    @Test func menuQuitDismissesBeforeSchedulingTermination() {
        var events: [String] = []
        var scheduledTermination: (@MainActor () -> Void)?

        MenuBarQuitRequest.requestAfterMenuDismissal(
            dismissMenu: {
                events.append("dismiss")
            },
            scheduleTermination: { terminate in
                events.append("schedule")
                scheduledTermination = terminate
            },
            terminate: {
                events.append("terminate")
            }
        )

        #expect(events == ["dismiss", "schedule"])
        scheduledTermination?()
        #expect(events == ["dismiss", "schedule", "terminate"])
    }

    @MainActor
    @Test func applicationDelegateUsesInjectedQuitConfirmationPresenter() async {
        let presenter = FakeQuitConfirmationPresenter(decision: .cancel)
        var prepareCount = 0
        var terminationReplies: [Bool] = []
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: presenter,
            prepareForTermination: {
                prepareCount += 1
            },
            replyToTerminationRequest: { _, shouldTerminate in
                terminationReplies.append(shouldTerminate)
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(presenter.requestCount == 1)
        #expect(prepareCount == 0)

        presenter.decision = .quit

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater)
        #expect(presenter.requestCount == 2)
        await yieldUntil { terminationReplies == [true] }
        #expect(prepareCount == 1)
        #expect(terminationReplies == [true])
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        #expect(presenter.requestCount == 2)
    }

    @MainActor
    @Test func applicationDelegateSkipsQuitConfirmationForUpdaterRelaunch() async {
        let presenter = FakeQuitConfirmationPresenter(decision: .cancel)
        var prepareCount = 0
        var terminationReplies: [Bool] = []
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: presenter,
            isUpdaterRelaunchInProgress: { true },
            prepareForTermination: {
                prepareCount += 1
            },
            replyToTerminationRequest: { _, shouldTerminate in
                terminationReplies.append(shouldTerminate)
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater)
        #expect(presenter.requestCount == 0)
        await yieldUntil { terminationReplies == [true] }
        #expect(prepareCount == 1)
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @MainActor
    @Test func applicationDelegateBoundsTerminationPreparation() async {
        var prepareStarted = false
        var terminationReplies: [Bool] = []
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: FakeQuitConfirmationPresenter(decision: .quit),
            prepareForTermination: {
                prepareStarted = true
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            },
            replyToTerminationRequest: { _, shouldTerminate in
                terminationReplies.append(shouldTerminate)
            },
            terminationTimeoutNanoseconds: 1_000_000
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater)
        await yieldUntil { terminationReplies == [true] }

        #expect(prepareStarted)
        #expect(terminationReplies == [true])
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @MainActor
    @Test func applicationDelegateStartsAndStopsRuntimeComponentsForNormalLaunch() {
        var startCount = 0
        var stopCount = 0
        var clearHistoryCount = 0
        var maintenanceScheduleCount = 0
        var repairCount = 0
        let promptCoordinator = FakeTranscriptionFailurePromptCoordinator()
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: FakeQuitConfirmationPresenter(decision: .quit),
            transcriptionFailurePromptCoordinator: promptCoordinator,
            launchEnvironment: [:],
            clearTranscriptHistory: {
                clearHistoryCount += 1
            },
            startRuntimeComponents: {
                startCount += 1
            },
            stopRuntimeComponents: {
                stopCount += 1
            },
            scheduleProviderStartupMaintenance: {
                maintenanceScheduleCount += 1
            },
            repairInterruptedRecordings: {
                repairCount += 1
            }
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        #expect(startCount == 1)
        #expect(stopCount == 1)
        #expect(clearHistoryCount == 1)
        #expect(maintenanceScheduleCount == 1)
        #expect(repairCount == 1)
        #expect(promptCoordinator.startCount == 1)
        #expect(promptCoordinator.stopCount == 1)
    }

    @MainActor
    @Test func applicationDelegateSkipsRuntimeComponentsForInputMonitoringRecoveryLaunch() {
        var startCount = 0
        var stopCount = 0
        var clearHistoryCount = 0
        var maintenanceScheduleCount = 0
        var repairCount = 0
        let promptCoordinator = FakeTranscriptionFailurePromptCoordinator()
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: FakeQuitConfirmationPresenter(decision: .quit),
            transcriptionFailurePromptCoordinator: promptCoordinator,
            launchEnvironment: [InputMonitoringPermissionLaunchRecovery.requestEnvironmentKey: "1"],
            clearTranscriptHistory: {
                clearHistoryCount += 1
            },
            startRuntimeComponents: {
                startCount += 1
            },
            stopRuntimeComponents: {
                stopCount += 1
            },
            scheduleProviderStartupMaintenance: {
                maintenanceScheduleCount += 1
            },
            repairInterruptedRecordings: {
                repairCount += 1
            }
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        #expect(startCount == 0)
        #expect(stopCount == 0)
        #expect(clearHistoryCount == 0)
        #expect(maintenanceScheduleCount == 0)
        #expect(repairCount == 0)
        #expect(promptCoordinator.startCount == 0)
        #expect(promptCoordinator.stopCount == 0)
    }

    @MainActor
    private func yieldUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

@MainActor
private final class FakeQuitConfirmationPresenter: QuitConfirmationPresenting {
    var decision: QuitConfirmationDecision
    private(set) var requestCount = 0

    init(decision: QuitConfirmationDecision) {
        self.decision = decision
    }

    func requestQuitConfirmation() -> QuitConfirmationDecision {
        requestCount += 1
        return decision
    }
}

@MainActor
private final class FakeTranscriptionFailurePromptCoordinator: TranscriptionFailurePromptCoordinating {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }
}
