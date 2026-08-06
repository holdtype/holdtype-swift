import AppKit
import Testing
@testable import HoldType

@MainActor
struct QuitConfirmationHandshakeTests {
    @Test func legacyRequesterReturnsPresenterDecisionSynchronously() {
        let presenter = StubQuitConfirmationPresenter(decision: .cancel)
        let requester = LegacyQuitConfirmationRequester(presenter: presenter)
        var resolvedDecision: QuitConfirmationDecision?

        requester.requestQuitConfirmation { decision in
            resolvedDecision = decision
        }

        #expect(resolvedDecision == .cancel)
        #expect(presenter.requestCount == 1)
    }

    @Test func confirmedAsynchronousPromptPreparesBeforeRequestingTermination() async {
        let requester = DeferredQuitConfirmationRequester()
        var terminationRequestCount = 0
        var preparationCount = 0
        let delegate = HoldTypeAppDelegate(
            quitConfirmationRequester: requester,
            prepareForTermination: {
                preparationCount += 1
            },
            requestTermination: {
                terminationRequestCount += 1
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(requester.requestCount == 1)
        #expect(preparationCount == 0)

        requester.resolve(.quit)
        await yieldUntil { preparationCount == 1 && terminationRequestCount == 1 }

        #expect(preparationCount == 1)
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @Test func repeatedQuitDuringPreparationDoesNotStartAnotherHandshake() async {
        let requester = DeferredQuitConfirmationRequester()
        let preparation = DeferredTerminationPreparation()
        var terminationRequestCount = 0
        let delegate = HoldTypeAppDelegate(
            quitConfirmationRequester: requester,
            prepareForTermination: {
                await preparation.run()
            },
            requestTermination: {
                terminationRequestCount += 1
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        requester.resolve(.quit)
        await yieldUntil { preparation.startCount == 1 }

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(requester.requestCount == 1)
        #expect(preparation.startCount == 1)

        preparation.finish()
        await yieldUntil { terminationRequestCount == 1 }

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }

    @Test func cancelLeavesTerminationCancelled() {
        let requester = DeferredQuitConfirmationRequester()
        var terminationRequestCount = 0
        let delegate = HoldTypeAppDelegate(
            quitConfirmationRequester: requester,
            requestTermination: {
                terminationRequestCount += 1
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        requester.resolve(.cancel)

        #expect(terminationRequestCount == 0)
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(requester.requestCount == 2)
    }

    private func yieldUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }
}

@MainActor
private final class DeferredQuitConfirmationRequester: QuitConfirmationRequesting {
    private(set) var requestCount = 0
    private var completion: (@MainActor (QuitConfirmationDecision) -> Void)?

    func requestQuitConfirmation(
        completion: @escaping @MainActor (QuitConfirmationDecision) -> Void
    ) {
        requestCount += 1
        self.completion = completion
    }

    func resolve(_ decision: QuitConfirmationDecision) {
        let completion = self.completion
        self.completion = nil
        completion?(decision)
    }
}

@MainActor
private final class DeferredTerminationPreparation {
    private(set) var startCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func run() async {
        startCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish() {
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume()
    }
}

@MainActor
private final class StubQuitConfirmationPresenter: QuitConfirmationPresenting {
    let decision: QuitConfirmationDecision
    private(set) var requestCount = 0

    init(decision: QuitConfirmationDecision) {
        self.decision = decision
    }

    func requestQuitConfirmation() -> QuitConfirmationDecision {
        requestCount += 1
        return decision
    }
}
