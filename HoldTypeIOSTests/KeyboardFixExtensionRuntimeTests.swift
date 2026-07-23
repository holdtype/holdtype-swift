import Foundation
import Testing

@MainActor
struct KeyboardFixExtensionRuntimeTests {
    @Test func availabilityRequiresFullAccessIdleDictationAndSelection()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        #expect(runtime.presentation.status == .ready)

        fixture.hasFullAccess = false
        runtime.refreshAvailability()
        #expect(
            runtime.presentation.status
                == .unavailable(
                    message: "Allow Full Access to use Fixes."
                )
        )

        fixture.hasFullAccess = true
        fixture.dictationIsBusy = true
        runtime.refreshAvailability()
        #expect(
            runtime.presentation.status
                == .unavailable(
                    message: "Finish dictation before using Fixes."
                )
        )

        fixture.dictationIsBusy = false
        fixture.target = nil
        runtime.refreshAvailability()
        #expect(
            runtime.presentation.status
                == .unavailable(
                    message: "Select text in the current field."
                )
        )
    }

    @Test func activationPublishesExactSelectionAndOneSignal() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()

        runtime.activate(actionIdentifier: "user.action.0")

        let request = try fixture.requireRequest()
        let target = try #require(fixture.target)
        #expect(request.sourceText == target.selectedText)
        #expect(
            request.documentIdentifier
                == target.documentIdentifier
        )
        #expect(
            request.sourceFingerprint == target.fingerprint
        )
        #expect(request.actionIdentifier == "user.action.0")
        #expect(fixture.postRequestCount == 1)
        #expect(
            fixture.openedURLs == [
                KeyboardFixLaunchRoute(requestID: request.requestID).url
            ].compactMap { $0 }
        )
        #expect(
            runtime.presentation.status
                == .processing(actionIdentifier: "user.action.0")
        )
    }

    @Test func concurrentActivationIsIgnoredWithoutQueueing() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let first = try fixture.requireRequest()

        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )

        #expect(try fixture.requireRequest() == first)
        #expect(fixture.postRequestCount == 1)
    }

    @Test func successConsumesThenAppliesExactlyOnce() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        try fixture.publishSuccess(output: "Exact output")

        runtime.poll()
        runtime.poll()

        #expect(fixture.appliedOutputs == ["Exact output"])
        #expect(fixture.latestResult == nil)
        #expect(
            runtime.presentation.status
                == .applied(message: "Custom 0 applied.")
        )
    }

    @Test func changedSelectionConsumesWithoutApplying() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        try fixture.publishSuccess()
        fixture.target = KeyboardFixExtensionTarget(
            documentIdentifier: "document-id",
            selectedText: "Changed"
        )

        runtime.poll()

        #expect(fixture.appliedOutputs.isEmpty)
        #expect(fixture.latestResult == nil)
        #expect(
            runtime.presentation.status
                == .failure(
                    message:
                        "The selected text changed. Select it again."
                )
        )
    }

    @Test func recreatedRuntimeRecoversMatchingTerminalResult() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let target = try #require(fixture.target)
        let request = try #require(
            KeyboardFixRequestRecord(
                revision: 9,
                requestID: UUID(),
                actionIdentifier: "user.action.0",
                sourceText: target.selectedText,
                documentIdentifier: target.documentIdentifier,
                sourceFingerprint: target.fingerprint,
                issuedAt: fixture.now,
                expiresAt: fixture.now.addingTimeInterval(60)
            )
        )
        fixture.publishedRequest = request
        fixture.now = request.issuedAt.addingTimeInterval(1)
        fixture.latestResult = try makeKeyboardFixResult(
            request: request,
            outputText: "Recovered",
            publishedAt: fixture.now
        )
        let runtime = fixture.makeRuntime()

        runtime.start()

        #expect(fixture.appliedOutputs == ["Recovered"])
        #expect(fixture.latestResult == nil)
    }

    @Test func closedFailureMapsToConciseMessage() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let request = try fixture.requireRequest()
        fixture.now = request.issuedAt.addingTimeInterval(1)
        fixture.latestResult = try makeKeyboardFixResult(
            request: request,
            phase: .failed,
            outputText: nil,
            failureCode: .consentRequired,
            publishedAt: fixture.now
        )

        runtime.poll()

        #expect(
            runtime.presentation.status
                == .failure(
                    message:
                        "Review OpenAI processing consent in HoldType."
                )
        )
        #expect(fixture.appliedOutputs.isEmpty)
    }
}
