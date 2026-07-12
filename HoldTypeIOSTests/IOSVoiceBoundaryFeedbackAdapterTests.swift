import Foundation
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceBoundaryFeedbackAdapterTests {
    private let enabled = IOSVoiceBoundaryFeedbackPreferences(
        audioCuesEnabled: true,
        hapticsEnabled: true
    )
    private let disabled = IOSVoiceBoundaryFeedbackPreferences(
        audioCuesEnabled: false,
        hapticsEnabled: false
    )

    @Test func feedbackOrderingStaysOutsideRetainedCapture() async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()

        let startTask = Task {
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .start) != nil
                && fixture.sleep.waiterCount == 1
        }
        let startPlayer = try #require(fixture.player(for: .start))
        #expect(
            Array(fixture.calls.prefix(3)) == [
                .haptic,
                .makePlayer(.start),
                .play(.start),
            ]
        )

        startPlayer.emit(.completed)
        #expect(await startTask.value == .completed)
        #expect(startPlayer.stopCount == 1)
        #expect(adapter.retainedCaptureDidBegin(for: token))

        let callsAtCaptureStart = fixture.calls
        let overlapping = await adapter.prepareStartBoundary(
            for: IOSVoiceBoundaryFeedbackToken(),
            preferences: enabled
        )
        #expect(overlapping == .busy)
        #expect(fixture.calls == callsAtCaptureStart)

        let stopResult = adapter.recorderDidClose(
            for: token,
            disposition: .success,
            preferences: enabled
        )
        #expect(stopResult == .feedbackStarted)
        let stopPlayer = try #require(fixture.player(for: .successStop))

        let firstHaptic = try #require(
            fixture.calls.firstIndex(of: .haptic)
        )
        let startPlay = try #require(
            fixture.calls.firstIndex(of: .play(.start))
        )
        let startStop = try #require(
            fixture.calls.firstIndex(of: .stop(.start))
        )
        let lastHaptic = try #require(
            fixture.calls.lastIndex(of: .haptic)
        )
        let stopPlay = try #require(
            fixture.calls.firstIndex(of: .play(.successStop))
        )
        #expect(firstHaptic < startPlay)
        #expect(startPlay < startStop)
        #expect(startStop < lastHaptic)
        #expect(lastHaptic < stopPlay)

        stopPlayer.emit(.completed)
        #expect(stopPlayer.stopCount == 1)
        fixture.sleep.fire()
    }

    @Test func startCueFailureStopsOnceAndRejectsLateSignals()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let diagnostics = VoiceBoundaryDiagnosticCapture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client,
            diagnose: diagnostics.record
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        let task = Task {
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .start) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .start))

        player.emit(.failed)
        #expect(await task.value == .cueFailed)
        #expect(player.stopCount == 1)

        player.emit(.completed)
        fixture.sleep.fire()
        await Task.yield()
        #expect(player.stopCount == 1)
        #expect(
            diagnostics.values.filter {
                $0 == .staleCallbackIgnored
            }.count == 2
        )
        #expect(adapter.retainedCaptureDidBegin(for: token))
    }

    @Test func callerTaskCancellationStopsOnceAndCannotStartCapture()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        let task = Task {
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .start) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .start))

        task.cancel()
        #expect(await task.value == .callerCancelled)
        #expect(player.stopCount == 1)
        #expect(!adapter.retainedCaptureDidBegin(for: token))

        player.emit(.completed)
        fixture.sleep.fire()
        await Task.yield()
        #expect(player.stopCount == 1)
    }

    @Test func interruptionStopsStartCueOnceAndRetiresTheBoundary()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        let task = Task {
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .start) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .start))

        adapter.cancelStart(for: token, reason: .interrupted)
        #expect(await task.value == .interrupted)
        #expect(player.stopCount == 1)
        #expect(!adapter.retainedCaptureDidBegin(for: token))

        adapter.cancelStart(for: token, reason: .interrupted)
        player.emit(.failed)
        fixture.sleep.fire()
        await Task.yield()
        #expect(player.stopCount == 1)
    }

    @Test func monotonicTwoSecondWatchdogWinsOnce() async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let diagnostics = VoiceBoundaryDiagnosticCapture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client,
            diagnose: diagnostics.record
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        let task = Task {
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .start) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .start))
        #expect(
            fixture.sleep.requestedDurations
                == [IOSVoiceBoundaryFeedbackAdapter.startCueWatchdogDuration]
        )
        #expect(
            IOSVoiceBoundaryFeedbackAdapter.startCueWatchdogDuration
                == .seconds(2)
        )

        fixture.sleep.fire()
        #expect(await task.value == .timedOut)
        #expect(player.stopCount == 1)
        #expect(diagnostics.values.contains(.startBoundaryTimedOut))

        player.emit(.completed)
        #expect(player.stopCount == 1)
        #expect(adapter.retainedCaptureDidBegin(for: token))
    }

    @Test func playerStartFailureFailsClosedAndStopsOnce() async {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.startPlayResult = false
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()

        let result = await adapter.prepareStartBoundary(
            for: token,
            preferences: enabled
        )

        #expect(result == .cueFailed)
        #expect(fixture.player(for: .start)?.stopCount == 1)
        #expect(adapter.retainedCaptureDidBegin(for: token))
        await Task.yield()
        fixture.sleep.fire()
    }

    @Test func synchronousStartCallbackDuringFactoryCompletesWithoutPlaying()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.startFactoryEvent = .completed
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()

        #expect(
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            ) == .completed
        )
        let player = try #require(fixture.player(for: .start))
        #expect(player.stopCount == 1)
        #expect(!fixture.calls.contains(.play(.start)))
        #expect(adapter.retainedCaptureDidBegin(for: token))
    }

    @Test func synchronousStartCallbackDuringPlayWinsExactlyOnce()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.startPlayEvent = .completed
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()

        #expect(
            await adapter.prepareStartBoundary(
                for: token,
                preferences: enabled
            ) == .completed
        )
        let player = try #require(fixture.player(for: .start))
        #expect(player.stopCount == 1)
        #expect(
            fixture.calls.filter { $0 == .play(.start) }.count == 1
        )
        #expect(adapter.retainedCaptureDidBegin(for: token))
        await Task.yield()
        fixture.sleep.fire()
    }

    @Test func synchronousStopCallbackDuringFactoryReturnsCompletedNotStarted()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.stopFactoryEvent = .completed
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        #expect(
            await adapter.prepareStartBoundary(
                for: token,
                preferences: disabled
            ) == .completed
        )
        #expect(adapter.retainedCaptureDidBegin(for: token))

        #expect(
            adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            ) == .feedbackCompleted
        )
        let player = try #require(fixture.player(for: .successStop))
        #expect(player.stopCount == 1)
        #expect(!fixture.calls.contains(.play(.successStop)))
    }

    @Test func synchronousStopCallbackDuringPlayReturnsCompletedNotStarted()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.stopPlayEvent = .completed
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        #expect(
            await adapter.prepareStartBoundary(
                for: token,
                preferences: disabled
            ) == .completed
        )
        #expect(adapter.retainedCaptureDidBegin(for: token))

        #expect(
            adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            ) == .feedbackCompleted
        )
        let player = try #require(fixture.player(for: .successStop))
        #expect(player.stopCount == 1)
        #expect(
            fixture.calls.filter {
                $0 == .play(.successStop)
            }.count == 1
        )
    }

    @Test func cancelAndInterruptionAfterRecorderCloseNeverEmitSuccessFeedback() async {
        for disposition in [
            IOSVoiceBoundaryRecorderCloseDisposition.cancelled,
            .interrupted,
        ] {
            let fixture = VoiceBoundaryFeedbackFixture()
            let adapter = IOSVoiceBoundaryFeedbackAdapter(
                client: fixture.client
            )
            let token = IOSVoiceBoundaryFeedbackToken()

            #expect(
                await adapter.prepareStartBoundary(
                    for: token,
                    preferences: disabled
                ) == .completed
            )
            #expect(adapter.retainedCaptureDidBegin(for: token))
            let callsDuringCapture = fixture.calls

            #expect(
                adapter.recorderDidClose(
                    for: token,
                    disposition: disposition,
                    preferences: enabled
                ) == .feedbackSkipped
            )
            #expect(fixture.calls == callsDuringCapture)
            #expect(fixture.player(for: .successStop) == nil)
        }
    }

    @Test func absentBundledCueURLsFailClosedWithoutRealFeedback() async {
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: .live(startCueURL: nil, successStopCueURL: nil)
        )
        let token = IOSVoiceBoundaryFeedbackToken()
        let cueOnly = IOSVoiceBoundaryFeedbackPreferences(
            audioCuesEnabled: true,
            hapticsEnabled: false
        )

        #expect(
            await adapter.prepareStartBoundary(
                for: token,
                preferences: cueOnly
            ) == .cueUnavailable
        )
        #expect(adapter.retainedCaptureDidBegin(for: token))
        #expect(
            adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: cueOnly
            ) == .cueUnavailable
        )
    }

    @Test func publicDescriptionsAndDiagnosticsStayRedacted() async {
        let fixture = VoiceBoundaryFeedbackFixture()
        let diagnostics = VoiceBoundaryDiagnosticCapture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client,
            diagnose: diagnostics.record
        )
        let token = IOSVoiceBoundaryFeedbackToken(
            rawValue: UUID(
                uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )!
        )
        _ = await adapter.prepareStartBoundary(
            for: token,
            preferences: disabled
        )
        let canaries = [
            token.rawValue.uuidString.lowercased(),
            "private-start-cue-url",
        ]

        for value in [
            String(describing: token),
            String(reflecting: token),
            String(describing: fixture.client),
            String(reflecting: fixture.client),
            String(describing: adapter),
            String(reflecting: adapter),
            diagnostics.values.map(\.rawValue).joined(separator: " "),
        ] {
            #expect(value.contains("<redacted>") || !value.isEmpty)
            for canary in canaries {
                #expect(!value.lowercased().contains(canary))
            }
        }
        #expect(Mirror(reflecting: token).children.isEmpty)
        #expect(Mirror(reflecting: fixture.client).children.isEmpty)
        #expect(Mirror(reflecting: adapter).children.isEmpty)
    }
}

