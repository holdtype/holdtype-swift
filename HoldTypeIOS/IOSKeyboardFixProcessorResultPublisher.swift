import Foundation

nonisolated struct IOSKeyboardFixResultPublisher {
    let request: KeyboardFixRequestRecord
    let bridge: IOSKeyboardFixBridgeClient
    let clock: IOSKeyboardFixProcessorClock
    let signals: IOSKeyboardFixSignalClient

    func publishProcessing() -> Bool {
        guard let result = makeRecord(
            output: nil,
            failure: nil,
            phase: .processing
        ) else {
            signals.emit(.bridgeUnavailable)
            return false
        }
        do {
            try bridge.publishResult(result)
        } catch {
            signals.emit(.bridgeUnavailable)
            return false
        }
        signals.emit(
            .processing(
                requestID: request.requestID,
                actionIdentifier: request.actionIdentifier
            )
        )
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
            return .bridgeUnavailable
        }
        signals.emit(
            .terminal(
                requestID: request.requestID,
                actionIdentifier: request.actionIdentifier,
                outcome: outcome
            )
        )
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
        return .bridgeUnavailable
    }

    private func encodedSize(of result: KeyboardFixResultRecord) -> Int {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(result).count) ?? Int.max
    }
}
