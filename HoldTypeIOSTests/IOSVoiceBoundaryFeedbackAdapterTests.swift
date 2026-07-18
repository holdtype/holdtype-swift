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

        let stopTask = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
        }
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
        #expect(await stopTask.value == .feedbackCompleted)
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
            await adapter.recorderDidClose(
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
            await adapter.recorderDidClose(
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

    @Test func stopCueFailureIsTerminalAndStopsPlayerBeforeReturn()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(client: fixture.client)
        let token = try await beginCapture(adapter: adapter, fixture: fixture)
        let task = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
        }
        let player = try #require(fixture.player(for: .successStop))

        player.emit(.failed)

        #expect(await task.value == .cueFailed)
        #expect(player.stopCount == 1)
        player.emit(.completed)
        fixture.sleep.fire()
        await Task.yield()
        #expect(player.stopCount == 1)
    }

    @Test func unavailableStopCueReturnsWithoutStartingPlayer() async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.stopFactoryError = .cueUnavailable
        let adapter = IOSVoiceBoundaryFeedbackAdapter(client: fixture.client)
        let token = try await beginCapture(adapter: adapter, fixture: fixture)

        #expect(
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            ) == .cueUnavailable
        )
        #expect(fixture.player(for: .successStop) == nil)
        #expect(!fixture.calls.contains(.play(.successStop)))
    }

    @Test func stopCueWatchdogStopsOnceBeforeReturningTimeout()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let diagnostics = VoiceBoundaryDiagnosticCapture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client,
            diagnose: diagnostics.record
        )
        let token = try await beginCapture(adapter: adapter, fixture: fixture)
        let task = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .successStop))
        #expect(
            fixture.sleep.requestedDurations
                == [
                    IOSVoiceBoundaryFeedbackAdapter
                        .successStopCueWatchdogDuration,
                ]
        )
        #expect(
            IOSVoiceBoundaryFeedbackAdapter.successStopCueWatchdogDuration
                == .seconds(2)
        )

        fixture.sleep.fire()

        #expect(await task.value == .timedOut)
        #expect(player.stopCount == 1)
        #expect(diagnostics.values.contains(.successFeedbackTimedOut))
        player.emit(.completed)
        #expect(player.stopCount == 1)
    }

    @Test func stopFeedbackTaskCancellationStopsOnceAndRejectsLateSignals()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let diagnostics = VoiceBoundaryDiagnosticCapture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(
            client: fixture.client,
            diagnose: diagnostics.record
        )
        let token = try await beginCapture(adapter: adapter, fixture: fixture)
        let task = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
                && fixture.sleep.waiterCount == 1
        }
        let player = try #require(fixture.player(for: .successStop))

        task.cancel()

        #expect(await task.value == .feedbackSkipped)
        #expect(player.stopCount == 1)
        player.emit(.completed)
        fixture.sleep.fire()
        await Task.yield()
        #expect(player.stopCount == 1)
        #expect(diagnostics.values.contains(.staleCallbackIgnored))
    }

    @Test func recorderClosePrecedesEverySuccessFeedbackSurface()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(client: fixture.client)
        let token = try await beginCapture(adapter: adapter, fixture: fixture)
        fixture.markRecorderClosed()
        let task = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
        }
        let player = try #require(fixture.player(for: .successStop))
        let close = try #require(fixture.calls.firstIndex(of: .recorderClosed))
        let haptic = try #require(fixture.calls.lastIndex(of: .haptic))
        let makePlayer = try #require(
            fixture.calls.firstIndex(of: .makePlayer(.successStop))
        )
        let play = try #require(
            fixture.calls.firstIndex(of: .play(.successStop))
        )
        #expect(close < haptic)
        #expect(haptic < makePlayer)
        #expect(makePlayer < play)

        player.emit(.completed)
        #expect(await task.value == .feedbackCompleted)
        #expect(player.stopCount == 1)
        fixture.sleep.fire()
    }

    @Test func reentrantStartCannotEnterDuringStopBoundaryHaptic()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        let adapter = IOSVoiceBoundaryFeedbackAdapter(client: fixture.client)
        let token = try await beginCapture(adapter: adapter, fixture: fixture)
        let overlappingToken = IOSVoiceBoundaryFeedbackToken()
        let overlappingPreferences = disabled
        var reentrantStart: Task<IOSVoiceBoundaryStartResult, Never>?
        fixture.hapticAction = {
            reentrantStart = Task {
                await adapter.prepareStartBoundary(
                    for: overlappingToken,
                    preferences: overlappingPreferences
                )
            }
        }
        let stopTask = Task {
            await adapter.recorderDidClose(
                for: token,
                disposition: .success,
                preferences: enabled
            )
        }
        try await feedbackEventually {
            fixture.player(for: .successStop) != nil
                && reentrantStart != nil
        }
        let player = try #require(fixture.player(for: .successStop))
        let overlappingResult = await reentrantStart?.value

        #expect(overlappingResult == .busy)
        player.emit(.completed)
        #expect(await stopTask.value == .feedbackCompleted)
        #expect(player.stopCount == 1)
        #expect(!adapter.retainedCaptureDidBegin(for: overlappingToken))
        fixture.sleep.fire()
    }

    @Test func unexpectedStopWatchdogFailureCompletesWithoutHanging()
        async throws {
        let fixture = VoiceBoundaryFeedbackFixture()
        fixture.sleep.error = VoiceBoundarySleepFixture.Failure.injected
        let adapter = IOSVoiceBoundaryFeedbackAdapter(client: fixture.client)
        let token = try await beginCapture(adapter: adapter, fixture: fixture)

        let result = await adapter.recorderDidClose(
            for: token,
            disposition: .success,
            preferences: enabled
        )

        let player = try #require(fixture.player(for: .successStop))
        #expect(result == .cueFailed)
        #expect(player.stopCount == 1)
        #expect(
            fixture.sleep.requestedDurations
                == [
                    IOSVoiceBoundaryFeedbackAdapter
                        .successStopCueWatchdogDuration,
                ]
        )
    }

    @Test func p4PreferencesAlwaysEnableHapticsButKeepCuePreference() {
        #expect(
            IOSVoiceBoundaryFeedbackPreferences.p4(audioCuesEnabled: false)
                == IOSVoiceBoundaryFeedbackPreferences(
                    audioCuesEnabled: false,
                    hapticsEnabled: true
                )
        )
        #expect(
            IOSVoiceBoundaryFeedbackPreferences.p4(audioCuesEnabled: true)
                == IOSVoiceBoundaryFeedbackPreferences(
                    audioCuesEnabled: true,
                    hapticsEnabled: true
                )
        )
    }

    @Test func liveCueWaveDataIsDeterministicDistinctValidPCM() throws {
        let start = IOSVoiceBoundaryCueAudio.waveData(for: .start)
        let repeatedStart = IOSVoiceBoundaryCueAudio.waveData(for: .start)
        let stop = IOSVoiceBoundaryCueAudio.waveData(for: .successStop)

        #expect(start == repeatedStart)
        #expect(start != stop)
        try assertValidCueWaveData(start)
        try assertValidCueWaveData(stop)
        #expect(start.count < stop.count)
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
                await adapter.recorderDidClose(
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
            await adapter.recorderDidClose(
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
        case recorderClosed
        case haptic
        case makePlayer(IOSVoiceBoundaryCue)
        case play(IOSVoiceBoundaryCue)
        case stop(IOSVoiceBoundaryCue)
    }

    var startPlayResult = true
    var startFactoryEvent: IOSVoiceBoundaryPlayerEvent?
    var stopFactoryEvent: IOSVoiceBoundaryPlayerEvent?
    var startPlayEvent: IOSVoiceBoundaryPlayerEvent?
    var stopPlayEvent: IOSVoiceBoundaryPlayerEvent?
    var stopFactoryError: IOSVoiceBoundaryFeedbackSystemError?
    var hapticAction: (@MainActor () -> Void)?
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
                if cue != .start, let stopFactoryError {
                    throw stopFactoryError
                }
                let player = VoiceBoundaryPlayerFixture(
                    cue: cue,
                    playResult: cue == .start
                        ? startPlayResult
                        : true,
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
                self?.hapticAction?()
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

    func markRecorderClosed() {
        calls.append(.recorderClosed)
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
    enum Failure: Error {
        case injected
    }

    private var waiters: [CheckedContinuation<Void, Error>] = []
    private(set) var requestedDurations: [Duration] = []
    var error: Error?

    var waiterCount: Int { waiters.count }

    func wait(for duration: Duration) async throws {
        requestedDurations.append(duration)
        if Task.isCancelled { throw CancellationError() }
        if let error { throw error }
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

@MainActor
private func beginCapture(
    adapter: IOSVoiceBoundaryFeedbackAdapter,
    fixture: VoiceBoundaryFeedbackFixture
) async throws -> IOSVoiceBoundaryFeedbackToken {
    let token = IOSVoiceBoundaryFeedbackToken()
    let result = await adapter.prepareStartBoundary(
        for: token,
        preferences: IOSVoiceBoundaryFeedbackPreferences(
            audioCuesEnabled: false,
            hapticsEnabled: false
        )
    )
    try #require(result == .completed)
    try #require(adapter.retainedCaptureDidBegin(for: token))
    #expect(fixture.calls.isEmpty)
    return token
}

private func assertValidCueWaveData(_ data: Data) throws {
    try #require(data.count > 44)
    #expect(String(data: data[0..<4], encoding: .ascii) == "RIFF")
    #expect(littleEndianUInt32(data, at: 4) == UInt32(data.count - 8))
    #expect(String(data: data[8..<12], encoding: .ascii) == "WAVE")
    #expect(String(data: data[12..<16], encoding: .ascii) == "fmt ")
    #expect(littleEndianUInt32(data, at: 16) == 16)
    #expect(littleEndianUInt16(data, at: 20) == 1)
    #expect(littleEndianUInt16(data, at: 22) == 1)
    #expect(littleEndianUInt32(data, at: 24) == 44_100)
    #expect(littleEndianUInt32(data, at: 28) == 88_200)
    #expect(littleEndianUInt16(data, at: 32) == 2)
    #expect(littleEndianUInt16(data, at: 34) == 16)
    #expect(String(data: data[36..<40], encoding: .ascii) == "data")
    #expect(littleEndianUInt32(data, at: 40) == UInt32(data.count - 44))
    #expect(data[44...].contains { $0 != 0 })
}

private func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
    UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

private func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
}
