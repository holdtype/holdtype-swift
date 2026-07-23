import Foundation

extension KeyboardFixExtensionRuntime {
    func recoverLatestResult() {
        guard activeRequest == nil,
              dependencies.hasFullAccess(),
              let result = try? dependencies.loadLatestResult(
                  dependencies.now()
              )
        else {
            return
        }
        guard dependencies.currentTarget()?.matches(result.identity)
                == true else {
            handleStaleRecoveredResult(result)
            return
        }
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
        guard let output = result.outputText,
              dependencies.currentTarget()?.matches(result.identity)
                == true,
              dependencies.applyOutput(output, result.identity)
        else {
            finishActiveRequest(
                status: .failure(
                    message:
                        "The selected text changed. Select it again."
                )
            )
            return
        }
        finishActiveRequest(
            status: .applied(
                message: "\(activeRequest.actionTitle) applied."
            )
        )
    }

    private func handleStaleRecoveredResult(
        _ result: KeyboardFixResultRecord
    ) {
        let completionStatus = KeyboardFixExtensionStatus.failure(
            message: "The selected text changed. Select it again."
        )
        if result.isTerminal {
            _ = try? dependencies.consumeTerminalResult(
                result.identity,
                dependencies.now()
            )
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
