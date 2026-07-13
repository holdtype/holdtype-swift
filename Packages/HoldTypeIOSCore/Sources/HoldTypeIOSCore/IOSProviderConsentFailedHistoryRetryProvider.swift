import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence

protocol IOSFailedHistoryRetryConsentStageExecuting: Sendable {
    func execute(
        _ authorization: IOSProviderConsentAuthorization,
        for stage: IOSProviderConsentProviderStage,
        operation: @escaping @Sendable () async
            -> IOSFailedHistoryRetryProviderTextOutcome
    ) async -> IOSProviderConsentStageOutcome<
        IOSFailedHistoryRetryProviderTextOutcome,
        IOSFailedHistoryRetryRuntimeFailure
    >
}

private struct IOSFailedHistoryRetryConsentStageExecutor:
    IOSFailedHistoryRetryConsentStageExecuting {
    let executor: IOSProviderConsentStageExecutor

    func execute(
        _ authorization: IOSProviderConsentAuthorization,
        for stage: IOSProviderConsentProviderStage,
        operation: @escaping @Sendable () async
            -> IOSFailedHistoryRetryProviderTextOutcome
    ) async -> IOSProviderConsentStageOutcome<
        IOSFailedHistoryRetryProviderTextOutcome,
        IOSFailedHistoryRetryRuntimeFailure
    > {
        await executor.execute(
            authorization,
            for: stage,
            operation: operation,
            normalizeFailure: { _ in .unknown }
        )
    }
}

/// Gates every failed-History Retry provider stage behind the exact consent
/// observation that survived session preflight.
struct IOSProviderConsentFailedHistoryRetryProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private let provider: any IOSFailedHistoryRetryProviderExecuting
    private let consentObservation: IOSProviderConsentObservation
    private let consentCoordinator: IOSProviderConsentCoordinator
    private let stageExecutor:
        any IOSFailedHistoryRetryConsentStageExecuting

    init(
        provider: any IOSFailedHistoryRetryProviderExecuting,
        consentObservation: IOSProviderConsentObservation,
        consentCoordinator: IOSProviderConsentCoordinator
    ) {
        self.provider = provider
        self.consentObservation = consentObservation
        self.consentCoordinator = consentCoordinator
        stageExecutor = IOSFailedHistoryRetryConsentStageExecutor(
            executor: IOSProviderConsentStageExecutor(
                consentCoordinator: consentCoordinator
            )
        )
    }

    init(
        provider: any IOSFailedHistoryRetryProviderExecuting,
        consentObservation: IOSProviderConsentObservation,
        consentCoordinator: IOSProviderConsentCoordinator,
        stageExecutor:
            any IOSFailedHistoryRetryConsentStageExecuting
    ) {
        self.provider = provider
        self.consentObservation = consentObservation
        self.consentCoordinator = consentCoordinator
        self.stageExecutor = stageExecutor
    }

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        let provider = provider
        return await execute(stage: .transcription) {
            await provider.transcribe(request)
        }
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        let provider = provider
        return await execute(stage: .correction) {
            await provider.correct(request)
        }
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        let provider = provider
        return await execute(stage: .translation) {
            await provider.translate(request)
        }
    }

    private func execute(
        stage: IOSProviderConsentProviderStage,
        operation: @escaping @Sendable () async
            -> IOSFailedHistoryRetryProviderTextOutcome
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        guard let authorization = consentCoordinator.makeAuthorization(
            from: consentObservation
        ) else {
            return Task.isCancelled
                ? .failure(.cancelled)
                : .failure(.authorizationUnavailable)
        }

        let outcome = await stageExecutor.execute(
            authorization,
            for: stage,
            operation: operation
        )
        return switch outcome {
        case .success(let providerOutcome):
            providerOutcome
        case .failure(let failure):
            .failure(failure)
        case .cancelled:
            .failure(.cancelled)
        case .authorizationUnavailable:
            .failure(.authorizationUnavailable)
        }
    }
}

extension IOSProviderConsentFailedHistoryRetryProvider:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSProviderConsentFailedHistoryRetryProvider(redacted)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
