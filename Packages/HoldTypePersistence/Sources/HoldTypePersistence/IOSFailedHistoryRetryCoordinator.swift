import Foundation
import HoldTypeDomain

enum IOSFailedHistoryRetryCredentialEligibility: Equatable, Sendable {
    case available
    case unavailable
}

/// Transient containing-app setup frozen before the durable reservation. It
/// contains no credential material; eligibility is only the already-validated
/// result of the app-owned credential/setup check.
struct IOSFailedHistoryRetrySetupSnapshot: Equatable, Sendable {
    let transcriptionConfiguration: TranscriptionConfiguration
    let translationConfiguration: TranslationConfiguration?
    let keepLatestResult: Bool

    init(
        credentialEligibility:
            IOSFailedHistoryRetryCredentialEligibility,
        transcriptionConfiguration: TranscriptionConfiguration,
        translationConfiguration: TranslationConfiguration?,
        keepLatestResult: Bool
    ) throws {
        guard credentialEligibility == .available,
              !transcriptionConfiguration.customLanguageCodeValidation
                .isInvalid,
              IOSPendingRecordingValidation.isValidModel(
                  transcriptionConfiguration.resolvedModel
              ),
              IOSPendingRecordingValidation.isValidLanguageCode(
                  transcriptionConfiguration.resolvedLanguageCode
              ),
              translationConfiguration.map({ configuration in
                  configuration.canRunAction
                      && IOSPendingRecordingValidation.isValidModel(
                          configuration.resolvedModel
                      )
              }) ?? true else {
            throw IOSFailedHistoryError.invalidTransition
        }
        self.transcriptionConfiguration = transcriptionConfiguration
        self.translationConfiguration = translationConfiguration
        self.keepLatestResult = keepLatestResult
    }

    func supports(_ outputIntent: DictationOutputIntent) -> Bool {
        switch outputIntent {
        case .standard:
            translationConfiguration == nil
        case .translate:
            translationConfiguration?.canRunAction == true
        }
    }
}

