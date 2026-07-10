import Foundation

struct IOSAcceptedHistoryOutboxJournalMutationAuthorization: Sendable {
    fileprivate init() {}
}

fileprivate struct IOSAcceptedHistoryOutboxCandidate: Equatable, Sendable {
    let delivery: IOSAcceptedOutputDeliveryAuthorization
    let entry: IOSAcceptedHistoryOutboxEntry

    init(delivery: IOSAcceptedOutputDeliveryAuthorization) throws {
        let record = delivery.record
        guard let marker = record.historyWrite,
              marker.state == .pending,
              let acceptedText = record.acceptedText else {
            throw IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        }
        self.delivery = delivery
        entry = try Self.makeEntry(
            record: record,
            marker: marker,
            acceptedText: acceptedText
        )
    }

    static func entry(
        from delivery: IOSAcceptedOutputDeliveryAuthorization
    ) throws -> IOSAcceptedHistoryOutboxEntry {
        let record = delivery.record
        guard let marker = record.historyWrite,
              marker.state == .pending,
              let acceptedText = record.acceptedText else {
            throw IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        }
        return try makeEntry(
            record: record,
            marker: marker,
            acceptedText: acceptedText
        )
    }

    private static func makeEntry(
        record: IOSAcceptedOutputDeliveryRecord,
        marker: IOSAcceptedOutputHistoryWrite,
        acceptedText: String
    ) throws -> IOSAcceptedHistoryOutboxEntry {
        try IOSAcceptedHistoryOutboxEntry(
            deliveryID: record.deliveryID,
            transcriptID: record.transcriptID,
            acceptedText: acceptedText,
            outputIntent: record.outputIntent,
            createdAt: record.createdAt,
            expiresAt: record.expiresAt,
            policyGeneration: marker.policyGeneration,
            transcriptionModel: marker.transcriptionModel,
            transcriptionLanguageCode: marker.transcriptionLanguageCode,
            durationMilliseconds: marker.durationMilliseconds
        )
    }
}

