import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSUsageEstimateStateOwnerTests {
    @Test func refreshPublishesAThirtyDaySummary() async throws {
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 90,
            priceUSDPerMinute: 0.006
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [event] },
                reset: { try await unusedUsageResetToken() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(owner.state == .notLoaded)
        #expect(await owner.refresh())
        let summary = try #require(owner.summary)
        #expect(summary.totalDurationSeconds == 90)
        #expect(summary.todayDurationSeconds == 90)
        let totalCost = try #require(summary.totalEstimatedCostUSD)
        #expect(abs(totalCost - 0.009) < 1e-12)
        #expect(owner.operation == .idle)
    }

    @Test func loadFailuresAreDistinctFromEmptyAndPreserveConfirmedData()
        async throws {
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let fixture = UsageEstimateLoadFixture(
            steps: [.failure, .events([event]), .failure]
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { try await fixture.load() },
                reset: { try await unusedUsageResetToken() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(!(await owner.refresh()))
        #expect(owner.state == .loadFailed(lastConfirmed: nil))

        #expect(await owner.refresh())
        let confirmed = try #require(owner.summary)
        #expect(!confirmed.isEmpty)

        #expect(!(await owner.refresh()))
        #expect(owner.state == .loadFailed(lastConfirmed: confirmed))
        #expect(owner.summary == confirmed)
    }

    @Test func resetFailurePreservesTheLastConfirmedSummary() async throws {
        let now = fixedUsageDate()
        let tokens = try await usageWriteTokens()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 120,
            priceUSDPerMinute: 0.006
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [event] },
                reset: { throw UsageEstimateTestError.scriptedFailure }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        let confirmed = try #require(owner.summary)
        owner.reportWriteFailure(tokens.beforeFence)
        #expect(!(await owner.reset()))
        #expect(owner.state == .resetFailed(lastConfirmed: confirmed))
        #expect(owner.summary == confirmed)
        #expect(owner.notice == .writeFailed)
        #expect(owner.operation == .idle)
    }

    @Test func unreadableStorageCanBeResetWithoutInventingAnEmptyLoad()
        async throws {
        let tokens = try await usageWriteTokens()
        let now = fixedUsageDate()
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { throw UsageEstimateTestError.scriptedFailure },
                reset: { tokens.resetFence }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(!(await owner.refresh()))
        #expect(owner.state == .loadFailed(lastConfirmed: nil))
        #expect(owner.canReset)

        #expect(await owner.reset())
        #expect(owner.state == .ready(.empty(
            now: now,
            calendar: usageCalendar()
        )))
        #expect(owner.summary?.isEmpty == true)
        #expect(!owner.canReset)
    }

    @Test func unreadableResetFailureRemainsVisibleAndRetryable()
        async throws {
        let tokens = try await usageWriteTokens()
        let fixture = UsageEstimateResetFixture(
            token: tokens.resetFence,
            failures: [true, false]
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { throw UsageEstimateTestError.scriptedFailure },
                reset: { try await fixture.reset() }
            )
        )

        #expect(!(await owner.refresh()))
        #expect(!(await owner.reset()))
        #expect(owner.state == .resetFailed(lastConfirmed: nil))
        #expect(owner.canReset)

        #expect(await owner.reset())
        #expect(owner.summary?.isEmpty == true)
        #expect(await fixture.resetCallCount() == 2)
    }

    @Test func busyRefreshSuppressesCompetingRefreshAndReset() async throws {
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let fixture = UsageEstimateSuspendingLoadFixture(events: [event])
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { try await fixture.load() },
                reset: { try await unusedUsageResetToken() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        await fixture.suspendNextLoad()
        let refresh = Task { @MainActor in await owner.refresh() }
        try await usageEventually { await fixture.loadCallCount() == 2 }

        guard case .refreshing(let revision) = owner.operation else {
            Issue.record("Expected a token-bearing refresh operation.")
            refresh.cancel()
            return
        }
        #expect(revision > 0)
        #expect(!(await owner.refresh()))
        #expect(!(await owner.reset()))
        #expect(owner.operation == .refreshing(revision))

        await fixture.resumeLoad()
        #expect(await refresh.value)
        #expect(owner.operation == .idle)
        #expect(await fixture.loadCallCount() == 2)
    }

    @Test func busyResetSuppressesCompetingResetAndRefresh() async throws {
        let tokens = try await usageWriteTokens()
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let fixture = UsageEstimateSuspendingResetFixture(
            token: tokens.resetFence
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [event] },
                reset: { try await fixture.reset() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        let reset = Task { @MainActor in await owner.reset() }
        try await usageEventually { await fixture.resetCallCount() == 1 }

        guard case .resetting(let revision) = owner.operation else {
            Issue.record("Expected a token-bearing Reset operation.")
            reset.cancel()
            return
        }
        #expect(revision > 0)
        #expect(!(await owner.reset()))
        #expect(!(await owner.refresh()))
        #expect(owner.operation == .resetting(revision))

        await fixture.resumeReset()
        #expect(await reset.value)
        #expect(owner.summary?.isEmpty == true)
        #expect(owner.operation == .idle)
    }

    @Test func cancelledRefreshCannotPublishFromACancellationInsensitiveLoad()
        async throws {
        let now = fixedUsageDate()
        let initialEvent = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let replacementEvent = try usageEvent(
            timestamp: now,
            durationSeconds: 600,
            priceUSDPerMinute: 0.006
        )
        let fixture = UsageEstimateMutableLoadFixture(events: [initialEvent])
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { try await fixture.load() },
                reset: { try await unusedUsageResetToken() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        let confirmed = try #require(owner.summary)
        await fixture.replaceEvents([replacementEvent])
        await fixture.suspendNextLoad()
        let refresh = Task { @MainActor in await owner.refresh() }
        try await usageEventually { await fixture.loadCallCount() == 2 }

        refresh.cancel()
        await fixture.resumeLoad()

        #expect(!(await refresh.value))
        #expect(owner.state == .ready(confirmed))
        #expect(owner.operation == .idle)
    }

    @Test func cancellationErrorsDoNotBecomeLoadOrResetFailures()
        async throws {
        let tokens = try await usageWriteTokens()
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let fixture = UsageEstimateCancellationFixture(
            events: [event],
            resetToken: tokens.resetFence
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { try await fixture.load() },
                reset: { try await fixture.reset() }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        await fixture.cancelNextLoad()
        #expect(!(await owner.refresh()))
        #expect(owner.state == .notLoaded)

        #expect(await owner.refresh())
        let confirmed = try #require(owner.summary)
        await fixture.cancelNextReset()
        #expect(!(await owner.reset()))
        #expect(owner.state == .ready(confirmed))
        #expect(owner.operation == .idle)
    }

    @Test func successfulRefreshDoesNotDismissAWriteFailureNotice()
        async throws {
        let tokens = try await usageWriteTokens()
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [] },
                reset: { tokens.resetFence }
            )
        )

        owner.reportWriteFailure(tokens.beforeFence)
        #expect(await owner.refresh())
        #expect(owner.notice == .writeFailed)
    }

    @Test func successfulResetFencesOldFailuresButKeepsNewerFailures()
        async throws {
        let tokens = try await usageWriteTokens()
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [event] },
                reset: { tokens.resetFence }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        owner.reportWriteFailure(tokens.beforeFence)
        #expect(owner.notice == .writeFailed)

        #expect(await owner.reset())
        #expect(owner.summary?.isEmpty == true)
        #expect(owner.notice == nil)

        owner.reportWriteFailure(tokens.beforeFence)
        #expect(owner.notice == nil)
        owner.reportWriteFailure(tokens.afterFence)
        #expect(owner.notice == .writeFailed)

        owner.dismissNotice()
        #expect(owner.notice == nil)
        owner.reportWriteFailure(tokens.afterFence)
        #expect(owner.notice == nil)
        owner.reportWriteFailure(tokens.afterDismiss)
        #expect(owner.notice == .writeFailed)
    }

    @Test func exhaustedWriteOrderingFailsClosedAfterDismissAndReset()
        async throws {
        let exhausted = IOSTranscriptionUsageQualificationFixture
            .writeToken(revision: UInt64.max)
        let now = fixedUsageDate()
        let event = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [event] },
                reset: { exhausted }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        owner.reportWriteFailure(exhausted)
        owner.dismissNotice()
        owner.reportWriteFailure(exhausted)
        #expect(owner.notice == .writeFailed)

        #expect(await owner.reset())
        #expect(owner.notice == nil)
        owner.reportWriteFailure(exhausted)
        #expect(owner.notice == .writeFailed)
    }

    @Test func emptySummaryCannotStartAReset() async throws {
        let now = fixedUsageDate()
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [] },
                reset: {
                    Issue.record("Empty usage must not call Reset storage.")
                    return try await unusedUsageResetToken()
                }
            ),
            calendar: usageCalendar(),
            now: { now }
        )

        #expect(await owner.refresh())
        #expect(owner.summary?.isEmpty == true)
        #expect(!(await owner.reset()))
        #expect(owner.operation == .idle)
    }

    @Test func presentationDescriptionsDoNotExposeUsageContent() async throws {
        let owner = IOSUsageEstimateStateOwner(
            client: IOSUsageEstimateClient(
                load: { [] },
                reset: { try await unusedUsageResetToken() }
            )
        )

        #expect(owner.description.contains("redacted"))
        #expect(owner.debugDescription.contains("redacted"))
        #expect(owner.customMirror.children.isEmpty)
    }
}

