import Foundation

@MainActor
extension KeyboardFixExtensionRuntime {
    func cancelActiveRequest() {
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
        do {
            try dependencies.publishCancellationRequest(cancellation)
            dependencies.postCancellationChanged()
        } catch {
            // Fail closed until the same bounded cancellation window expires.
        }
    }

    func pollCancellation(at now: Date) {
        guard let pendingCancellation else { return }
        if now >= pendingCancellation.expiresAt {
            finishActiveRequest(
                status: pendingCancellation.completionStatus
            )
            return
        }
        let acknowledgement = try? dependencies
            .consumeCancellationAcknowledgement(
                pendingCancellation.requestID,
                now
            )
        guard acknowledgement != nil else { return }
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
        dependencies.openContainingApp(url) { [weak self] in
            self?.handleLaunchFailure(for: request.identity)
        }
    }

    private func handleLaunchFailure(
        for identity: KeyboardFixRequestIdentity
    ) {
        guard activeRequest?.identity == identity else { return }
        requestCancellation(
            completingWith: .failure(
                message: "Could not open HoldType for this Fix."
            )
        )
    }
}