extension IOSFailedHistoryRetrySetupSnapshot: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetrySetupSnapshot(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// A successful provider invocation plus the exact terminal authority required
/// by the next durable Retry transition. C4.4B consumes this value; C4.4A does
/// not interpret provider outcomes or clear the live owner on completion.
struct IOSFailedHistoryRetryProviderCompletion<Outcome: Sendable>: Sendable {
    let outcome: Outcome
    let dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt
    let claim: IOSFailedHistoryRetryProviderCompletionClaim
    let setup: IOSFailedHistoryRetrySetupSnapshot
}

extension IOSFailedHistoryRetryProviderCompletion: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryProviderCompletion(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// One process-local, one-shot provider handoff for an exact durable Retry.
/// The provider closure runs only after the root gate turn that created this
/// value has ended. Cancellation and deinit both use the same exact durable
/// cleanup relay.
final class IOSFailedHistoryRetryHandoff: @unchecked Sendable {
    private let audio: IOSPendingTranscriptionAudio
    private let dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt
    private let registration: IOSFailedHistoryRetryProviderRegistration
    private let retryState: IOSFailedHistoryRetryLiveOwnerState
    private let setup: IOSFailedHistoryRetrySetupSnapshot
    private let cancellationRelay:
        IOSFailedHistoryRetryCancellationRelay

    fileprivate init(
        audio: IOSPendingTranscriptionAudio,
        dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration,
        retryState: IOSFailedHistoryRetryLiveOwnerState,
        setup: IOSFailedHistoryRetrySetupSnapshot,
        cancellationRelay: IOSFailedHistoryRetryCancellationRelay
    ) {
        self.audio = audio
        self.dispatchReceipt = dispatchReceipt
        self.registration = registration
        self.retryState = retryState
        self.setup = setup
        self.cancellationRelay = cancellationRelay
    }

    /// Executes one provider operation. Provider-specific errors and timeouts
    /// are values here so C4.4B can map them before choosing a Store transition.
    func execute<Outcome: Sendable>(
        _ operation: @escaping @Sendable (
            IOSPendingTranscriptionAudio,
            IOSFailedHistoryRetrySetupSnapshot
        ) async -> Outcome
    ) async throws -> IOSFailedHistoryRetryProviderCompletion<Outcome> {
        guard let launchClaim = await retryState.claimProviderLaunch(
            registration
        ) else {
            throw IOSPendingRecordingError.dispatchAlreadyCommitted
        }

        let audio = audio
        let setup = setup
        let providerTask = Task<Outcome, Error> {
            defer { audio.invalidate() }
            try await launchClaim.waitForLaunch()
            try Task.checkCancellation()
            return await IOSFailedHistoryRetryProviderTaskContext
                .$cancellationOwnerIdentity.withValue(
                    ObjectIdentifier(cancellationRelay)
                ) {
                    await operation(audio, setup)
                }
        }
        await cancellationRelay.registerProviderDrain {
            _ = await providerTask.result
        }
        guard launchClaim.installRunningCancellation({
            providerTask.cancel()
        }) else {
            providerTask.cancel()
            _ = await providerTask.result
            try await cancellationRelay.cancel()
            throw IOSPendingRecordingError.dispatchAlreadyCommitted
        }

        if Task.isCancelled {
            try await cancellationRelay.cancel()
            _ = await providerTask.result
            throw CancellationError()
        }
        guard launchClaim.launch() else {
            providerTask.cancel()
            _ = await providerTask.result
            try await cancellationRelay.cancel()
            throw IOSPendingRecordingError.dispatchAlreadyCommitted
        }

        return try await withTaskCancellationHandler {
            let result = await providerTask.result
            if Task.isCancelled {
                try await cancellationRelay.cancel()
                throw CancellationError()
            }
            switch result {
            case .success(let outcome):
                guard let terminal = await retryState
                    .claimProviderCompletion(launchClaim),
                      case .completion(let completionClaim) = terminal else {
                    try await cancellationRelay.cancel()
                    throw CancellationError()
                }
                await cancellationRelay.markProviderCompletionClaimed()
                return IOSFailedHistoryRetryProviderCompletion(
                    outcome: outcome,
                    dispatchReceipt: dispatchReceipt,
                    claim: completionClaim,
                    setup: setup
                )
            case .failure:
                try await cancellationRelay.cancel()
                throw CancellationError()
            }
        } onCancel: {
            cancellationRelay.requestCancellation()
        }
    }

    func cancel() async throws {
        if IOSFailedHistoryRetryProviderTaskContext
            .cancellationOwnerIdentity
            == ObjectIdentifier(cancellationRelay) {
            try await cancellationRelay.cancelFromProviderTask()
        } else {
            try await cancellationRelay.cancel()
        }
    }

    /// Nonblocking cancellation request for callback tasks that cannot safely
    /// await the provider task they are helping unwind.
    func requestCancellation() {
        cancellationRelay.requestCancellation()
    }

    deinit {
        cancellationRelay.requestCancellation()
    }
}

private enum IOSFailedHistoryRetryProviderTaskContext {
    @TaskLocal static var cancellationOwnerIdentity: ObjectIdentifier?
}

extension IOSFailedHistoryRetryHandoff: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryHandoff(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

private actor IOSFailedHistoryRetryCancellationRelay:
    IOSFailedHistoryRetryCancellationOwner {
    private struct InFlight: Sendable {
        let id: UUID
        let task: Task<Void, Error>
    }

    private let dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt
    private let registration: IOSFailedHistoryRetryProviderRegistration
    private let retryState: IOSFailedHistoryRetryLiveOwnerState
    private let operationGate: IOSPersistenceOperationGate
    private let failedStore: IOSFailedHistoryStore
    private let repositoryIdentityState:
        IOSAcceptedHistoryCoordinatorRepositoryIdentityState
    private let repositoryRegistration:
        IOSAcceptedHistoryCoordinatorRepositoryRegistration?

    private var cancellationClaim:
        IOSFailedHistoryRetryProviderCancellationClaim?
    private var cancellationClaimTask:
        Task<IOSFailedHistoryRetryProviderCancellationClaim, Error>?
    private var providerDrain: (@Sendable () async -> Void)?
    private var inFlight: InFlight?
    private var cancellationCompleted = false
    private var providerCompletionClaimed = false
    private var audioInvalidations: [@Sendable () -> Void]

    init(
        dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration,
        retryState: IOSFailedHistoryRetryLiveOwnerState,
        operationGate: IOSPersistenceOperationGate,
        failedStore: IOSFailedHistoryStore,
        repositoryIdentityState:
            IOSAcceptedHistoryCoordinatorRepositoryIdentityState,
        repositoryRegistration:
            IOSAcceptedHistoryCoordinatorRepositoryRegistration?,
        audioInvalidation: @escaping @Sendable () -> Void
    ) {
        self.dispatchReceipt = dispatchReceipt
        self.registration = registration
        self.retryState = retryState
        self.operationGate = operationGate
        self.failedStore = failedStore
        self.repositoryIdentityState = repositoryIdentityState
        self.repositoryRegistration = repositoryRegistration
        audioInvalidations = [audioInvalidation]
    }

    nonisolated func requestCancellation() {
        Task.detached { [self] in
            for _ in 0..<3 {
                do {
                    try await cancel()
                    return
                } catch {
                    await Task.yield()
                }
            }
        }
    }

    func registerProviderDrain(
        _ drain: @escaping @Sendable () async -> Void
    ) {
        guard providerDrain == nil,
              !cancellationCompleted,
              !providerCompletionClaimed else {
            return
        }
        providerDrain = drain
    }

    func registerProviderAudio(_ audio: IOSPendingTranscriptionAudio) {
        guard cancellationClaim == nil,
              !cancellationCompleted,
              !providerCompletionClaimed else {
            audio.invalidate()
            return
        }
        audioInvalidations.append { audio.invalidate() }
    }

    func markProviderCompletionClaimed() {
        providerCompletionClaimed = true
        providerDrain = nil
    }

    func cancel() async throws {
        guard !cancellationCompleted else { return }
        guard !providerCompletionClaimed else {
            throw IOSFailedHistoryError.invalidTransition
        }
        let work = cancellationWork()

        do {
            try await work.task.value
            if inFlight?.id == work.id {
                inFlight = nil
                cancellationCompleted = true
                providerDrain = nil
            }
        } catch {
            if inFlight?.id == work.id {
                inFlight = nil
            }
            throw error
        }
    }

    /// A provider task cannot await its own drain. It atomically retires the
    /// provider authority, starts the normal cleanup relay, and returns so that
    /// the provider closure can unwind and satisfy that relay's drain.
    func cancelFromProviderTask() async throws {
        guard !cancellationCompleted else { return }
        guard !providerCompletionClaimed else {
            throw IOSFailedHistoryError.invalidTransition
        }
        _ = try await exactCancellationClaim()
        invalidateProviderAudio()
        _ = cancellationWork()
    }

    private func cancellationWork() -> InFlight {
        if let inFlight { return inFlight }
        let id = UUID()
        let task = Task.detached { [self] in
            try await performCancellation()
        }
        let work = InFlight(id: id, task: task)
        inFlight = work
        return work
    }

    private func exactCancellationClaim() async throws
        -> IOSFailedHistoryRetryProviderCancellationClaim {
        if let cancellationClaim { return cancellationClaim }
        let task: Task<
            IOSFailedHistoryRetryProviderCancellationClaim,
            Error
        >
        if let cancellationClaimTask {
            task = cancellationClaimTask
        } else {
            let retryState = retryState
            let registration = registration
            task = Task.detached {
                guard let terminal = await retryState
                    .claimProviderCancellation(registration),
                      case .cancellation(let claim) = terminal else {
                    throw IOSFailedHistoryError.invalidTransition
                }
                return claim
            }
            cancellationClaimTask = task
        }
        do {
            let claim = try await task.value
            cancellationClaim = claim
            cancellationClaimTask = nil
            return claim
        } catch {
            cancellationClaimTask = nil
            throw error
        }
    }

    private func performCancellation() async throws {
        let claim = try await exactCancellationClaim()

        // The terminal claim has already retired provider authority. Releasing
        // descriptor access and draining a registered task happen before the
        // durable row becomes retryable again.
        invalidateProviderAudio()
        if let providerDrain {
            await providerDrain()
        }

        let operationGate = operationGate
        let dispatchReceipt = dispatchReceipt
        let retryState = retryState
        let failedStore = failedStore
        let repositoryIdentityState = repositoryIdentityState
        let repositoryRegistration = repositoryRegistration
        do {
            try await operationGate.perform { lease in
                let repositoryBinding = repositoryRegistration?.revalidate()
                guard !repositoryIdentityState.isConflicted else {
                    throw IOSAcceptedHistoryCoordinatorError
                        .repositoryIdentityConflict
                }
                let receipt = try await IOSAcceptedHistoryCoordinator
                    .commitExactRetryCancellation(
                        dispatchReceipt: dispatchReceipt,
                        providerCancellationClaim: claim,
                        failedStore: failedStore,
                        operationLeaseAuthorization: lease
                    )
                guard await retryState.consumeProviderCancellation(
                    using: receipt
                ) else {
                    throw IOSAcceptedHistoryCoordinatorError
                        .localRecoveryPending
                }
                if let repositoryBinding {
                    _ = repositoryRegistration?.revalidate(
                        expectedBinding: repositoryBinding
                    )
                }
                guard !repositoryIdentityState.isConflicted else {
                    throw IOSAcceptedHistoryCoordinatorError
                        .repositoryIdentityConflict
                }
            }
        } catch IOSPersistenceOperationGate.AcquisitionError
            .cancelledBeforeLease {
            throw IOSAcceptedHistoryCoordinatorError.cancelledBeforeOperation
        } catch IOSPersistenceOperationGate.AcquisitionError
            .reentrantOperation {
            throw IOSAcceptedHistoryCoordinatorError.reentrantOperation
        }
    }

    private func invalidateProviderAudio() {
        let invalidations = audioInvalidations
        audioInvalidations.removeAll()
        for invalidate in invalidations {
            invalidate()
        }
    }
}

extension IOSAcceptedHistoryCoordinator {
    /// Reserves exactly one ready failed row, validates and holds its descriptor,
    /// durably publishes provider dispatch, and registers the matching stable
    /// live owner before the root gate is released.
    func prepareFailedHistoryRetry(
        attemptID: UUID,
        setup: IOSFailedHistoryRetrySetupSnapshot
    ) async throws -> IOSFailedHistoryRetryHandoff {
        guard let pendingRecordingStore else {
            throw IOSAcceptedHistoryCoordinatorError.localRecoveryPending
        }
        let policyStore = policyStore
        let failedStore = failedHistoryStore
        let retryState = failedHistoryRetryState
        let operationGate = operationGate
        let baselineRecoveryState = baselineRecoveryState
        let acceptanceState = acceptanceState
        let pendingReplacementState = pendingReplacementState
        let outboxWorkerState = outboxWorkerState
        let policyCutoverState = policyCutoverState
        let failedTransferState = failedHistoryTransferState
        let failedAudioCleanupState = failedHistoryAudioCleanupState
        let failedMutationInterlock = failedHistoryMutationInterlock
        let deliveryStore = deliveryStore
        let repositoryIdentityState = repositoryIdentityState
        let repositoryRegistration = repositoryRegistration
        let transcriptionConfiguration = setup.transcriptionConfiguration

        // A previous handoff may have exhausted its bounded immediate cleanup
        // attempts after already minting the exact terminal cancellation claim.
        // Retrigger only that terminal work here; an active provider whose
        // cancellation has not begun remains untouched and is rejected below.
        if await retryState.requestRetainedProviderCancellation() {
            throw IOSAcceptedHistoryCoordinatorError.localRecoveryPending
        }

        let handoff: IOSFailedHistoryRetryHandoff
        do {
            handoff = try await operationGate.perform { lease in
                let repositoryBinding = repositoryRegistration?.revalidate()
                guard !repositoryIdentityState.isConflicted else {
                    throw IOSAcceptedHistoryCoordinatorError
                        .repositoryIdentityConflict
                }
                do {
                    guard await baselineRecoveryState.value() == false,
                          await acceptanceState.current() == nil,
                          await pendingReplacementState.current() == nil,
                          await outboxWorkerState.current() == nil,
                          await policyCutoverState.current() == nil,
                          await failedTransferState.current() == nil,
                          await failedAudioCleanupState.current() == nil,
                          await retryState.hasLiveOwner() == false,
                          await retryState.hasCancellationReservation()
                            == false,
                          !failedMutationInterlock.isBlocked,
                          await deliveryStore
                            .hasUncertainAcceptanceForHistoryCoordinator()
                            == false,
                          await deliveryStore
                            .hasRetainedHistoryWorkForPolicyCutover()
                            == false else {
                        throw IOSAcceptedHistoryCoordinatorError
                            .localRecoveryPending
                    }

                    guard let currentPolicy = try await policyStore.load(),
                          currentPolicy.historyEnabled else {
                        throw IOSFailedHistoryError.stalePolicyGeneration
                    }
                    let policyReceipt = try await policyStore.confirm(
                        expected: IOSHistoryPolicyExpectation(
                            state: currentPolicy
                        )
                    )
                    guard policyReceipt.state == currentPolicy,
                          policyReceipt.state.historyEnabled else {
                        throw IOSFailedHistoryError.stalePolicyGeneration
                    }

                    let initialPreparation = try await failedStore
                        .prepareRetryReservation(
                            attemptID: attemptID,
                            transcriptionConfiguration:
                                transcriptionConfiguration,
                            using: policyReceipt,
                            operationLeaseAuthorization: lease
                        )
                    guard case .commit(let reservationAuthorization) =
                            initialPreparation else {
                        throw IOSAcceptedHistoryCoordinatorError
                            .localRecoveryPending
                    }
                    guard setup.supports(
                        reservationAuthorization.candidate.outputIntent
                    ) else {
                        throw IOSFailedHistoryError.invalidTransition
                    }

                    let audioSource = try await pendingRecordingStore
                        .acquireValidatedFailedHistoryRetryAudio(
                            using: reservationAuthorization,
                            operationLeaseAuthorization: lease
                        )
                    let reservationReceipt = try await Self
                        .commitExactRetryReservation(
                            initialAuthorization: reservationAuthorization,
                            audioSource: audioSource,
                            attemptID: attemptID,
                            transcriptionConfiguration:
                                transcriptionConfiguration,
                            policyReceipt: policyReceipt,
                            failedStore: failedStore,
                            operationLeaseAuthorization: lease
                        )

                    let initialDispatch:
                        IOSFailedHistoryRetryDispatchPreparation
                    do {
                        initialDispatch = try await failedStore
                            .prepareRetryDispatch(
                                using: reservationReceipt,
                                operationLeaseAuthorization: lease
                            )
                    } catch {
                        let dispatchPreparationError = error
                        guard !failedMutationInterlock.isBlocked else {
                            throw dispatchPreparationError
                        }
                        do {
                            _ = try await Self.cancelExactRetryReservation(
                                reservationReceipt: reservationReceipt,
                                failedStore: failedStore,
                                operationLeaseAuthorization: lease
                            )
                        } catch {
                            throw IOSAcceptedHistoryCoordinatorError
                                .localRecoveryPending
                        }
                        throw dispatchPreparationError
                    }
                    guard case .commit(let dispatchAuthorization) =
                            initialDispatch else {
                        throw IOSAcceptedHistoryCoordinatorError
                            .localRecoveryPending
                    }

                    let dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt
                    do {
                        dispatchReceipt = try await Self
                            .commitExactRetryDispatch(
                                initialAuthorization: dispatchAuthorization,
                                reservationReceipt: reservationReceipt,
                                failedStore: failedStore,
                                operationLeaseAuthorization: lease
                            )
                    } catch {
                        let dispatchCommitError = error
                        // A dispatch uncertainty may already be durable and must
                        // be recovered as that exact operation. Only a definite
                        // pre-dispatch failure may return the row to retryable.
                        if !failedMutationInterlock.isBlocked {
                            do {
                                _ = try await Self
                                    .cancelExactRetryReservation(
                                        reservationReceipt:
                                            reservationReceipt,
                                        failedStore: failedStore,
                                        operationLeaseAuthorization: lease
                                    )
                            } catch {
                                throw IOSAcceptedHistoryCoordinatorError
                                    .localRecoveryPending
                            }
                        }
                        throw dispatchCommitError
                    }

                    if let repositoryBinding {
                        _ = repositoryRegistration?.revalidate(
                            expectedBinding: repositoryBinding
                        )
                    }
                    guard !repositoryIdentityState.isConflicted,
                          let registration = await retryState
                            .registerLiveOwner(
                                dispatchReceipt.liveOwnerToken
                            ) else {
                        throw IOSAcceptedHistoryCoordinatorError
                            .repositoryIdentityConflict
                    }
                    let relay = IOSFailedHistoryRetryCancellationRelay(
                        dispatchReceipt: dispatchReceipt,
                        registration: registration,
                        retryState: retryState,
                        operationGate: operationGate,
                        failedStore: failedStore,
                        repositoryIdentityState: repositoryIdentityState,
                        repositoryRegistration: repositoryRegistration,
                        audioInvalidation: { audioSource.invalidate() }
                    )
                    guard await retryState.retainProviderCancellationOwner(
                        relay,
                        for: registration
                    ) else {
                        throw IOSAcceptedHistoryCoordinatorError
                            .localRecoveryPending
                    }

                    let audio: IOSPendingTranscriptionAudio
                    do {
                        audio = try audioSource.take(
                            using: dispatchReceipt,
                            registration: registration
                        )
                    } catch {
                        let audioTransferError = error
                        audioSource.invalidate()
                        guard let terminal = await retryState
                            .claimProviderCancellation(registration),
                              case .cancellation(let claim) = terminal else {
                            throw IOSAcceptedHistoryCoordinatorError
                                .localRecoveryPending
                        }
                        do {
                            let receipt = try await Self
                                .commitExactRetryCancellation(
                                dispatchReceipt: dispatchReceipt,
                                providerCancellationClaim: claim,
                                failedStore: failedStore,
                                operationLeaseAuthorization: lease
                            )
                            guard await retryState
                                .consumeProviderCancellation(using: receipt)
                            else {
                                throw IOSAcceptedHistoryCoordinatorError
                                    .localRecoveryPending
                            }
                        } catch {
                            relay.requestCancellation()
                            throw error
                        }
                        throw audioTransferError
                    }
                    await relay.registerProviderAudio(audio)
                    return IOSFailedHistoryRetryHandoff(
                        audio: audio,
                        dispatchReceipt: dispatchReceipt,
                        registration: registration,
                        retryState: retryState,
                        setup: setup,
                        cancellationRelay: relay
                    )
                } catch {
                    if let repositoryBinding {
                        _ = repositoryRegistration?.revalidate(
                            expectedBinding: repositoryBinding
                        )
                    }
                    if repositoryIdentityState.isConflicted {
                        throw IOSAcceptedHistoryCoordinatorError
                            .repositoryIdentityConflict
                    }
                    throw error
                }
            }
        } catch IOSPersistenceOperationGate.AcquisitionError
            .cancelledBeforeLease {
            throw IOSAcceptedHistoryCoordinatorError.cancelledBeforeOperation
        } catch IOSPersistenceOperationGate.AcquisitionError
            .reentrantOperation {
            throw IOSAcceptedHistoryCoordinatorError.reentrantOperation
        }

        if Task.isCancelled {
            try await handoff.cancel()
            throw CancellationError()
        }
        return handoff
    }

    fileprivate static func commitExactRetryReservation(
        initialAuthorization:
            IOSFailedHistoryRetryReservationAuthorization,
        audioSource: IOSFailedHistoryRetryAudioSource,
        attemptID: UUID,
        transcriptionConfiguration: TranscriptionConfiguration,
        policyReceipt: IOSHistoryPolicyReceipt,
        failedStore: IOSFailedHistoryStore,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSFailedHistoryRetryReservationReceipt {
        do {
            return try await failedStore.commitRetryReservation(
                using: initialAuthorization,
                validatedAudio: audioSource.validationReceipt
            )
        } catch IOSFailedHistoryError.commitUncertain {
            let retained = try await failedStore.prepareRetryReservation(
                attemptID: attemptID,
                transcriptionConfiguration: transcriptionConfiguration,
                using: policyReceipt,
                operationLeaseAuthorization: operationLeaseAuthorization
            )
            switch retained {
            case .completed(let receipt):
                return receipt
            case .commit(let authorization):
                guard authorization.identifiesSameReservation(
                    as: initialAuthorization
                ) else {
                    throw IOSFailedHistoryError.commitUncertain
                }
                return try await failedStore.commitRetryReservation(
                    using: authorization,
                    validatedAudio: audioSource.validationReceipt
                )
            }
        }
    }

    fileprivate static func commitExactRetryDispatch(
        initialAuthorization: IOSFailedHistoryRetryDispatchAuthorization,
        reservationReceipt: IOSFailedHistoryRetryReservationReceipt,
        failedStore: IOSFailedHistoryStore,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSFailedHistoryRetryDispatchReceipt {
        do {
            return try await failedStore.commitRetryDispatch(
                using: initialAuthorization
            )
        } catch IOSFailedHistoryError.commitUncertain {
            let retained = try await failedStore.prepareRetryDispatch(
                using: reservationReceipt,
                operationLeaseAuthorization: operationLeaseAuthorization
            )
            switch retained {
            case .completed(let receipt):
                return receipt
            case .commit(let authorization):
                guard authorization.identifiesSameDispatch(
                    as: initialAuthorization
                ) else {
                    throw IOSFailedHistoryError.commitUncertain
                }
                return try await failedStore.commitRetryDispatch(
                    using: authorization
                )
            }
        }
    }

    @discardableResult
    fileprivate static func cancelExactRetryReservation(
        reservationReceipt: IOSFailedHistoryRetryReservationReceipt,
        failedStore: IOSFailedHistoryStore,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSFailedHistoryRetryCancellationReceipt {
        let preparation = try await failedStore.prepareRetryCancellation(
            using: reservationReceipt,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
        switch preparation {
        case .completed(let receipt):
            return receipt
        case .commit(let authorization):
            do {
                return try await failedStore.commitRetryCancellation(
                    using: authorization
                )
            } catch IOSFailedHistoryError.commitUncertain {
                let retained = try await failedStore
                    .prepareRetryCancellation(
                        using: reservationReceipt,
                        operationLeaseAuthorization:
                            operationLeaseAuthorization
                    )
                switch retained {
                case .completed(let receipt):
                    return receipt
                case .commit(let refreshed):
                    guard refreshed.identifiesSameCancellation(
                        as: authorization
                    ) else {
                        throw IOSFailedHistoryError.commitUncertain
                    }
                    return try await failedStore.commitRetryCancellation(
                        using: refreshed
                    )
                }
            }
        }
    }

    fileprivate static func commitExactRetryCancellation(
        dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        providerCancellationClaim:
            IOSFailedHistoryRetryProviderCancellationClaim,
        failedStore: IOSFailedHistoryStore,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSFailedHistoryRetryCancellationReceipt {
        let preparation = try await failedStore.prepareRetryCancellation(
            using: dispatchReceipt,
            providerCancellationClaim: providerCancellationClaim,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
        switch preparation {
        case .completed(let receipt):
            return receipt
        case .commit(let authorization):
            do {
                return try await failedStore.commitRetryCancellation(
                    using: authorization
                )
            } catch IOSFailedHistoryError.commitUncertain {
                let retained = try await failedStore
                    .prepareRetryCancellation(
                        using: dispatchReceipt,
                        providerCancellationClaim:
                            providerCancellationClaim,
                        operationLeaseAuthorization:
                            operationLeaseAuthorization
                    )
                switch retained {
                case .completed(let receipt):
                    return receipt
                case .commit(let refreshed):
                    guard refreshed.identifiesSameCancellation(
                        as: authorization
                    ) else {
                        throw IOSFailedHistoryError.commitUncertain
                    }
                    return try await failedStore.commitRetryCancellation(
                        using: refreshed
                    )
                }
            }
        }
    }
}
