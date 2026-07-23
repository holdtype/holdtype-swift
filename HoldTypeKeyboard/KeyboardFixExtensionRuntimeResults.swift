import Foundation

extension KeyboardFixExtensionRuntime {
    func recoverLatestResult() {
        guard activeRequest == nil,
              dependencies.hasFullAccess()
        else {
            return
        }
        let result: KeyboardFixResultRecord
        do {
            guard let loaded = try dependencies.loadLatestResult(
                dependencies.now()
            ) else {
                return
            }
            result = loaded
        } catch {
            dependencies.diagnostics.record(
                .result,
                outcome: .bridgeUnavailable
            )
            return
        }
        guard dependencies.currentTarget()?.matches(result.identity)
                == true else {
            handleStaleRecoveredResult(result)
            return
        }
        dependencies.diagnostics.record(
            .result,
            actionIdentifier: result.actionIdentifier,
            requestID: result.requestID,
            outcome: .started
        )
        let title = metadata?.action(
            identifier: result.actionIdentifier
        )?.title ?? "Fix"
        activeRequest = ActiveRequest(
            identity: result.identity,
            actionTitle: title,
            expiresAt: result.expiresAt
        )
        beginPolling()
        poll()
    }

    func handleTerminal(
        _ result: KeyboardFixResultRecord,
        activeRequest: ActiveRequest
    ) {
        switch result.phase {
        case .processing:
            return
        case .failed:
            dependencies.diagnostics.record(
                .result,
                actionIdentifier: result.actionIdentifier,
                requestID: result.requestID,
                outcome: (
                    result.failureCode ?? .providerFailed
                ).diagnosticOutcome
            )
            finishActiveRequest(
                status: .failure(
                    message: (
                        result.failureCode ?? .providerFailed
                    ).keyboardMessage
                )
            )
        case .succeeded:
            applySuccessfulResult(
                result,
                activeRequest: activeRequest
            )
        }
    }

    private func applySuccessfulResult(
        _ result: KeyboardFixResultRecord,
        activeRequest: ActiveRequest
    ) {
        guard let output = result.outputText else {
            dependencies.diagnostics.record(
                .output,
                actionIdentifier: result.actionIdentifier,
                requestID: result.requestID,
                outcome: .failed
            )
            finishActiveRequest(
                status: .failure(
                    message:
                        "The selected text changed. Select it again."
                )
            )
            return
        }
        guard dependencies.currentTarget()?.matches(result.identity)
                == true else {
            dependencies.diagnostics.record(
                .target,
                actionIdentifier: result.actionIdentifier,
                requestID: result.requestID,
                outcome: .stale
            )
            finishActiveRequest(
                status: .failure(
                    message:
                        "The selected text changed. Select it again."
                )
            )
            return
        }
        guard dependencies.applyOutput(output, result.identity) else {
            dependencies.diagnostics.record(
                .output,
                actionIdentifier: result.actionIdentifier,
                requestID: result.requestID,
                outcome: .stale
            )
            finishActiveRequest(
                status: .failure(
                    message:
                        "The selected text changed. Select it again."
                )
            )
            return
        }
        dependencies.diagnostics.record(
            .output,
            actionIdentifier: result.actionIdentifier,
            requestID: result.requestID,
            outcome: .succeeded
        )
        finishActiveRequest(
            status: .applied(
                message: "\(activeRequest.actionTitle) applied."
            )
        )
    }

    private func handleStaleRecoveredResult(
        _ result: KeyboardFixResultRecord
    ) {
        dependencies.diagnostics.record(
            .target,
            actionIdentifier: result.actionIdentifier,
            requestID: result.requestID,
            outcome: .stale
        )
        let completionStatus = KeyboardFixExtensionStatus.failure(
            message: "The selected text changed. Select it again."
        )
        if result.isTerminal {
            do {
                _ = try dependencies.consumeTerminalResult(
                    result.identity,
                    dependencies.now()
                )
            } catch {
                dependencies.diagnostics.record(
                    .result,
                    actionIdentifier: result.actionIdentifier,
                    requestID: result.requestID,
                    outcome: .bridgeUnavailable
                )
            }
            presentation = currentPresentation(
                status: completionStatus
            )
        } else {
            let title = metadata?.action(
                identifier: result.actionIdentifier
            )?.title ?? "Fix"
            activeRequest = ActiveRequest(
                identity: result.identity,
                actionTitle: title,
                expiresAt: result.expiresAt
            )
            requestCancellation(completingWith: completionStatus)
        }
    }
}
