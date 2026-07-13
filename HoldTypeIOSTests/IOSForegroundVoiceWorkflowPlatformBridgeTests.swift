import Foundation
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSForegroundVoiceWorkflowPlatformBridgeTests {
    @Test
    func permissionOwnerBoundsSystemPromptWaitAndRejectsLateCompletion()
        async throws {
        let gate = WorkflowPermissionGate()
        let state = WorkflowPermissionState(gate: gate)
        let adapter = IOSMicrophonePermissionAdapter(client: state.client)
        let owner = IOSForegroundVoiceWorkflowPermissionOwner(
            adapter: adapter,
            timeout: .milliseconds(1),
            sleep: { _ in }
        )

        let outcome = await owner.client.requestIfUndetermined()
        #expect(outcome == .timedOut)

        state.status = .granted
        await gate.open()
        try await waitForBridge { owner.client.read() == .granted }
        #expect(outcome == .timedOut)
        #expect(state.requestCount == 1)
    }

    @Test
    func audioOwnerAllowsOnlyExactOutputOnlyRouteChange() throws {
        let system = WorkflowAudioSystem()
        let adapter = IOSAudioSessionAdapter(system: system)
        let owner = IOSForegroundVoiceWorkflowAudioOwner(adapter: adapter)
        let lease = try owner.activate()
        try lease.freezeAndValidateInput()
        var events: [IOSForegroundVoiceWorkflowAudioEvent] = []
        let observation = lease.observe { events.append($0) }

        system.emit(.routeChanged(.routeConfigurationChange))
        #expect(events.isEmpty)

        system.state = IOSAudioSessionCurrentState(
            inputPorts: [
                IOSAudioSessionInputPort(
                    uid: "different-input",
                    portType: "built-in",
                    selectedDataSourceID: nil
                )
            ],
            isInputAvailable: true,
            isInputMuted: false,
            sampleRate: 48_000,
            inputNumberOfChannels: 1
        )
        system.emit(.routeChanged(.oldDeviceUnavailable))
        #expect(events == [.routeInvalid])

        observation.cancel()
        lease.deactivate()
        #expect(system.activationRequests == [
            .activate,
            .deactivateAndNotifyOthers,
        ])
    }

    @Test
    func finalizationBridgeForwardsExpirationAndEndsAssertionOnce() {
        var expiration: (@MainActor @Sendable (
            IOSForegroundBackgroundTaskIdentifier
        ) -> Void)?
        var endCount = 0
        let identifier = IOSForegroundBackgroundTaskIdentifier(rawValue: 42)
        let background = IOSForegroundFinalizationBackgroundTask(
            client: IOSForegroundBackgroundTaskClient(
                begin: { _, handler in
                    expiration = handler
                    return identifier
                },
                end: { value in
                    #expect(value == identifier)
                    endCount += 1
                }
            ),
            sleep: { _ in try await Task.sleep(for: .seconds(3_600)) }
        )
        let owner = IOSForegroundVoiceWorkflowFinalizationOwner(
            backgroundTask: background
        )
        var expirationCount = 0
        let lease = owner.begin { expirationCount += 1 }

        expiration?(identifier)
        lease?.finish()
        lease?.finish()

        #expect(expirationCount == 1)
        #expect(endCount == 1)
        #expect(!background.hasActiveFinalization)
    }
}

@MainActor
private final class WorkflowPermissionState {
    var status = IOSMicrophonePermissionStatus.undetermined
    private(set) var requestCount = 0
    private let gate: WorkflowPermissionGate

    init(gate: WorkflowPermissionGate) {
        self.gate = gate
    }

    var client: IOSMicrophonePermissionClient {
        IOSMicrophonePermissionClient(
            read: { [weak self] in self?.status ?? .unavailable },
            request: { [weak self] in
                guard let self else { return }
                requestCount += 1
                await gate.wait()
            }
        )
    }
}

private actor WorkflowPermissionGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending { continuation.resume() }
    }
}

@MainActor
private final class WorkflowAudioSystem: IOSAudioSessionSystem {
    var state = IOSAudioSessionCurrentState(
        inputPorts: [
            IOSAudioSessionInputPort(
                uid: "input",
                portType: "built-in",
                selectedDataSourceID: nil
            )
        ],
        isInputAvailable: true,
        isInputMuted: false,
        sampleRate: 48_000,
        inputNumberOfChannels: 1
    )
    private(set) var activationRequests: [IOSAudioSessionActivationRequest] = []
    private var receive: (@MainActor @Sendable (
        IOSAudioSessionSystemEvent
    ) -> Void)?

    func setCategory(_ configuration: IOSAudioSessionConfiguration) throws {}

    func setAllowsHapticsAndSystemSoundsDuringRecording(
        _ allowed: Bool
    ) throws {}

    func setActive(_ request: IOSAudioSessionActivationRequest) throws {
        activationRequests.append(request)
    }

    func currentState() -> IOSAudioSessionCurrentState { state }

    func installEventObserver(
        _ receive: @escaping @MainActor @Sendable (
            IOSAudioSessionSystemEvent
        ) -> Void
    ) -> any IOSAudioSessionSystemObservation {
        self.receive = receive
        return WorkflowAudioObservation { [weak self] in
            self?.receive = nil
        }
    }

    func emit(_ event: IOSAudioSessionSystemEvent) { receive?(event) }
}

@MainActor
private final class WorkflowAudioObservation: IOSAudioSessionSystemObservation {
    private var cancelAction: (@MainActor () -> Void)?

    init(cancel: @escaping @MainActor () -> Void) {
        cancelAction = cancel
    }

    func cancel() {
        let action = cancelAction
        cancelAction = nil
        action?()
    }
}

@MainActor
private func waitForBridge(
    condition: @escaping @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if condition() { return }
        await Task.yield()
    }
    throw WorkflowBridgeTestError.timedOut
}

private enum WorkflowBridgeTestError: Error {
    case timedOut
}