@MainActor
struct IOSUsageEstimateFormattingTests {
    @Test func formatterMakesUnknownAndSmallCostsExplicit() {
        #expect(IOSUsageEstimateFormatter.minutes(0) == "0 min")
        #expect(IOSUsageEstimateFormatter.minutes(1) == "<0.1 min")
        #expect(IOSUsageEstimateFormatter.minutes(30) == "0.5 min")
        #expect(IOSUsageEstimateFormatter.minutes(6_000) == "100 min")
        #expect(IOSUsageEstimateFormatter.cost(nil) == "Unavailable")
        #expect(IOSUsageEstimateFormatter.cost(0) == "$0.00")
        #expect(IOSUsageEstimateFormatter.cost(0.00001) == "<$0.0001")
        #expect(IOSUsageEstimateFormatter.cost(0.006) == "$0.0060")
        #expect(IOSUsageEstimateFormatter.cost(1.234) == "$1.23")
    }

    @Test func chartAccessibilityCallsOutUnknownAndPartialCost()
        async throws {
        let now = fixedUsageDate()
        let unknown = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: nil
        )
        let known = try usageEvent(
            timestamp: now,
            durationSeconds: 60,
            priceUSDPerMinute: 0.006
        )
        let calendar = usageCalendar()

        let unknownBucket = try #require(
            TranscriptionUsageSummary.make(
                events: [unknown],
                now: now,
                calendar: calendar
            ).dailyBuckets.last
        )
        #expect(
            IOSUsageChartMetric.cost.accessibilityValue(
                for: unknownBucket
            ) == "Cost unavailable"
        )
        #expect(
            IOSUsageChartMetric.minutes.accessibilityValue(
                for: unknownBucket
            ) == "1.0 min"
        )

        let mixedBucket = try #require(
            TranscriptionUsageSummary.make(
                events: [known, unknown],
                now: now,
                calendar: calendar
            ).dailyBuckets.last
        )
        #expect(
            IOSUsageChartMetric.cost.accessibilityValue(
                for: mixedBucket
            ) == "$0.0060, partial"
        )
    }
}

