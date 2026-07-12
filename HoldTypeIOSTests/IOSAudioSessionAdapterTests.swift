import AVFAudio
import Foundation
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSAudioSessionAdapterTests {
    @Test func configuresAndActivatesWithOnlyFrozenOptionsThenNotifiesOnDeactivation()
        throws {
        let system = AudioSessionSystemFixture()
        let adapter = IOSAudioSessionAdapter(system: system)
        let token = IOSAudioSessionAttemptToken()

        try adapter.configureAndActivate(for: token)

        #expect(
            system.calls == [
                .setCategory(
                    IOSAudioSessionConfiguration(
                        category: .playAndRecord,
                        mode: .default,
                        options: [
                            .allowBluetoothHFP,
                            .defaultToSpeaker,
                        ]
                    )
                ),
                .setHapticsAllowed(false),
                .setActive(.activate),
            ]
        )

        try adapter.deactivate(for: token)
        #expect(
            system.calls.last == .setActive(.deactivateAndNotifyOthers)
        )

        #expect(throws: IOSAudioSessionAdapterError.staleAttempt) {
            try adapter.deactivate(for: token)
        }
        #expect(
            system.calls.filter {
                $0 == .setActive(.deactivateAndNotifyOthers)
            }.count == 1
        )
    }

    @Test func refusesASecondAttemptWithoutReconfiguringTheSession()
        throws {
        let system = AudioSessionSystemFixture()
        let adapter = IOSAudioSessionAdapter(system: system)

        try adapter.configureAndActivate(
            for: IOSAudioSessionAttemptToken()
        )
        let firstCalls = system.calls

        #expect(throws: IOSAudioSessionAdapterError.attemptAlreadyActive) {
            try adapter.configureAndActivate(
                for: IOSAudioSessionAttemptToken()
            )
        }
        #expect(system.calls == firstCalls)
    }

    @Test func mapsSystemFailuresToPayloadFreeErrorsAndDiagnostics() {
        let failureCases: [(
            AudioSessionSystemFixture.FailurePoint,
            IOSAudioSessionAdapterError
        )] = [
            (.category, .categoryConfigurationFailed),
            (.haptics, .hapticsConfigurationFailed),
            (.activation, .activationFailed),
        ]

        for (failurePoint, expectedError) in failureCases {
            let system = AudioSessionSystemFixture(
                failurePoint: failurePoint
            )
            let diagnostics = AudioSessionDiagnosticCapture()
            let adapter = IOSAudioSessionAdapter(
                system: system,
                diagnose: diagnostics.record
            )

            #expect(throws: expectedError) {
                try adapter.configureAndActivate(
                    for: IOSAudioSessionAttemptToken()
                )
            }
            #expect(diagnostics.values.last == .operationFailed)
        }

        let system = AudioSessionSystemFixture()
        let diagnostics = AudioSessionDiagnosticCapture()
        let adapter = IOSAudioSessionAdapter(
            system: system,
            diagnose: diagnostics.record
        )
        let token = IOSAudioSessionAttemptToken()
        try? adapter.configureAndActivate(for: token)
        system.failurePoint = .deactivation

        #expect(throws: IOSAudioSessionAdapterError.deactivationFailed) {
            try adapter.deactivate(for: token)
        }
        #expect(diagnostics.values.last == .operationFailed)
        #expect(
            diagnostics.values.allSatisfy {
                !$0.rawValue.contains(token.rawValue.uuidString)
                && !$0.rawValue.contains("built-in-mic-private-uid")
            }
        )
    }

    @Test func freezesTheExactInputIdentityAndActiveFormat() throws {
        let state = audioSessionState(
            uid: "built-in-mic-private-uid",
            portType: "MicrophoneBuiltIn",
            selectedDataSourceID: 42,
            sampleRate: 48_000,
            channels: 1
        )
        let system = AudioSessionSystemFixture(currentState: state)
        let adapter = IOSAudioSessionAdapter(system: system)
        let token = IOSAudioSessionAttemptToken()
        try adapter.configureAndActivate(for: token)

        let frozen = try adapter.freezeCurrentInput(for: token)

        #expect(
            frozen == IOSAudioSessionFrozenInput(
                uid: "built-in-mic-private-uid",
                portType: "MicrophoneBuiltIn",
                selectedDataSourceID: 42,
                sampleRate: 48_000,
                inputNumberOfChannels: 1
            )
        )
        #expect(system.calls.last == .currentState)
    }

    @Test func inputFreezeFailsClosedForUnavailableAmbiguousOrInvalidState()
        throws {
        let cases: [(IOSAudioSessionCurrentState, IOSAudioSessionAdapterError)] = [
            (
                audioSessionState(isInputAvailable: false),
                .inputUnavailable
            ),
            (
                audioSessionState(isInputMuted: true),
                .inputUnavailable
            ),
            (
                audioSessionState(inputPorts: []),
                .ambiguousInput
            ),
            (
                audioSessionState(
                    inputPorts: [
                        audioInputPort(uid: "first"),
                        audioInputPort(uid: "second"),
                    ]
                ),
                .ambiguousInput
            ),
            (
                audioSessionState(uid: ""),
                .invalidInputIdentity
            ),
            (
                audioSessionState(sampleRate: 0),
                .invalidInputFormat
            ),
            (
                audioSessionState(channels: 0),
                .invalidInputFormat
            ),
        ]

        for (state, expectedError) in cases {
            let system = AudioSessionSystemFixture(currentState: state)
            let adapter = IOSAudioSessionAdapter(system: system)
            let token = IOSAudioSessionAttemptToken()
            try adapter.configureAndActivate(for: token)

            #expect(throws: expectedError) {
                try adapter.freezeCurrentInput(for: token)
            }
        }
    }

    @Test func emitsTheCompleteEventMatrixWithCurrentRouteReinspection()
        throws {
        let firstState = audioSessionState(
            uid: "first-input",
            sampleRate: 44_100
        )
        let secondState = audioSessionState(
            uid: "second-input",
            isInputMuted: true,
            sampleRate: 48_000
        )
        let system = AudioSessionSystemFixture(currentState: firstState)
        let events = AudioSessionEventCapture()
        let adapter = IOSAudioSessionAdapter(system: system)
        let token = IOSAudioSessionAttemptToken()
        let subscription = adapter.observeEvents(
            for: token,
            receive: events.record
        )

        system.emit(.interruptionBegan)
        system.emit(.interruptionEnded)
        system.emit(.routeChanged(.oldDeviceUnavailable))
        system.currentStateValue = secondState
        system.emit(.inputMuteChanged)
        system.emit(.mediaServicesLost)
        system.emit(.mediaServicesReset)

        #expect(
            events.values.map(\.event) == [
                .interruptionBegan,
                .interruptionEnded,
                .routeChanged(
                    reason: .oldDeviceUnavailable,
                    currentState: firstState
                ),
                .inputMuteChanged(currentState: secondState),
                .mediaServicesLost,
                .mediaServicesReset,
            ]
        )
        #expect(
            events.values.allSatisfy {
                $0.attemptToken == token
                    && $0.generation == subscription.generation
            }
        )
        #expect(
            system.calls.filter { $0 == .currentState }.count == 2
        )
        #expect(
            system.calls.filter { call in
                if case .setActive = call { return true }
                return false
            }.isEmpty
        )
    }

    @Test func replacementAndCancellationRejectLateGenerationCallbacks() {
        let system = AudioSessionSystemFixture()
        let firstEvents = AudioSessionEventCapture()
        let secondEvents = AudioSessionEventCapture()
        let diagnostics = AudioSessionDiagnosticCapture()
        let adapter = IOSAudioSessionAdapter(
            system: system,
            diagnose: diagnostics.record
        )

        let first = adapter.observeEvents(
            for: IOSAudioSessionAttemptToken(),
            receive: firstEvents.record
        )
        let secondToken = IOSAudioSessionAttemptToken()
        let second = adapter.observeEvents(
            for: secondToken,
            receive: secondEvents.record
        )

        #expect(first.generation != second.generation)
        #expect(system.observations[0].cancelCount == 1)

        system.emit(.mediaServicesLost, observerAt: 0)
        system.emit(.mediaServicesReset, observerAt: 1)
        #expect(firstEvents.values.isEmpty)
        #expect(
            secondEvents.values == [
                IOSAudioSessionEventEnvelope(
                    attemptToken: secondToken,
                    generation: second.generation,
                    event: .mediaServicesReset
                ),
            ]
        )

        second.cancel()
        second.cancel()
        #expect(system.observations[1].cancelCount == 1)
        system.emit(.interruptionBegan, observerAt: 1)
        #expect(secondEvents.values.count == 1)
        #expect(
            diagnostics.values.filter {
                $0 == .staleCallbackIgnored
            }.count == 2
        )
    }

    @Test func productionBridgePreservesCrossThreadFIFOAndRejectsStaleGeneration()
        async throws {
        let system = AudioSessionSystemFixture()
        let staleEvents = AudioSessionEventCapture()
        let currentEvents = AudioSessionEventCapture()
        let diagnostics = AudioSessionDiagnosticCapture()
        let adapter = IOSAudioSessionAdapter(
            system: system,
            diagnose: diagnostics.record
        )

        _ = adapter.observeEvents(
            for: IOSAudioSessionAttemptToken(),
            receive: staleEvents.record
        )
        let staleBridge = IOSAudioSessionNotificationBridge(
            receive: system.eventHandler(at: 0)
        )

        let currentToken = IOSAudioSessionAttemptToken()
        let currentSubscription = adapter.observeEvents(
            for: currentToken,
            receive: currentEvents.record
        )
        let currentBridge = IOSAudioSessionNotificationBridge(
            receive: system.eventHandler(at: 1)
        )
        let staleBurst: [IOSAudioSessionSystemEvent] = [
            .mediaServicesLost,
            .interruptionBegan,
            .mediaServicesReset,
        ]
        let currentBurst: [IOSAudioSessionSystemEvent] = [
            .interruptionBegan,
            .mediaServicesLost,
            .interruptionEnded,
            .mediaServicesReset,
        ]

        sendCrossThreadBurst(staleBurst, to: staleBridge)
        sendCrossThreadBurst(currentBurst, to: currentBridge)
        try await audioSessionEventually {
            currentEvents.values.count == currentBurst.count
                && diagnostics.values.filter {
                    $0 == .staleCallbackIgnored
                }.count == staleBurst.count
        }

        #expect(staleEvents.values.isEmpty)
        #expect(
            currentEvents.values.map(\.event) == [
                .interruptionBegan,
                .mediaServicesLost,
                .interruptionEnded,
                .mediaServicesReset,
            ]
        )
        #expect(
            currentEvents.values.allSatisfy {
                $0.attemptToken == currentToken
                    && $0.generation == currentSubscription.generation
            }
        )
    }

    @Test func productionNotificationDecoderDropsResumeAdviceAndRawPayloads() {
        let interruptionBegan = Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [
                AVAudioSessionInterruptionTypeKey:
                    AVAudioSession.InterruptionType.began.rawValue,
            ]
        )
        let interruptionEndedWithResumeAdvice = Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [
                AVAudioSessionInterruptionTypeKey:
                    AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey:
                    AVAudioSession.InterruptionOptions.shouldResume.rawValue,
            ]
        )

        #expect(
            IOSAVAudioSessionSystem.systemEvent(from: interruptionBegan)
                == .interruptionBegan
        )
        #expect(
            IOSAVAudioSessionSystem.systemEvent(
                from: interruptionEndedWithResumeAdvice
            ) == .interruptionEnded
        )
        #expect(
            IOSAVAudioSessionSystem.systemEvent(
                from: Notification(
                    name: AVAudioApplication
                        .inputMuteStateChangeNotification,
                    userInfo: [AVAudioApplication.muteStateKey: true]
                )
            ) == .inputMuteChanged
        )
        #expect(
            IOSAVAudioSessionSystem.systemEvent(
                from: Notification(
                    name: AVAudioSession
                        .mediaServicesWereLostNotification
                )
            ) == .mediaServicesLost
        )
        #expect(
            IOSAVAudioSessionSystem.systemEvent(
                from: Notification(
                    name: AVAudioSession
                        .mediaServicesWereResetNotification
                )
            ) == .mediaServicesReset
        )
    }

    @Test func productionNotificationDecoderNormalizesEveryStableRouteReason() {
        let cases: [(
            AVAudioSession.RouteChangeReason,
            IOSAudioRouteChangeReason
        )] = [
            (.unknown, .unknown),
            (.newDeviceAvailable, .newDeviceAvailable),
            (.oldDeviceUnavailable, .oldDeviceUnavailable),
            (.categoryChange, .categoryChange),
            (.override, .override),
            (.wakeFromSleep, .wakeFromSleep),
            (.noSuitableRouteForCategory, .noSuitableRouteForCategory),
            (.routeConfigurationChange, .routeConfigurationChange),
        ]

        for (systemReason, expectedReason) in cases {
            let notification = Notification(
                name: AVAudioSession.routeChangeNotification,
                userInfo: [
                    AVAudioSessionRouteChangeReasonKey:
                        systemReason.rawValue,
                    AVAudioSessionRouteChangePreviousRouteKey:
                        "must-not-cross-seam",
                ]
            )
            #expect(
                IOSAVAudioSessionSystem.systemEvent(from: notification)
                    == .routeChanged(expectedReason)
            )
        }

        #expect(
            IOSAVAudioSessionSystem.systemEvent(
                from: Notification(
                    name: AVAudioSession.routeChangeNotification
                )
            ) == .routeChanged(.unknown)
        )
    }
}

