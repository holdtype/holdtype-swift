import Foundation

nonisolated struct IOSKeyboardFixResultPublisher {
    let request: KeyboardFixRequestRecord
    let bridge: IOSKeyboardFixBridgeClient
    let clock: IOSKeyboardFixProcessorClock
    let signals: IOSKeyboardFixSignalClient
    let diagnostics: IOSRuntimeTextFixDiagnosticClient

    func publishProcessing() -> Bool {
        guard let result = makeRecord(
            output: nil,
            failure: nil,
            phase: .processing
        ) else {
            signals.emit(.bridgeUnavailable)
            record(.processing, outcome: .bridgeUnavailable)
            return false
        }
        do {
            try bridge.publishResult(result)
        } catch {
            signals.emit(.bridgeUnavailable)
            record(.processing, outcome: .bridgeUnavailable)
            return false
        }
        signals.emit(
            .processing(
                requestID: request.requestID,
                actionIdentifier: request.actionIdentifier
            )
        )
        record(.processing, outcome: .started)
        return true
    }

    func publishSuccess(_ output: String) -> IOSKeyboardFixProcessorOutcome {
        guard let result = makeRecord(
            output: output,
            failure: nil,
            phase: .succeeded
        ),
        encodedSize(of: result)
            <= KeyboardFixBridgeConfiguration.maximumResultBytes
        else {
            return publishFailure(.invalidOutput)
        }
        return publish(
            result,
            outcome: .succeeded
        )
    }

    func publishFailure(
        _ failure: KeyboardFixFailureCode
    ) -> IOSKeyboardFixProcessorOutcome {
        guard let result = makeRecord(
            output: nil,
            failure: failure,
            phase: .failed
        ) else {
            return expiredOrUnavailable()
        }
        return publish(
            result,
            outcome: .failed(failure)
        )
    }

    func reportExpired() -> IOSKeyboardFixProcessorOutcome {
        signals.emit(
            .expired(
                requestID: request.requestID,
                actionIdentifier: request.actionIdentifier
            )
        )
        record(.result, outcome: .expired)
        return .expired
    }

    private func publish(
        _ result: KeyboardFixResultRecord,
        outcome: IOSKeyboardFixTerminalOutcome
    ) -> IOSKeyboardFixProcessorOutcome {
        do {
            try bridge.publishResult(result)
        } catch {
            signals.emit(.bridgeUnavailable)
            record(.result, outcome: .bridgeUnavailable)
            return .bridgeUnavailable
        }
        signals.emit(
            .terminal(
                requestID: request.requestID,
                actionIdentifier: request.actionIdentifier,
                outcome: outcome
            )
        )
        let diagnosticOutcome: IOSDiagnosticTextFixOutcome = switch outcome {
        case .succeeded:
            .succeeded
        case .failed(let failure):
            failure.diagnosticOutcome
        }
        record(.result, outcome: diagnosticOutcome)
        return .completed(outcome)
    }

    private func makeRecord(
        output: String?,
        failure: KeyboardFixFailureCode?,
        phase: KeyboardFixResultPhase
    ) -> KeyboardFixResultRecord? {
        KeyboardFixResultRecord(
            identity: request.identity,
            phase: phase,
            outputText: output,
            failureCode: failure,
            requestIssuedAt: request.issuedAt,
            publishedAt: clock.now(),
            expiresAt: request.expiresAt
        )
    }

    private func expiredOrUnavailable() -> IOSKeyboardFixProcessorOutcome {
        if !request.isValid(at: clock.now()) {
            return reportExpired()
        }
        signals.emit(.bridgeUnavailable)
        record(.result, outcome: .bridgeUnavailable)
        return .bridgeUnavailable
    }

    private func record(
        _ stage: IOSDiagnosticTextFixStage,
        outcome: IOSDiagnosticTextFixOutcome
    ) {
        diagnostics.record(
            stage,
            actionIdentifier: request.actionIdentifier,
            requestID: request.requestID,
            outcome: outcome
        )
    }

    private func encodedSize(of result: KeyboardFixResultRecord) -> Int {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(result).count) ?? Int.max
    }
}
