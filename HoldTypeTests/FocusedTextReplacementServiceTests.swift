import Foundation
import Testing
@testable import HoldType

@MainActor
struct FocusedTextReplacementServiceTests {
    @Test func replacementRevalidatesRestoresAndPostsOnce() async throws {
        let eventLog = ReplacementEventLog()
        let token = FocusedTextElementToken()
        let client = ReplacementTargetClient(
            eventLog: eventLog,
            state: makeState(
                token: token,
                text: "Hello world",
                selectedRange: NSRange(location: 6, length: 5)
            )
        )
        let targetService = makeTargetService(client: client)
        let snapshot = try targetService.capture()
        let activator = ReplacementApplicationActivator(
            eventLog: eventLog
        )
        let poster = ReplacementTextEventPoster(eventLog: eventLog)
        let service = makeReplacementService(
            targetService: targetService,
            activator: activator,
            poster: poster
        )

        try await service.replace(snapshot: snapshot, with: "Swift")

        #expect(await poster.texts == ["Swift"])
        #expect(
            eventLog.events == [
                "activate:101",
                "focus",
                "select:6:5",
                "post",
            ]
        )
    }

    @Test func staleSourceNeverActivatesOrPosts() async throws {
        let eventLog = ReplacementEventLog()
        let token = FocusedTextElementToken()
        let client = ReplacementTargetClient(
            eventLog: eventLog,
            state: makeState(
                token: token,
                text: "Hello world",
                selectedRange: NSRange(location: 6, length: 5)
            )
        )
        let targetService = makeTargetService(client: client)
        let snapshot = try targetService.capture()
        client.state = makeState(
            token: token,
            text: "Hello there",
            selectedRange: NSRange(location: 6, length: 5)
        )
        let poster = ReplacementTextEventPoster(eventLog: eventLog)
        let service = makeReplacementService(
            targetService: targetService,
            activator: ReplacementApplicationActivator(
                eventLog: eventLog
            ),
            poster: poster
        )

        await #expect(throws: FocusedTextTargetError.stale) {
            try await service.replace(snapshot: snapshot, with: "Swift")
        }

        #expect(eventLog.events.isEmpty)
        #expect(await poster.texts.isEmpty)
    }

    @Test func activationFailureLeavesSourceUnposted() async throws {
        let eventLog = ReplacementEventLog()
        let client = ReplacementTargetClient(
            eventLog: eventLog,
            state: makeState(text: "Hello")
        )
        let targetService = makeTargetService(client: client)
        let snapshot = try targetService.capture()
        let poster = ReplacementTextEventPoster(eventLog: eventLog)
        let service = makeReplacementService(
            targetService: targetService,
            activator: ReplacementApplicationActivator(
                eventLog: eventLog,
                shouldActivate: false
            ),
            poster: poster
        )

        await #expect(
            throws: FocusedTextTargetError.focusRestorationFailed
        ) {
            try await service.replace(snapshot: snapshot, with: "Changed")
        }

        #expect(eventLog.events == ["activate:101"])
        #expect(await poster.texts.isEmpty)
    }

    @Test func focusRestorationRetriesWithinBound() async throws {
        let eventLog = ReplacementEventLog()
        let client = ReplacementTargetClient(
            eventLog: eventLog,
            state: makeState(text: "Hello"),
            failedFocusAttemptCount: 1
        )
        let targetService = makeTargetService(client: client)
        let snapshot = try targetService.capture()
        let poster = ReplacementTextEventPoster(eventLog: eventLog)
        let service = makeReplacementService(
            targetService: targetService,
            activator: ReplacementApplicationActivator(
                eventLog: eventLog
            ),
            poster: poster,
            focusAttemptCount: 2
        )

        try await service.replace(snapshot: snapshot, with: "Changed")

        #expect(
            eventLog.events == [
                "activate:101",
                "focus-failed",
                "focus",
                "select:0:5",
                "post",
            ]
        )
    }

    @Test func postingTimeoutIsTyped() async throws {
        let eventLog = ReplacementEventLog()
        let client = ReplacementTargetClient(
            eventLog: eventLog,
            state: makeState(text: "Hello")
        )
        let targetService = makeTargetService(client: client)
        let snapshot = try targetService.capture()
        let poster = ReplacementTextEventPoster(
            eventLog: eventLog,
            delayNanoseconds: 1_000_000_000
        )
        let service = FocusedTextReplacementService(
            targetService: targetService,
            applicationActivator: ReplacementApplicationActivator(
                eventLog: eventLog
            ),
            textEventPoster: poster,
            sleeper: ImmediateReplacementSleeper(),
            replacementTimeout: 0.01,
            focusAttemptCount: 1,
            focusRetryDelay: 0
        )

        await #expect(
            throws: FocusedTextTargetError.replacementTimedOut
        ) {
            try await service.replace(snapshot: snapshot, with: "Changed")
        }
        #expect(await poster.texts.isEmpty)
    }

    private func makeTargetService(
        client: ReplacementTargetClient
    ) -> FocusedTextTargetService {
        FocusedTextTargetService(
            accessibilityPermissionService: AccessibilityPermissionService(
                client: ReplacementPermissionClient()
            ),
            client: client,
            holdTypeProcessIdentifier: 999
        )
    }

    private func makeReplacementService(
        targetService: FocusedTextTargetService,
        activator: ReplacementApplicationActivator,
        poster: ReplacementTextEventPoster,
        focusAttemptCount: Int = 1
    ) -> FocusedTextReplacementService {
        FocusedTextReplacementService(
            targetService: targetService,
            applicationActivator: activator,
            textEventPoster: poster,
            sleeper: TaskFocusedTextReplacementSleeper(),
            replacementTimeout: 100,
            focusAttemptCount: focusAttemptCount,
            focusRetryDelay: 0
        )
    }

    private func makeState(
        token: FocusedTextElementToken = FocusedTextElementToken(),
        text: String,
        selectedRange: NSRange? = NSRange(location: 0, length: 0)
    ) -> FocusedTextElementState {
        FocusedTextElementState(
            token: token,
            processIdentifier: 101,
            text: text,
            selectedRange: selectedRange,
            anchorRect: nil,
            isSecure: false
        )
    }
}