extension IOSAcceptedHistoryOutboxCandidate: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSAcceptedHistoryOutboxCandidate(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSAcceptedHistoryOutboxReceipt: Equatable, Sendable {
    fileprivate let entry: IOSAcceptedHistoryOutboxEntry
    fileprivate let snapshot: IOSAcceptedHistoryOutboxJournalSnapshot

    func provesMembership(
        for delivery: IOSAcceptedOutputDeliveryAuthorization
    ) -> Bool {
        guard let expected = try? IOSAcceptedHistoryOutboxCandidate.entry(
            from: delivery
        ),
            entry.hasSameImmutableBytes(as: expected) else {
            return false
        }
        return snapshot.envelope.entries.contains {
            $0.hasSameImmutableBytes(as: entry)
        }
    }

    func provesMembership(
        for observation: IOSAcceptedHistoryOutboxObservation
    ) -> Bool {
        entry.hasSameImmutableBytes(as: observation.entry)
            && snapshot.envelope.entries.contains {
                $0.hasSameImmutableBytes(as: entry)
            }
    }
}

extension IOSAcceptedHistoryOutboxReceipt: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSAcceptedHistoryOutboxReceipt(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSAcceptedHistoryOutboxObservation: Equatable, Sendable {
    let entry: IOSAcceptedHistoryOutboxEntry
    fileprivate let snapshot: IOSAcceptedHistoryOutboxJournalSnapshot

    fileprivate init(
        entry: IOSAcceptedHistoryOutboxEntry,
        snapshot: IOSAcceptedHistoryOutboxJournalSnapshot
    ) {
        self.entry = entry
        self.snapshot = snapshot
    }
}

extension IOSAcceptedHistoryOutboxObservation: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSAcceptedHistoryOutboxObservation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Internal ownership primitive. The coordinator supplies confirmed delivery
/// and policy capabilities and later consumes the exact membership receipt.
actor IOSAcceptedHistoryOutboxStore {
    private enum Source: Equatable, Sendable {
        case missing
        case existing(IOSAcceptedHistoryOutboxJournalSnapshot)
    }

    private struct Outcome: Equatable, Sendable {
        let envelope: IOSAcceptedHistoryOutboxEnvelope
    }

    private enum Operation: Equatable, Sendable {
        case transfer(IOSAcceptedHistoryOutboxCandidate)
        case deliveryConfirmation(IOSAcceptedHistoryOutboxEntry)
        case observationConfirmation(IOSAcceptedHistoryOutboxObservation)

        var entry: IOSAcceptedHistoryOutboxEntry {
            switch self {
            case .transfer(let candidate): candidate.entry
            case .deliveryConfirmation(let entry): entry
            case .observationConfirmation(let observation):
                observation.entry
            }
        }
    }

    private struct UncertainIntent: Equatable, Sendable {
        let source: Source
        let operation: Operation
        let outcome: Outcome
    }

    private let journal: any IOSAcceptedHistoryOutboxJournalStoring
    private let now: @Sendable () -> Date
    private var uncertainIntent: UncertainIntent?

    init(applicationSupportDirectoryURL: URL) {
        journal = FoundationIOSAcceptedHistoryOutboxJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        now = { Date() }
    }

    init(
        journal: any IOSAcceptedHistoryOutboxJournalStoring,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.journal = journal
        self.now = now
    }

    func load() throws -> IOSAcceptedHistoryOutboxEnvelope? {
        try journal.load()?.envelope
    }

    func observe() throws -> [IOSAcceptedHistoryOutboxObservation]? {
        guard uncertainIntent == nil else {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        }
        guard let snapshot = try journal.load() else { return nil }
        return snapshot.envelope.entries.map {
            IOSAcceptedHistoryOutboxObservation(
                entry: $0,
                snapshot: snapshot
            )
        }
    }

    func transfer(
        delivery: IOSAcceptedOutputDeliveryAuthorization,
        policy: IOSHistoryPolicyReceipt
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        let candidate = try IOSAcceptedHistoryOutboxCandidate(
            delivery: delivery
        )
        guard policy.state.historyEnabled,
              candidate.entry.policyGeneration
                == policy.state.policyGeneration else {
            throw IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        }
        let current = try journal.load()

        if let uncertainIntent {
            return try reconcileTransfer(
                uncertainIntent,
                candidate: candidate,
                current: current
            )
        }

        let temporalSnapshot = try currentTime()
        try requireLive(candidate.entry, at: temporalSnapshot)

        if let current {
            let outcome = try outcome(
                candidate,
                from: current.envelope,
                policyGeneration: policy.state.policyGeneration,
                now: temporalSnapshot
            )
            return try publish(
                outcome,
                source: .existing(current),
                operation: .transfer(candidate)
            )
        }

        let initial = try initialOutcome(candidate)
        do {
            return try publish(
                initial,
                source: .missing,
                operation: .transfer(candidate)
            )
        } catch IOSAcceptedHistoryOutboxError.slotOccupied {
            guard let raced = try journal.load() else {
                throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
            }
            return try publish(
                outcome(
                    candidate,
                    from: raced.envelope,
                    policyGeneration: policy.state.policyGeneration,
                    now: temporalSnapshot
                ),
                source: .existing(raced),
                operation: .transfer(candidate)
            )
        }
    }

    func confirmMembership(
        delivery: IOSAcceptedOutputDeliveryAuthorization
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        let candidate = try IOSAcceptedHistoryOutboxCandidate(
            delivery: delivery
        )
        let current = try journal.load()

        if let uncertainIntent {
            return try reconcileConfirmation(
                uncertainIntent,
                entry: candidate.entry,
                current: current
            )
        }

        guard let current else {
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        }
        _ = try exactMembership(of: candidate, in: current.envelope)
        return try publish(
            Outcome(envelope: current.envelope),
            source: .existing(current),
            operation: .deliveryConfirmation(candidate.entry)
        )
    }

    func confirmMembership(
        observation: IOSAcceptedHistoryOutboxObservation
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        let current = try journal.load()

        if let uncertainIntent {
            switch uncertainIntent.operation {
            case .observationConfirmation(let intendedObservation):
                guard observation == intendedObservation else {
                    throw IOSAcceptedHistoryOutboxError.commitUncertain
                }
            case .transfer, .deliveryConfirmation:
                guard current == observation.snapshot else {
                    throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
                }
            }
            return try reconcileConfirmation(
                uncertainIntent,
                entry: observation.entry,
                current: current
            )
        }

        guard let current,
              current == observation.snapshot else {
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        }
        guard current.envelope.entries.contains(where: {
            $0.hasSameImmutableBytes(as: observation.entry)
        }) else {
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        }
        return try publish(
            Outcome(envelope: current.envelope),
            source: .existing(current),
            operation: .observationConfirmation(observation)
        )
    }

    @discardableResult
    func performStagingMaintenance()
        throws -> IOSAcceptedHistoryOutboxMaintenanceReport {
        IOSAcceptedHistoryOutboxMaintenanceReport(
            try journal.performStagingMaintenance(now: now())
        )
    }
}

private extension IOSAcceptedHistoryOutboxStore {
    private func initialOutcome(
        _ candidate: IOSAcceptedHistoryOutboxCandidate
    ) throws -> Outcome {
        let envelope = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 1,
            entries: [candidate.entry]
        )
        guard try IOSAcceptedHistoryOutboxWireCodec
            .isWithinEncodedLimit(envelope) else {
            throw IOSAcceptedHistoryOutboxError.capacityExceeded
        }
        return Outcome(envelope: envelope)
    }

    private func outcome(
        _ candidate: IOSAcceptedHistoryOutboxCandidate,
        from current: IOSAcceptedHistoryOutboxEnvelope,
        policyGeneration: Int64,
        now: Date
    ) throws -> Outcome {
        let duplicate = try collisionResult(
            candidate,
            in: current
        )
        try requireNoRollback(in: current, at: now)
        guard current.entries.allSatisfy({
            $0.policyGeneration <= policyGeneration
        }) else {
            throw IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        }
        if duplicate != nil {
            return Outcome(envelope: current)
        }

        guard current.revision < Int64.max else {
            throw IOSAcceptedHistoryOutboxError.revisionOverflow
        }

        var entries = current.entries.filter { entry in
            entry.policyGeneration == policyGeneration
                && entry.temporalState(at: now) == .live
        }
        entries.append(candidate.entry)
        entries = IOSAcceptedHistoryOutboxValidation.sorted(entries)
        guard entries.count
                <= IOSAcceptedHistoryOutboxValidation.maximumEntryCount else {
            throw IOSAcceptedHistoryOutboxError.capacityExceeded
        }
        let envelope = try IOSAcceptedHistoryOutboxEnvelope(
            revision: current.revision + 1,
            entries: entries
        )
        guard try IOSAcceptedHistoryOutboxWireCodec
            .isWithinEncodedLimit(envelope) else {
            throw IOSAcceptedHistoryOutboxError.capacityExceeded
        }
        return Outcome(envelope: envelope)
    }

    private func collisionResult(
        _ candidate: IOSAcceptedHistoryOutboxCandidate,
        in envelope: IOSAcceptedHistoryOutboxEnvelope
    ) throws -> IOSAcceptedHistoryOutboxEntry? {
        if let existing = envelope.entries.first(where: {
            $0.deliveryID == candidate.entry.deliveryID
        }) {
            guard existing.hasSameImmutableBytes(as: candidate.entry) else {
                throw IOSAcceptedHistoryOutboxError.collision
            }
            return existing
        }
        guard !envelope.entries.contains(where: {
            $0.transcriptID == candidate.entry.transcriptID
        }) else {
            throw IOSAcceptedHistoryOutboxError.collision
        }
        return nil
    }

    private func exactMembership(
        of candidate: IOSAcceptedHistoryOutboxCandidate,
        in envelope: IOSAcceptedHistoryOutboxEnvelope
    ) throws -> IOSAcceptedHistoryOutboxEntry {
        if let existing = envelope.entries.first(where: {
            $0.deliveryID == candidate.entry.deliveryID
        }) {
            guard existing.hasSameImmutableBytes(as: candidate.entry) else {
                throw IOSAcceptedHistoryOutboxError.collision
            }
            return existing
        }
        if envelope.entries.contains(where: {
            $0.transcriptID == candidate.entry.transcriptID
        }) {
            throw IOSAcceptedHistoryOutboxError.collision
        }
        throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
    }

    private func currentTime() throws -> Date {
        do {
            return try IOSAcceptedOutputDeliveryTimestampCodec.canonicalDate(
                from: now()
            )
        } catch {
            throw IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        }
    }

    private func requireLive(
        _ entry: IOSAcceptedHistoryOutboxEntry,
        at now: Date
    ) throws {
        switch entry.temporalState(at: now) {
        case .live:
            return
        case .expired:
            throw IOSAcceptedHistoryOutboxError.expired
        case .clockRollbackAmbiguous:
            throw IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        }
    }

    private func requireNoRollback(
        in envelope: IOSAcceptedHistoryOutboxEnvelope,
        at now: Date
    ) throws {
        guard !envelope.entries.contains(where: {
            $0.temporalState(at: now) == .clockRollbackAmbiguous
        }) else {
            throw IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        }
    }

    private func publish(
        _ outcome: Outcome,
        source: Source,
        operation: Operation
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        let intent = UncertainIntent(
            source: source,
            operation: operation,
            outcome: outcome
        )
        do {
            let snapshot: IOSAcceptedHistoryOutboxJournalSnapshot =
                switch source {
                case .missing:
                    try journal.create(
                        outcome.envelope,
                        authorization:
                            IOSAcceptedHistoryOutboxJournalMutationAuthorization()
                    )
                case .existing(let current):
                    try journal.replace(
                        outcome.envelope,
                        expected: current,
                        authorization:
                            IOSAcceptedHistoryOutboxJournalMutationAuthorization()
                    )
                }
            uncertainIntent = nil
            return IOSAcceptedHistoryOutboxReceipt(
                entry: operation.entry,
                snapshot: snapshot
            )
        } catch IOSAcceptedHistoryOutboxError.commitUncertain {
            uncertainIntent = intent
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        }
    }

    private func reconcileTransfer(
        _ intent: UncertainIntent,
        candidate: IOSAcceptedHistoryOutboxCandidate,
        current: IOSAcceptedHistoryOutboxJournalSnapshot?
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        guard case .transfer(let intendedCandidate) = intent.operation,
              candidate == intendedCandidate else {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        }

        if let current,
           current.envelope == intent.outcome.envelope {
            return try publish(
                intent.outcome,
                source: .existing(current),
                operation: intent.operation
            )
        }

        let sourceStillCurrent: Bool = switch (intent.source, current) {
        case (.missing, .none): true
        case (.existing(let source), .some(let current)): source == current
        default: false
        }
        guard sourceStillCurrent else {
            uncertainIntent = nil
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        }

        let temporalSnapshot = try currentTime()
        do {
            try requireLive(candidate.entry, at: temporalSnapshot)
            if let current {
                try requireNoRollback(
                    in: current.envelope,
                    at: temporalSnapshot
                )
            }
        } catch IOSAcceptedHistoryOutboxError.expired {
            uncertainIntent = nil
            throw IOSAcceptedHistoryOutboxError.expired
        }

        switch intent.source {
        case .missing:
            return try publish(
                intent.outcome,
                source: .missing,
                operation: intent.operation
            )
        case .existing:
            guard let current else {
                uncertainIntent = nil
                throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
            }
            return try publish(
                intent.outcome,
                source: .existing(current),
                operation: intent.operation
            )
        }
    }

    private func reconcileConfirmation(
        _ intent: UncertainIntent,
        entry: IOSAcceptedHistoryOutboxEntry,
        current: IOSAcceptedHistoryOutboxJournalSnapshot?
    ) throws -> IOSAcceptedHistoryOutboxReceipt {
        guard intent.operation.entry.hasSameImmutableBytes(as: entry) else {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        }
        if let current,
           current.envelope == intent.outcome.envelope,
           current.envelope.entries.contains(where: {
               $0.hasSameImmutableBytes(as: entry)
           }) {
            return try publish(
                intent.outcome,
                source: .existing(current),
                operation: intent.operation
            )
        }

        let sourceStillCurrent: Bool = switch (intent.source, current) {
        case (.missing, .none): true
        case (.existing(let source), .some(let current)): source == current
        default: false
        }
        if sourceStillCurrent {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        }

        if current?.envelope != intent.outcome.envelope {
            uncertainIntent = nil
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        }
        throw IOSAcceptedHistoryOutboxError.commitUncertain
    }
}
