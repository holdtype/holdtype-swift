import AppKit
import Testing
@testable import HoldType

@MainActor
struct QuitConfirmationHandshakeTests {
    @Test func coordinatorOpensConfirmationWindowBeforeWaitingForDecision() {
        let coordinator = QuitConfirmationCoordinator()
        var windowRequestCount = 0
        var resolvedDecision: QuitConfirmationDecision?

        coordinator.install {
            windowRequestCount += 1
        }
        coordinator.requestQuitConfirmation { decision in
            resolvedDecision = decision
        }

        #expect(windowRequestCount == 1)
        #expect(coordinator.presentation != nil)

        coordinator.resolve(.cancel)

        #expect(resolvedDecision == .cancel)
    }

    @Test func confirmedAsynchronousPromptRequestsTerminationThenPrepares() async {
        let requester = DeferredQuitConfirmationRequester()
        var terminationRequestCount = 0
        var preparationCount = 0
        var terminationReplies: [Bool] = []
        let delegate = HoldTypeAppDelegate(
            quitConfirmationRequester: requester,
            prepareForTermination: {
                preparationCount += 1
            },
            replyToTerminationRequest: { _, shouldTerminate in
                terminationReplies.append(shouldTerminate)
            },
            requestTermination: {
                terminationRequestCount += 1
            }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(requester.requestCount == 1)
        #expect(preparationCount == 0)

        requester.resolve(.quit)
        await yieldUntil { terminationRequestCount == 1 }

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater)
        await yieldUntil { terminationReplies == [true] }
        #expect(preparationCount == 1)
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
