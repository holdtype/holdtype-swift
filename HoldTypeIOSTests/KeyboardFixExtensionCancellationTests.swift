import Foundation
import Testing

@MainActor
struct KeyboardFixExtensionCancellationTests {
    @Test func explicitCancelBlocksNextActionUntilMatchingAck()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let first = try fixture.requireRequest()

        runtime.cancelActiveRequest()
        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )

        let cancellation = try fixture.requireCancellation()
        #expect(cancellation.requestID == first.requestID)
        #expect(cancellation.phase == .requested)
        #expect(fixture.postCancellationCount == 1)
        #expect(fixture.postRequestCount == 1)
        #expect(
            runtime.presentation.status
                == .cancelling(actionIdentifier: "user.action.0")
        )

        try fixture.acknowledgeCancellation(requestID: UUID())
        #expect(
            runtime.presentation.status
                == .cancelling(actionIdentifier: "user.action.0")
        )
        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        #expect(fixture.postRequestCount == 1)

        try fixture.acknowledgeCancellation()
        #expect(
            runtime.presentation.status
                == .failure(message: "The Fix was cancelled.")
        )
        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        #expect(fixture.postRequestCount == 2)
    }

    @Test func cancellationExpiryReleasesTheOriginalIdentity()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        runtime.cancelActiveRequest()
        let cancellation = try fixture.requireCancellation()

        fixture.now = cancellation.expiresAt
        runtime.poll()

        #expect(
            runtime.presentation.status
                == .failure(message: "The Fix was cancelled.")
        )
        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        #expect(fixture.postRequestCount == 2)
    }

    @Test func requestExpiryWaitsForCancellationAck() throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let request = try fixture.requireRequest()
        fixture.now = request.expiresAt

        runtime.poll()

        #expect(
            try fixture.requireCancellation().requestID
                == request.requestID
        )
        #expect(
            runtime.presentation.status
                == .cancelling(actionIdentifier: "user.action.0")
        )
        try fixture.acknowledgeCancellation()
        #expect(
            runtime.presentation.status
                == .failure(message: "The Fix timed out. Try again.")
        )
    }

    @Test func launchFailureWaitsForCancellationAckWithoutApplying()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let request = try fixture.requireRequest()

        fixture.openFailure?()

        #expect(
            try fixture.requireCancellation().requestID
                == request.requestID
        )
        #expect(fixture.appliedOutputs.isEmpty)
        #expect(
            runtime.presentation.status
                == .cancelling(actionIdentifier: "user.action.0")
        )
        try fixture.acknowledgeCancellation()
        #expect(
            runtime.presentation.status
                == .failure(
                    message: "Could not open HoldType for this Fix."
                )
        )
    }

    @Test func stopCancelsRequestBeforeRuntimeCanBeRecreated()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        let request = try fixture.requireRequest()

        runtime.stop()

        #expect(
            try fixture.requireCancellation().requestID == request.requestID
        )
        #expect(fixture.publishedRequest == nil)
        let recreatedRuntime = fixture.makeRuntime()
        recreatedRuntime.start()
        #expect(fixture.appliedOutputs.isEmpty)
        #expect(fixture.latestResult == nil)
    }

    @Test func stopAndRestartPreservePendingCancellation()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime()
        runtime.start()
        runtime.activate(actionIdentifier: "user.action.0")
        runtime.cancelActiveRequest()

        runtime.stop()
        runtime.start()
        try fixture.acknowledgeCancellation()

        #expect(
            runtime.presentation.status
                == .failure(message: "The Fix was cancelled.")
        )
    }

    @Test func recreatedRuntimeCancelsProcessingResult()
        throws {
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let target = try #require(fixture.target)
        let request = try #require(
            KeyboardFixRequestRecord(
                revision: 7,
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
            phase: .processing,
            outputText: nil,
            publishedAt: fixture.now
        )
        let runtime = fixture.makeRuntime()

        runtime.start()

        #expect(
            try fixture.requireCancellation().requestID
                == request.requestID
        )
        #expect(
            runtime.presentation.status
                == .cancelling(actionIdentifier: "user.action.0")
        )
        try fixture.acknowledgeCancellation()
        #expect(
            runtime.presentation.status
                == .failure(
                    message:
                        "The Fix was interrupted. Select text and try again."
                )
        )
    }
}