@MainActor
private final class VoiceBoundaryFeedbackFixture {
    enum Call: Equatable {
        case haptic
        case makePlayer(IOSVoiceBoundaryCue)
        case play(IOSVoiceBoundaryCue)
        case stop(IOSVoiceBoundaryCue)
    }

    var startPlayResult = true
    var stopPlayResult = true
    var startFactoryEvent: IOSVoiceBoundaryPlayerEvent?
    var stopFactoryEvent: IOSVoiceBoundaryPlayerEvent?
    var startPlayEvent: IOSVoiceBoundaryPlayerEvent?
    var stopPlayEvent: IOSVoiceBoundaryPlayerEvent?
    var startFactoryError: IOSVoiceBoundaryFeedbackSystemError?
    var stopFactoryError: IOSVoiceBoundaryFeedbackSystemError?
    private(set) var calls: [Call] = []
    private(set) var players: [VoiceBoundaryPlayerFixture] = []
    let sleep = VoiceBoundarySleepFixture()

    var client: IOSVoiceBoundaryFeedbackClient {
        IOSVoiceBoundaryFeedbackClient(
            makePlayer: { [weak self] cue, receive in
                guard let self else {
                    throw IOSVoiceBoundaryFeedbackSystemError
                        .playerCreationFailed
                }
                calls.append(.makePlayer(cue))
                let error = cue == .start
                    ? startFactoryError
                    : stopFactoryError
                if let error { throw error }
                let player = VoiceBoundaryPlayerFixture(
                    cue: cue,
                    playResult: cue == .start
                        ? startPlayResult
                        : stopPlayResult,
                    playEvent: cue == .start
                        ? startPlayEvent
                        : stopPlayEvent,
                    receive: receive,
                    record: { [weak self] call in
                        self?.calls.append(call)
                    }
                )
                players.append(player)
                let factoryEvent = cue == .start
                    ? startFactoryEvent
                    : stopFactoryEvent
                if let factoryEvent { receive(factoryEvent) }
                return player
            },
            performHaptic: { [weak self] in
                self?.calls.append(.haptic)
            },
            sleep: { [sleep] duration in
                try await sleep.wait(for: duration)
            }
        )
    }

