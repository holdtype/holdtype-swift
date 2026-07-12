import Foundation
import HoldTypeDomain

/// The P4-only accepted-output input. Callers cannot opt into History or
/// automatic insertion through this surface.
public struct IOSForegroundVoiceAcceptedOutputPreparation: Equatable, Sendable {
    let deliveryPreparation: IOSAcceptedOutputDeliveryPreparation

    public var deliveryID: UUID { deliveryPreparation.deliveryID }
    public var sessionID: UUID { deliveryPreparation.sessionID }
    public var attemptID: UUID { deliveryPreparation.attemptID }
    public var transcriptID: UUID { deliveryPreparation.transcriptID }
    public var outputIntent: DictationOutputIntent {
        deliveryPreparation.outputIntent
    }
    public var keepLatestResult: Bool {
        deliveryPreparation.keepLatestResult
    }

    public init(
        deliveryID: UUID,
        sessionID: UUID,
        attemptID: UUID,
        transcriptID: UUID,
        rawAcceptedText: String,
        outputIntent: DictationOutputIntent,
        keepLatestResult: Bool
    ) throws {
        deliveryPreparation = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: deliveryID,
            sessionID: sessionID,
            attemptID: attemptID,
            transcriptID: transcriptID,
            rawAcceptedText: rawAcceptedText,
            outputIntent: outputIntent,
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: keepLatestResult,
            historyWrite: nil
        )
    }
}

public struct IOSForegroundVoiceSavingResultExpectation: Equatable, Sendable {
    public let deliveryID: UUID
    public let sessionID: UUID
    public let attemptID: UUID
    public let transcriptID: UUID

    init(preparation: IOSAcceptedOutputDeliveryPreparation) {
        deliveryID = preparation.deliveryID
        sessionID = preparation.sessionID
        attemptID = preparation.attemptID
        transcriptID = preparation.transcriptID
    }
}

public enum IOSForegroundVoiceAcceptanceResult: Equatable, Sendable {
    case resultReady(IOSAcceptedOutputDeliveryRecord)
    case savingResult(IOSForegroundVoiceSavingResultExpectation)
}

public enum IOSForegroundVoiceLatestResultObservation: Equatable, Sendable {
    case absent
    case resultReady(IOSAcceptedOutputDeliveryRecord)
    case savingResult(IOSForegroundVoiceSavingResultExpectation)
    case expired(IOSAcceptedOutputDeliveryExpectation)
    case clockRollbackAmbiguous(IOSAcceptedOutputDeliveryExpectation)
    case clearedCleanupPending
}

public enum IOSForegroundVoiceClearResult: Equatable, Sendable {
    case cleared
    case alreadyAbsent
    case clearedCleanupPending
}

public enum IOSForegroundVoicePersistenceError: Error, Equatable, Sendable {
    case cancelledBeforeOperation
    case reentrantOperation
    case repositoryIdentityConflict
    case localRecoveryPending
    case invalidPendingOwner
    case noSavingResult
    case savingResultIdentityMismatch
    case savingResultPending
}

struct IOSForegroundVoicePersistenceWork: Equatable, Sendable {
    let preparation: IOSAcceptedOutputDeliveryPreparation
    let pendingRecording: IOSPendingRecording

    var expectation: IOSForegroundVoiceSavingResultExpectation {
        IOSForegroundVoiceSavingResultExpectation(preparation: preparation)
    }

    func matches(
        _ expectation: IOSForegroundVoiceSavingResultExpectation
    ) -> Bool {
        self.expectation == expectation
    }
}

actor IOSForegroundVoicePersistenceOperationState {
    private var work: IOSForegroundVoicePersistenceWork?

    func begin(
        _ candidate: IOSForegroundVoicePersistenceWork
    ) throws -> IOSForegroundVoicePersistenceWork {
        if let work {
            guard work == candidate else {
                throw IOSForegroundVoicePersistenceError
                    .savingResultIdentityMismatch
            }
            return work
        }
        work = candidate
        return candidate
    }

    func current() -> IOSForegroundVoicePersistenceWork? { work }

    func clear(
        matching expectation: IOSForegroundVoiceSavingResultExpectation
    ) throws {
        guard let work else { return }
        guard work.matches(expectation) else {
            throw IOSForegroundVoicePersistenceError
                .savingResultIdentityMismatch
        }
        self.work = nil
    }
}