private enum UsageEstimateTestError: Error {
    case scriptedFailure
}

private enum UsageEstimateLoadStep: Sendable {
    case events([TranscriptionUsageEvent])
    case failure
}

private actor UsageEstimateLoadFixture {
    private var steps: [UsageEstimateLoadStep]

    init(steps: [UsageEstimateLoadStep]) {
        self.steps = steps
    }

    func load() throws -> [TranscriptionUsageEvent] {
        guard !steps.isEmpty else {
            throw UsageEstimateTestError.scriptedFailure
        }
        switch steps.removeFirst() {
        case .events(let events):
            return events
        case .failure:
            throw UsageEstimateTestError.scriptedFailure
        }
    }
}

private actor UsageEstimateSuspendingLoadFixture {
    private let events: [TranscriptionUsageEvent]
    private var loads = 0
    private var shouldSuspendNextLoad = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(events: [TranscriptionUsageEvent]) {
        self.events = events
    }

    func load() async throws -> [TranscriptionUsageEvent] {
        loads += 1
        if shouldSuspendNextLoad {
            shouldSuspendNextLoad = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
        return events
    }

    func suspendNextLoad() {
        shouldSuspendNextLoad = true
    }

    func resumeLoad() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }

    func loadCallCount() -> Int { loads }
}

private actor UsageEstimateMutableLoadFixture {
    private var events: [TranscriptionUsageEvent]
    private var loads = 0
    private var shouldSuspendNextLoad = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(events: [TranscriptionUsageEvent]) {
        self.events = events
    }

    func load() async throws -> [TranscriptionUsageEvent] {
        loads += 1
        if shouldSuspendNextLoad {
            shouldSuspendNextLoad = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
        return events
    }

    func replaceEvents(_ events: [TranscriptionUsageEvent]) {
        self.events = events
    }

    func suspendNextLoad() {
        shouldSuspendNextLoad = true
    }

    func resumeLoad() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }

    func loadCallCount() -> Int { loads }
}