@MainActor
private final class AudioSessionSystemFixture: IOSAudioSessionSystem {
    enum FailurePoint: Equatable {
        case category
        case haptics
        case activation
        case deactivation
    }

    enum Call: Equatable {
        case setCategory(IOSAudioSessionConfiguration)
        case setHapticsAllowed(Bool)
        case setActive(IOSAudioSessionActivationRequest)
        case currentState
        case installEventObserver
    }

    private struct FixtureError: Error {}

    var failurePoint: FailurePoint?
    var currentStateValue: IOSAudioSessionCurrentState
    private(set) var calls: [Call] = []
    private(set) var observations: [AudioSessionObservationFixture] = []
    private var eventHandlers: [
        @MainActor @Sendable (IOSAudioSessionSystemEvent) -> Void
    ] = []

    init(
        currentState: IOSAudioSessionCurrentState = audioSessionState(),
        failurePoint: FailurePoint? = nil
    ) {
        self.currentStateValue = currentState
        self.failurePoint = failurePoint
    }

    func setCategory(_ configuration: IOSAudioSessionConfiguration) throws {
        calls.append(.setCategory(configuration))
        if failurePoint == .category { throw FixtureError() }
    }

    func setAllowsHapticsAndSystemSoundsDuringRecording(
        _ allowed: Bool
    ) throws {
        calls.append(.setHapticsAllowed(allowed))
        if failurePoint == .haptics { throw FixtureError() }
    }