struct IOSForegroundVoiceAcceptedDestinationAuthorization: Sendable {
    let record: IOSAcceptedOutputDeliveryRecord
    let snapshot: IOSAcceptedOutputDeliveryJournalSnapshot
    let storeIdentity: IOSAcceptedOutputDeliveryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    func provesDestination(
        for recording: IOSPendingRecording,
        storeIdentity expectedStoreIdentity:
            IOSAcceptedOutputDeliveryStoreIdentity,
        ownerIdentity expectedOwnerIdentity:
            IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization expectedLease:
            IOSPersistenceOperationLeaseAuthorization
    ) -> Bool {
        record == snapshot.record
            && storeIdentity == expectedStoreIdentity
            && operationLeaseAuthorization.provesSameActiveLease(
                as: expectedLease
            )
            && ownerIdentity == expectedOwnerIdentity
            && record.isExactForegroundVoiceDestination(for: recording)
    }
}

struct IOSForegroundVoiceNoDestinationAuthorization: Sendable {
    let preparation: IOSAcceptedOutputDeliveryPreparation
    let pendingRecording: IOSPendingRecording
    let storeIdentity: IOSAcceptedOutputDeliveryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    func provesAbsence(
        for recording: IOSPendingRecording,
        storeIdentity expectedStoreIdentity:
            IOSAcceptedOutputDeliveryStoreIdentity,
        ownerIdentity expectedOwnerIdentity:
            IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization expectedLease:
            IOSPersistenceOperationLeaseAuthorization
    ) -> Bool {
        storeIdentity == expectedStoreIdentity
            && operationLeaseAuthorization.provesSameActiveLease(
                as: expectedLease
            )
            && ownerIdentity == expectedOwnerIdentity
            && pendingRecording == recording
            && preparation.attemptID == recording.attemptID
            && preparation.transcriptID == recording.transcriptionID
            && preparation.outputIntent == recording.outputIntent
    }
}

struct IOSForegroundVoicePendingAudioRemovalAuthorization: Sendable {
    let recording: IOSPendingRecording
    let storeIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    func provesRemoval(
        for candidate: IOSPendingRecording,
        storeIdentity expectedStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity expectedOwnerIdentity:
            IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization expectedLease:
            IOSPersistenceOperationLeaseAuthorization
    ) -> Bool {
        recording == candidate
            && storeIdentity == expectedStoreIdentity
            && ownerIdentity == expectedOwnerIdentity
            && operationLeaseAuthorization.provesSameActiveLease(
                as: expectedLease
            )
    }
}

extension IOSAcceptedOutputDeliveryRecord {
    var isForegroundVoiceAppOnlyRecord: Bool {
        failedRetryID == nil
            && publicationGeneration == 0
            && !automaticInsertionPreferenceEnabled
            && historyWrite == nil
            && (deliveryState == .pending || deliveryState == .discarded)
    }

    func isExactForegroundVoiceDestination(
        for recording: IOSPendingRecording
    ) -> Bool {
        isForegroundVoiceAppOnlyRecord
            && deliveryState == .pending
            && acceptedText != nil
            && attemptID == recording.attemptID
            && transcriptID == recording.transcriptionID
            && outputIntent == recording.outputIntent
    }

    func foregroundVoicePreparation()
        throws -> IOSAcceptedOutputDeliveryPreparation {
        guard isForegroundVoiceAppOnlyRecord,
              deliveryState == .pending,
              let acceptedText else {
            throw IOSAcceptedOutputDeliveryError.invalidRecord
        }
        return try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: deliveryID,
            sessionID: sessionID,
            attemptID: attemptID,
            transcriptID: transcriptID,
            rawAcceptedText: acceptedText,
            outputIntent: outputIntent,
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: keepLatestResult,
            historyWrite: nil
        )
    }
}