private actor UsageEstimateResetFixture {
    private let token: IOSTranscriptionUsageWriteToken
    private var failures: [Bool]
    private var resets = 0

    init(
        token: IOSTranscriptionUsageWriteToken,
        failures: [Bool]
    ) {
        self.token = token
        self.failures = failures
    }

    func reset() throws -> IOSTranscriptionUsageWriteToken {
        resets += 1
        if !failures.isEmpty, failures.removeFirst() {
            throw UsageEstimateTestError.scriptedFailure
        }
        return token
    }

    func resetCallCount() -> Int { resets }
}

private actor UsageEstimateSuspendingResetFixture {
    private let token: IOSTranscriptionUsageWriteToken
    private var resets = 0
    private var continuation: CheckedContinuation<Void, Never>?

    init(token: IOSTranscriptionUsageWriteToken) {
        self.token = token
    }

    func reset() async throws -> IOSTranscriptionUsageWriteToken {
        resets += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return token
    }

    func resumeReset() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }

    func resetCallCount() -> Int { resets }
}

private actor UsageEstimateCancellationFixture {
    private let events: [TranscriptionUsageEvent]
    private let resetToken: IOSTranscriptionUsageWriteToken
    private var shouldCancelNextLoad = false
    private var shouldCancelNextReset = false

    init(
        events: [TranscriptionUsageEvent],
        resetToken: IOSTranscriptionUsageWriteToken
    ) {
        self.events = events
        self.resetToken = resetToken
    }

    func cancelNextLoad() {
        shouldCancelNextLoad = true
    }

    func cancelNextReset() {
        shouldCancelNextReset = true
    }

    func load() throws -> [TranscriptionUsageEvent] {
        if shouldCancelNextLoad {
            shouldCancelNextLoad = false
            throw CancellationError()
        }
        return events
    }

    func reset() throws -> IOSTranscriptionUsageWriteToken {
        if shouldCancelNextReset {
            shouldCancelNextReset = false
            throw CancellationError()
        }
        return resetToken
    }
}

private struct UsageWriteTokens {
    let beforeFence: IOSTranscriptionUsageWriteToken
    let resetFence: IOSTranscriptionUsageWriteToken
    let afterFence: IOSTranscriptionUsageWriteToken
    let afterDismiss: IOSTranscriptionUsageWriteToken
}

private func usageWriteTokens() async throws -> UsageWriteTokens {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "HoldType-usage-token-tests-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let repository = IOSTranscriptionUsageRepository(
        applicationSupportDirectoryURL: root
    )
    let usage = try SuccessfulTranscriptionUsage(
        transcriptionID: UUID(),
        model: "gpt-4o-transcribe",
        audioDuration: 60
    )
    let first = try #require(
        writeToken(await repository.recordObserved(usage))
    )
    _ = await repository.recordObserved(usage)
    let fence = try await repository.resetWithWriteFence()
    let third = try #require(
        writeToken(await repository.recordObserved(usage))
    )
    let fourth = try #require(
        writeToken(await repository.recordObserved(usage))
    )
    return UsageWriteTokens(
        beforeFence: first,
        resetFence: fence,
        afterFence: third,
        afterDismiss: fourth
    )
}

private func unusedUsageResetToken()
    async throws -> IOSTranscriptionUsageWriteToken {
    let tokens = try await usageWriteTokens()
    return tokens.resetFence
}

private func writeToken(
    _ result: IOSTranscriptionUsageObservedRecordResult
) -> IOSTranscriptionUsageWriteToken? {
    switch result {
    case .inserted(let token),
         .duplicate(let token),
         .failed(let token):
        return token
    }
}

private func usageEvent(
    timestamp: Date,
    durationSeconds: TimeInterval,
    priceUSDPerMinute: Double?
) throws -> TranscriptionUsageEvent {
    try TranscriptionUsageEvent(
        timestamp: timestamp,
        model: priceUSDPerMinute == nil
            ? "future-transcribe-model"
            : "gpt-4o-transcribe",
        durationSeconds: durationSeconds,
        priceUSDPerMinute: priceUSDPerMinute,
        estimatedCostUSD: priceUSDPerMinute.map {
            durationSeconds / 60 * $0
        },
        pricingSource: priceUSDPerMinute.map { _ in "Test pricing" }
    )
}

private func fixedUsageDate() -> Date {
    Date(timeIntervalSince1970: 1_783_852_800)
}

private func usageCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
}

private func usageEventually(
    _ predicate: @escaping @Sendable () async -> Bool
) async throws {
    for _ in 0..<200 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(2))
    }
    Issue.record("Timed out waiting for usage-estimate fixture progress.")
}
