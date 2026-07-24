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
        let interruptionStatus = KeyboardFixExtensionStatus.failure(
            message: "The Fix was interrupted. Select text and try again."
        )
        guard !result.isTerminal else {
            discardRecoveredTerminalResult(
                result,
                status: interruptionStatus
            )
            return
        }
        dependencies.diagnostics.record(
            .result,
            actionIdentifier: result.actionIdentifier,
            requestID: result.requestID,
            outcome: .cancelled
        )
        let title = metadata?.action(
            identifier: result.actionIdentifier
        )?.title ?? "Fix"
        activeRequest = ActiveRequest(
            identity: result.identity,
            actionTitle: title,
            expiresAt: result.expiresAt
        )
        requestCancellation(completingWith: interruptionStatus)
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

    private func discardRecoveredTerminalResult(
        _ result: KeyboardFixResultRecord,
        status: KeyboardFixExtensionStatus
    ) {
        dependencies.diagnostics.record(
            .target,
            actionIdentifier: result.actionIdentifier,
            requestID: result.requestID,
            outcome: .cancelled
        )
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
        presentation = currentPresentation(status: status)
    }
}