/// Canonical P4 app-only accepted-output and PendingRecording transaction.
/// It performs no History, outbox, bridge, or keyboard operation.
public struct IOSForegroundVoicePersistence: Sendable {
    private let operationGate: IOSPersistenceOperationGate
    private let pendingRecordingStore: IOSPendingRecordingStore
    private let deliveryStore: IOSAcceptedOutputDeliveryStore
    private let state: IOSForegroundVoicePersistenceOperationState
    private let productionContext:
        IOSAcceptedHistoryCoordinatorProcessContext?
    private let repositoryRegistration:
        IOSAcceptedHistoryCoordinatorRepositoryRegistration?

    public init(applicationSupportDirectoryURL: URL) {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry
            .shared
        let context = registry.context(for: applicationSupportDirectoryURL)
        operationGate = context.operationGate
        pendingRecordingStore = context.pendingRecordingStore
        deliveryStore = context.deliveryStore
        state = context.foregroundVoicePersistenceState
        productionContext = context
        repositoryRegistration =
            IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                registry: registry,
                context: context,
                applicationSupportDirectoryURL:
                    applicationSupportDirectoryURL
            )
    }

    init(
        operationGate: IOSPersistenceOperationGate,
        pendingRecordingStore: IOSPendingRecordingStore,
        deliveryStore: IOSAcceptedOutputDeliveryStore,
        state: IOSForegroundVoicePersistenceOperationState =
            IOSForegroundVoicePersistenceOperationState()
    ) {
        self.operationGate = operationGate
        self.pendingRecordingStore = pendingRecordingStore
        self.deliveryStore = deliveryStore
        self.state = state
        productionContext = nil
        repositoryRegistration = nil
    }

    public func accept(
        _ preparation: IOSForegroundVoiceAcceptedOutputPreparation,
        expectedPending: IOSPendingRecordingCASExpectation
    ) async throws -> IOSForegroundVoiceAcceptanceResult {
        try await performRootOperation { lease in
            let pending = try await requireOutputDeliveryPending(
                expected: expectedPending,
                preparation: preparation.deliveryPreparation,
                operationLeaseAuthorization: lease
            )
            let work = try await state.begin(
                IOSForegroundVoicePersistenceWork(
                    preparation: preparation.deliveryPreparation,
                    pendingRecording: pending
                )
            )
            do {
                return try await resume(
                    work,
                    operationLeaseAuthorization: lease
                )
            } catch {
                return .savingResult(work.expectation)
            }
        }
    }

    public func retrySavingResult(
        expected: IOSForegroundVoiceSavingResultExpectation
    ) async throws -> IOSForegroundVoiceAcceptanceResult {
        try await performRootOperation { lease in
            guard let work = await state.current() else {
                throw IOSForegroundVoicePersistenceError.noSavingResult
            }
            guard work.matches(expected) else {
                throw IOSForegroundVoicePersistenceError
                    .savingResultIdentityMismatch
            }
            do {
                return try await resume(
                    work,
                    operationLeaseAuthorization: lease
                )
            } catch {
                return .savingResult(work.expectation)
            }
        }
    }

    public func recoverRecordingFromSavingResult(
        expected: IOSForegroundVoiceSavingResultExpectation
    ) async throws -> IOSPendingRecording {
        try await performRootOperation { lease in
            guard let work = await state.current() else {
                throw IOSForegroundVoicePersistenceError.noSavingResult
            }
            guard work.matches(expected) else {
                throw IOSForegroundVoicePersistenceError
                    .savingResultIdentityMismatch
            }
            let absence = try await deliveryStore
                .proveForegroundVoiceDestinationAbsent(
                    preparation: work.preparation,
                    pendingRecording: work.pendingRecording,
                    operationLeaseAuthorization: lease
                )
            let recovered = try await pendingRecordingStore
                .moveForegroundVoiceOutputToRecovery(
                    expectedSource: work.pendingRecording,
                    absenceAuthorization: absence,
                    deliveryStoreIdentity: deliveryStore.storeIdentity,
                    operationLeaseAuthorization: lease
                )
            try await state.clear(matching: work.expectation)
            return recovered
        }
    }

    public func loadLatestResult()
        async throws -> IOSForegroundVoiceLatestResultObservation {
        try await performRootOperation { lease in
            let retainedWork = await state.current()
            let pending = try await pendingRecordingStore
                .loadForContainingAppBoundary(
                    operationLeaseAuthorization: lease
                )
            if let retainedWork {
                return .savingResult(retainedWork.expectation)
            }
            let delivery = try await deliveryStore
                .loadForegroundVoiceLatestResult(
                    operationLeaseAuthorization: lease
                )
            if let pending,
               pending.recording.phase == .outputDelivery,
               case .active(let record)? = delivery,
               record.isExactForegroundVoiceDestination(
                   for: pending.recording
               ) {
                return .savingResult(
                    IOSForegroundVoiceSavingResultExpectation(
                        preparation: try record
                            .foregroundVoicePreparation()
                    )
                )
            }
            guard let delivery else { return .absent }
            switch delivery {
            case .active(let record):
                if record.deliveryState == .discarded {
                    return .clearedCleanupPending
                }
                return .resultReady(record)
            case .expired(let expectation):
                return .expired(expectation)
            case .clockRollbackAmbiguous(let expectation):
                return .clockRollbackAmbiguous(expectation)
            }
        }
    }

    public func clearLatestResult(
        expected: IOSAcceptedOutputDeliveryExpectation
    ) async throws -> IOSForegroundVoiceClearResult {
        try await performRootOperation { lease in
            guard await state.current() == nil else {
                throw IOSForegroundVoicePersistenceError
                    .savingResultPending
            }
            if let pending = try await pendingRecordingStore
                .loadForContainingAppBoundary(
                    operationLeaseAuthorization: lease
                ), pending.recording.phase == .outputDelivery,
               pending.recording.attemptID == expected.attemptID,
               pending.recording.transcriptionID == expected.transcriptID {
                throw IOSForegroundVoicePersistenceError.savingResultPending
            }
            return try await deliveryStore.clearForegroundVoiceLatestResult(
                expected: expected,
                operationLeaseAuthorization: lease
            )
        }
    }

    private func resume(
        _ work: IOSForegroundVoicePersistenceWork,
        operationLeaseAuthorization lease:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSForegroundVoiceAcceptanceResult {
        let record = try await deliveryStore.acceptForegroundVoiceOutput(
            work.preparation,
            pendingRecording: work.pendingRecording,
            operationLeaseAuthorization: lease
        )
        let firstDestination = try await deliveryStore
            .confirmForegroundVoiceDestination(
                expected: IOSAcceptedOutputDeliveryExpectation(record: record),
                pendingRecording: work.pendingRecording,
                operationLeaseAuthorization: lease
            )
        let audioRemoval = try await pendingRecordingStore
            .removeForegroundVoiceAcceptedOutputAudio(
                expected: work.pendingRecording,
                destinationAuthorization: firstDestination,
                deliveryStoreIdentity: deliveryStore.storeIdentity,
                operationLeaseAuthorization: lease
            )
        let confirmedDestination = try await deliveryStore
            .confirmForegroundVoiceDestination(
                expected: IOSAcceptedOutputDeliveryExpectation(
                    record: firstDestination.record
                ),
                pendingRecording: work.pendingRecording,
                operationLeaseAuthorization: lease
            )
        try await pendingRecordingStore
            .retireForegroundVoiceAcceptedOutputJournal(
                expected: work.pendingRecording,
                destinationAuthorization: confirmedDestination,
                audioRemovalAuthorization: audioRemoval,
                deliveryStoreIdentity: deliveryStore.storeIdentity,
                operationLeaseAuthorization: lease
            )
        try await state.clear(matching: work.expectation)
        return .resultReady(confirmedDestination.record)
    }

    private func requireOutputDeliveryPending(
        expected: IOSPendingRecordingCASExpectation,
        preparation: IOSAcceptedOutputDeliveryPreparation,
        operationLeaseAuthorization lease:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSPendingRecording {
        guard let observation = try await pendingRecordingStore
            .loadForContainingAppBoundary(
                operationLeaseAuthorization: lease
            ) else {
            throw IOSForegroundVoicePersistenceError.invalidPendingOwner
        }
        let recording = observation.recording
        guard observation.availability == .available,
              IOSPendingRecordingCASExpectation(recording: recording)
                == expected,
              recording.phase == .outputDelivery,
              recording.attemptID == preparation.attemptID,
              recording.transcriptionID == preparation.transcriptID,
              recording.outputIntent == preparation.outputIntent else {
            throw IOSForegroundVoicePersistenceError.invalidPendingOwner
        }
        return recording
    }

    private func performRootOperation<Value: Sendable>(
        _ operation: @escaping @Sendable (
            IOSPersistenceOperationLeaseAuthorization
        ) async throws -> Value
    ) async throws -> Value {
        do {
            return try await operationGate.perform { lease in
                let repositoryBinding = try await beginProductionAdmission(
                    operationLeaseAuthorization: lease
                )
                do {
                    let value = try await operation(lease)
                    try finishProductionAdmission(
                        expectedBinding: repositoryBinding
                    )
                    return value
                } catch {
                    try finishProductionAdmission(
                        expectedBinding: repositoryBinding
                    )
                    throw error
                }
            }
        } catch IOSPersistenceOperationGate.AcquisitionError
            .cancelledBeforeLease {
            throw IOSForegroundVoicePersistenceError
                .cancelledBeforeOperation
        } catch IOSPersistenceOperationGate.AcquisitionError
            .reentrantOperation {
            throw IOSForegroundVoicePersistenceError.reentrantOperation
        }
    }

    private func beginProductionAdmission(
        operationLeaseAuthorization lease:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSAcceptedHistoryCoordinatorRepositoryBinding? {
        guard let context else { return nil }
        guard await context.failedHistoryRetryState.hasLiveOwner() == false,
              !context.failedHistoryMutationInterlock.isBlocked,
              await context.baselineRecoveryState.value() == false,
              await context.acceptanceState.current() == nil,
              await context.pendingReplacementState.current() == nil,
              await context.outboxWorkerState.current() == nil,
              await context.policyCutoverState.current() == nil,
              await context.failedHistoryTransferState.current() == nil,
              await context.failedHistoryAudioCleanupState.current() == nil,
              try await context.failedHistoryStore
                .hasPendingJournalRetirement(
                    operationLeaseAuthorization: lease
                ) == false else {
            throw IOSForegroundVoicePersistenceError.localRecoveryPending
        }
        let binding = repositoryRegistration?.revalidate()
        guard !context.repositoryIdentityState.isConflicted else {
            throw IOSForegroundVoicePersistenceError
                .repositoryIdentityConflict
        }
        return binding
    }

    private func finishProductionAdmission(
        expectedBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding?
    ) throws {
        guard let context, let expectedBinding else { return }
        let current = repositoryRegistration?.revalidate(
            expectedBinding: expectedBinding
        )
        guard current == expectedBinding,
              !context.repositoryIdentityState.isConflicted else {
            throw IOSForegroundVoicePersistenceError
                .repositoryIdentityConflict
        }
    }
}

private extension IOSForegroundVoicePersistence {
    var context: IOSAcceptedHistoryCoordinatorProcessContext? {
        productionContext
    }
}

extension IOSForegroundVoiceAcceptedOutputPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceAcceptedOutputPreparation(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceSavingResultExpectation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceSavingResultExpectation(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceAcceptanceResult:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceAcceptanceResult(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceLatestResultObservation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceLatestResultObservation(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceClearResult:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceClearResult(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoicePersistenceError:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoicePersistenceError(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoicePersistenceWork:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoicePersistenceWork(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceAcceptedDestinationAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceAcceptedDestinationAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceNoDestinationAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceNoDestinationAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoicePendingAudioRemovalAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoicePendingAudioRemovalAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoicePersistence:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoicePersistence(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
