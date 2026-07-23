import Foundation

@MainActor
extension KeyboardFixExtensionRuntime {
    func cancelActiveRequest() {
        if let activeRequest {
            dependencies.diagnostics.record(
                .result,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .cancelled
            )
        }
        requestCancellation(
            completingWith: .failure(
                message: "The Fix was cancelled."
            )
        )
    }

    func requestCancellation(
        completingWith completionStatus: KeyboardFixExtensionStatus
    ) {
        guard pendingCancellation == nil,
              let activeRequest
        else {
            return
        }
        let now = dependencies.now()
        let expiresAt = now.addingTimeInterval(
            KeyboardFixBridgeConfiguration.recordLifetime
        )
        guard let cancellation = KeyboardFixCancellationRecord(
            requestID: activeRequest.identity.requestID,
            issuedAt: now,
            expiresAt: expiresAt
        ) else {
            dependencies.diagnostics.record(
                .cancellation,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .failed
            )
            finishActiveRequest(status: completionStatus)
            return
        }

        pendingCancellation = PendingCancellation(
            requestID: activeRequest.identity.requestID,
            expiresAt: expiresAt,
            completionStatus: completionStatus
        )
        presentation = currentPresentation(
            status: .cancelling(
                actionIdentifier:
                    activeRequest.identity.actionIdentifier
            )
        )
        beginPolling()
        dependencies.diagnostics.record(
            .cancellation,
            actionIdentifier:
                activeRequest.identity.actionIdentifier,
            requestID: activeRequest.identity.requestID,
            outcome: .started
        )
        do {
            try dependencies.publishCancellationRequest(cancellation)
            dependencies.postCancellationChanged()
        } catch {
            dependencies.diagnostics.record(
                .cancellation,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .bridgeUnavailable
            )
            // Fail closed until the same bounded cancellation window expires.
        }
    }

    func pollCancellation(at now: Date) {
        guard let pendingCancellation else { return }
        if now >= pendingCancellation.expiresAt {
            if let activeRequest {
                dependencies.diagnostics.record(
                    .cancellation,
                    actionIdentifier:
                        activeRequest.identity.actionIdentifier,
                    requestID: activeRequest.identity.requestID,
                    outcome: .timedOut
                )
            }
            finishActiveRequest(
                status: pendingCancellation.completionStatus
            )
            return
        }
        let acknowledgement: KeyboardFixCancellationRecord?
        do {
            acknowledgement = try dependencies
                .consumeCancellationAcknowledgement(
                pendingCancellation.requestID,
                now
            )
        } catch {
            if let activeRequest {
                dependencies.diagnostics.record(
                    .cancellation,
                    actionIdentifier:
                        activeRequest.identity.actionIdentifier,
                    requestID: activeRequest.identity.requestID,
                    outcome: .bridgeUnavailable
                )
            }
            return
        }
        guard acknowledgement != nil else { return }
        if let activeRequest {
            dependencies.diagnostics.record(
                .cancellation,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .acknowledged
            )
        }
        finishActiveRequest(
            status: pendingCancellation.completionStatus
        )
    }

    func launchContainingApp(
        for request: KeyboardFixRequestRecord
    ) {
        guard let url = KeyboardFixLaunchRoute(
            requestID: request.requestID
        ).url else {
            handleLaunchFailure(for: request.identity)
            return
        }
        dependencies.diagnostics.record(
            .launch,
            actionIdentifier: request.actionIdentifier,
            requestID: request.requestID,
            outcome: .started
        )
        dependencies.openContainingApp(url) { [weak self] in
            self?.handleLaunchFailure(for: request.identity)
        }
    }

    private func handleLaunchFailure(
        for identity: KeyboardFixRequestIdentity
    ) {
        guard activeRequest?.identity == identity else { return }
        dependencies.diagnostics.record(
            .launch,
            actionIdentifier: identity.actionIdentifier,
            requestID: identity.requestID,
            outcome: .failed
        )
        requestCancellation(
            completingWith: .failure(
                message: "Could not open HoldType for this Fix."
            )
        )
    }
}