    func setActive(_ request: IOSAudioSessionActivationRequest) throws {
        calls.append(.setActive(request))
        if request == .activate, failurePoint == .activation {
            throw FixtureError()
        }
        if request == .deactivateAndNotifyOthers,
           failurePoint == .deactivation {
            throw FixtureError()
        }
    }

    func currentState() -> IOSAudioSessionCurrentState {
        calls.append(.currentState)
        return currentStateValue
    }

    func installEventObserver(
        _ receive: @escaping @MainActor @Sendable (
            IOSAudioSessionSystemEvent
        ) -> Void
    ) -> any IOSAudioSessionSystemObservation {
        calls.append(.installEventObserver)
        eventHandlers.append(receive)
        let observation = AudioSessionObservationFixture()
        observations.append(observation)
        return observation
    }

    func emit(
        _ event: IOSAudioSessionSystemEvent,
        observerAt index: Int? = nil
    ) {
        let resolvedIndex = index ?? eventHandlers.count - 1
        eventHandlers[resolvedIndex](event)
    }

    func eventHandler(
        at index: Int
    ) -> @MainActor @Sendable (IOSAudioSessionSystemEvent) -> Void {
        eventHandlers[index]
    }
}

@MainActor
private final class AudioSessionObservationFixture:
    IOSAudioSessionSystemObservation
{
    private(set) var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

@MainActor
private final class AudioSessionEventCapture {
    private(set) var values: [IOSAudioSessionEventEnvelope] = []

    func record(_ value: IOSAudioSessionEventEnvelope) {
        values.append(value)
    }
}

@MainActor
private final class AudioSessionDiagnosticCapture {
    private(set) var values: [IOSAudioSessionDiagnostic] = []

    func record(_ value: IOSAudioSessionDiagnostic) {
        values.append(value)
    }
}

private func audioInputPort(
    uid: String = "input-uid",
    portType: String = "MicrophoneBuiltIn",
    selectedDataSourceID: Int? = nil
) -> IOSAudioSessionInputPort {
    IOSAudioSessionInputPort(
        uid: uid,
        portType: portType,
        selectedDataSourceID: selectedDataSourceID
    )
}

private func audioSessionState(
    inputPorts: [IOSAudioSessionInputPort]? = nil,
    uid: String = "input-uid",
    portType: String = "MicrophoneBuiltIn",
    selectedDataSourceID: Int? = nil,
    isInputAvailable: Bool = true,
    isInputMuted: Bool = false,
    sampleRate: Double = 44_100,
    channels: Int = 1
) -> IOSAudioSessionCurrentState {
    IOSAudioSessionCurrentState(
        inputPorts: inputPorts ?? [
            audioInputPort(
                uid: uid,
                portType: portType,
                selectedDataSourceID: selectedDataSourceID
            ),
        ],
        isInputAvailable: isInputAvailable,
        isInputMuted: isInputMuted,
        sampleRate: sampleRate,
        inputNumberOfChannels: channels
    )
}

private func sendCrossThreadBurst(
    _ events: [IOSAudioSessionSystemEvent],
    to bridge: IOSAudioSessionNotificationBridge
) {
    let gates = (0...events.count).map { _ in
        DispatchSemaphore(value: 0)
    }
    let group = DispatchGroup()
    gates[0].signal()

    for (index, event) in events.enumerated() {
        group.enter()
        DispatchQueue.global(qos: .userInteractive)
            .async {
                gates[index].wait()
                bridge.send(event)
                gates[index + 1].signal()
                group.leave()
            }
    }

    group.wait()
}

@MainActor
private func audioSessionEventually(
    _ predicate: @escaping @MainActor @Sendable () -> Bool
) async throws {
    for _ in 0..<100 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for audio-session delivery.")
}