    func player(
        for cue: IOSVoiceBoundaryCue
    ) -> VoiceBoundaryPlayerFixture? {
        players.last { $0.cue == cue }
    }
}

@MainActor
private final class VoiceBoundaryPlayerFixture:
    IOSVoiceBoundaryAudioPlayer
{
    let cue: IOSVoiceBoundaryCue
    private let playResult: Bool
    private let playEvent: IOSVoiceBoundaryPlayerEvent?
    private let receive:
        IOSVoiceBoundaryFeedbackClient.PlayerEventHandler
    private let record: @MainActor (VoiceBoundaryFeedbackFixture.Call) -> Void
    private(set) var stopCount = 0

    init(
        cue: IOSVoiceBoundaryCue,
        playResult: Bool,
        playEvent: IOSVoiceBoundaryPlayerEvent?,
        receive: @escaping IOSVoiceBoundaryFeedbackClient.PlayerEventHandler,
        record: @escaping @MainActor (
            VoiceBoundaryFeedbackFixture.Call
        ) -> Void
    ) {
        self.cue = cue
        self.playResult = playResult
        self.playEvent = playEvent
        self.receive = receive
        self.record = record
    }

    func play() -> Bool {
        record(.play(cue))
        if let playEvent { receive(playEvent) }
        return playResult
    }

    func stop() {
        stopCount += 1
        record(.stop(cue))
    }

    func emit(_ event: IOSVoiceBoundaryPlayerEvent) {
        receive(event)
    }
}

@MainActor
private final class VoiceBoundarySleepFixture {
    private var waiters: [CheckedContinuation<Void, Error>] = []
    private(set) var requestedDurations: [Duration] = []

    var waiterCount: Int { waiters.count }

    func wait(for duration: Duration) async throws {
        requestedDurations.append(duration)
        if Task.isCancelled { throw CancellationError() }
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func fire() {
        let waiters = waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

@MainActor
private final class VoiceBoundaryDiagnosticCapture {
    private(set) var values: [IOSVoiceBoundaryFeedbackDiagnostic] = []

    func record(_ value: IOSVoiceBoundaryFeedbackDiagnostic) {
        values.append(value)
    }
}

@MainActor
private func feedbackEventually(
    _ predicate: @escaping @MainActor @Sendable () -> Bool
) async throws {
    for _ in 0..<100 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for boundary feedback state.")
}