@MainActor
private final class ReplacementEventLog {
    var events: [String] = []
}

@MainActor
private final class ReplacementTargetClient: FocusedTextTargetClient {
    let eventLog: ReplacementEventLog
    var state: FocusedTextElementState?
    private var failedFocusAttemptCount: Int
    private var focusedToken: FocusedTextElementToken?

    init(
        eventLog: ReplacementEventLog,
        state: FocusedTextElementState?,
        failedFocusAttemptCount: Int = 0
    ) {
        self.eventLog = eventLog
        self.state = state
        self.failedFocusAttemptCount = failedFocusAttemptCount
    }

    func focusedElement() -> FocusedTextElementState? {
        state
    }

    func currentState(
        for token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        state?.token == token ? state : nil
    }

    func focus(_ token: FocusedTextElementToken) -> Bool {
        if failedFocusAttemptCount > 0 {
            failedFocusAttemptCount -= 1
            eventLog.events.append("focus-failed")
            return false
        }
        eventLog.events.append("focus")
        focusedToken = token
        return true
    }

    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool {
        guard let current = state, current.token == token else {
            return false
        }
        eventLog.events.append("select:\(range.location):\(range.length)")
        state = FocusedTextElementState(
            token: current.token,
            processIdentifier: current.processIdentifier,
            text: current.text,
            selectedRange: range,
            anchorRect: current.anchorRect,
            isSecure: current.isSecure
        )
        return true
    }

    func isFocused(_ token: FocusedTextElementToken) -> Bool {
        focusedToken == token
    }
}

@MainActor
private struct ReplacementApplicationActivator:
    ExternalApplicationActivating {
    let eventLog: ReplacementEventLog
    var shouldActivate = true

    func activate(processIdentifier: pid_t) -> Bool {
        eventLog.events.append("activate:\(processIdentifier)")
        return shouldActivate
    }
}

private actor ReplacementTextEventPoster: TextEventPosting {
    let eventLog: ReplacementEventLog
    let delayNanoseconds: UInt64
    private(set) var texts: [String] = []

    init(
        eventLog: ReplacementEventLog,
        delayNanoseconds: UInt64 = 0
    ) {
        self.eventLog = eventLog
        self.delayNanoseconds = delayNanoseconds
    }

    func postText(_ text: String) async throws {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        await MainActor.run {
            eventLog.events.append("post")
        }
        texts.append(text)
    }
}

private struct ImmediateReplacementSleeper:
    FocusedTextReplacementSleeping {
    func sleep(seconds: TimeInterval) async throws {}
}

private final class ReplacementPermissionClient:
    AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        true
    }

    func openAccessibilitySettings() -> Bool {
        false
    }
}
