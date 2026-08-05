import AppKit
import Testing
@testable import HoldType

@MainActor
struct QuitConfirmationHandshakeTests {
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
