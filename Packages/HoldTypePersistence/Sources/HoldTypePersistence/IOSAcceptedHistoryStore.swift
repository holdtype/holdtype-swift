import Foundation

struct IOSAcceptedHistoryJournalMutationAuthorization: Sendable {
    fileprivate init() {}
}

fileprivate struct IOSAcceptedHistoryCandidate: Equatable, Sendable {
    let entry: IOSAcceptedHistoryEntry

    init(
        delivery: IOSAcceptedOutputDeliveryAuthorization,
        policy: IOSHistoryPolicyReceipt
    ) throws {
        let record = delivery.record
        guard let marker = record.historyWrite,
              marker.state == .pending,
              policy.state.historyEnabled,
              marker.policyGeneration == policy.state.policyGeneration,
              let acceptedText = record.acceptedText else {
            throw IOSAcceptedHistoryError.stalePolicyGeneration
        }
        entry = try IOSAcceptedHistoryEntry(
            deliveryID: record.deliveryID,
            transcriptID: record.transcriptID,
            acceptedText: acceptedText,
            outputIntent: record.outputIntent,
            createdAt: record.createdAt,
            policyGeneration: marker.policyGeneration,
            transcriptionModel: marker.transcriptionModel,
            transcriptionLanguageCode: marker.transcriptionLanguageCode,
            durationMilliseconds: marker.durationMilliseconds,
            cachedAudioRelativeIdentifier: nil
        )
    }
}

extension IOSAcceptedHistoryCandidate: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSAcceptedHistoryCandidate(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

enum IOSAcceptedHistoryRetentionDecision: Equatable, Sendable {
    case retained
    case notRetained
}

struct IOSAcceptedHistoryRowReceipt: Equatable, Sendable {
    fileprivate let candidate: IOSAcceptedHistoryCandidate
    fileprivate let snapshot: IOSAcceptedHistoryJournalSnapshot
    fileprivate let retainedEntry: IOSAcceptedHistoryEntry?

    var decision: IOSAcceptedHistoryRetentionDecision {
        retainedEntry == nil ? .notRetained : .retained
    }

    var provesExactMembership: Bool { retainedEntry != nil }
}

extension IOSAcceptedHistoryRowReceipt: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSAcceptedHistoryRowReceipt(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Internal persistence primitive. The containing-app coordinator supplies
/// confirmed delivery and policy capabilities; raw generations are never an
/// input to this boundary.
actor IOSAcceptedHistoryStore {
    private enum Source: Equatable, Sendable {
        case missing
        case existing(IOSAcceptedHistoryJournalSnapshot)
    }

    private struct Outcome: Equatable, Sendable {
        let envelope: IOSAcceptedHistoryEnvelope
        let retainedEntry: IOSAcceptedHistoryEntry?
    }

    private struct UncertainIntent: Equatable, Sendable {
        let source: Source
        let candidate: IOSAcceptedHistoryCandidate
        let outcome: Outcome
    }

    private let journal: any IOSAcceptedHistoryJournalStoring
    private let now: @Sendable () -> Date
    private var uncertainIntent: UncertainIntent?

    init(applicationSupportDirectoryURL: URL) {
        journal = FoundationIOSAcceptedHistoryJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        now = { Date() }
    }

    init(
        journal: any IOSAcceptedHistoryJournalStoring,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.journal = journal
        self.now = now
    }

    /// Raw state is coordinator-only because stale generations remain on disk
    /// after a committed policy cutover until lifecycle reconciliation.
    func load() throws -> IOSAcceptedHistoryEnvelope? {
        try journal.load()?.envelope
    }

    func decideUpsert(
        delivery: IOSAcceptedOutputDeliveryAuthorization,
        policy: IOSHistoryPolicyReceipt
    ) throws -> IOSAcceptedHistoryRowReceipt {
        let candidate = try IOSAcceptedHistoryCandidate(
            delivery: delivery,
            policy: policy
        )
        let current = try journal.load()

        if let uncertainIntent {
            return try reconcile(
                uncertainIntent,
                candidate: candidate,
                current: current
            )
        }

        if let current {
            return try publish(
                outcome(candidate, from: current.envelope),
                source: .existing(current),
                candidate: candidate
            )
        }

        let initial = try initialOutcome(candidate)
        do {
            return try publish(
                initial,
                source: .missing,
                candidate: candidate
            )
        } catch IOSAcceptedHistoryError.slotOccupied {
            guard let raced = try journal.load() else {
                throw IOSAcceptedHistoryError.compareAndSwapFailed
            }
            return try publish(
                outcome(candidate, from: raced.envelope),
                source: .existing(raced),
                candidate: candidate
            )
        }
    }

    /// Relaunch recovery never inserts an absent row. Exact immutable
    /// membership is identically rewritten before a new receipt is issued.
    func confirmMembership(
        delivery: IOSAcceptedOutputDeliveryAuthorization,
        policy: IOSHistoryPolicyReceipt
    ) throws -> IOSAcceptedHistoryRowReceipt {
        let candidate = try IOSAcceptedHistoryCandidate(
            delivery: delivery,
            policy: policy
        )
        let current = try journal.load()

        if let uncertainIntent {
            let receipt = try reconcile(
                uncertainIntent,
                candidate: candidate,
                current: current
            )
            guard receipt.provesExactMembership else {
                throw IOSAcceptedHistoryError.compareAndSwapFailed
            }
            return receipt
        }

        guard let current else {
            throw IOSAcceptedHistoryError.compareAndSwapFailed
        }
        let retained = try exactMembership(
            of: candidate,
            in: current.envelope
        )
        return try publish(
            Outcome(envelope: current.envelope, retainedEntry: retained),
            source: .existing(current),
            candidate: candidate
        )
    }

    @discardableResult
    func performStagingMaintenance()
        throws -> IOSAcceptedHistoryMaintenanceReport {
        IOSAcceptedHistoryMaintenanceReport(
            try journal.performStagingMaintenance(now: now())
        )
    }
}

private extension IOSAcceptedHistoryStore {
    private func initialOutcome(
        _ candidate: IOSAcceptedHistoryCandidate
    ) throws -> Outcome {
        let entries = try trimToEncodedLimit(
            [candidate.entry],
            revision: 1
        )
        let envelope = try IOSAcceptedHistoryEnvelope(
            revision: 1,
            entries: entries
        )
        return Outcome(
            envelope: envelope,
            retainedEntry: retainedEntry(candidate, in: entries)
        )
    }

    private func outcome(
        _ candidate: IOSAcceptedHistoryCandidate,
        from current: IOSAcceptedHistoryEnvelope
    ) throws -> Outcome {
        if let duplicate = current.entries.first(where: {
            $0.deliveryID == candidate.entry.deliveryID
        }) {
            guard duplicate.hasSameImmutableBytes(as: candidate.entry) else {
                throw IOSAcceptedHistoryError.collision
            }
            return Outcome(envelope: current, retainedEntry: duplicate)
        }
        guard !current.entries.contains(where: {
            $0.transcriptID == candidate.entry.transcriptID
        }) else {
            throw IOSAcceptedHistoryError.collision
        }
        guard current.entries.allSatisfy({
            $0.policyGeneration <= candidate.entry.policyGeneration
        }) else {
            throw IOSAcceptedHistoryError.stalePolicyGeneration
        }

        var entries = current.entries.filter {
            $0.policyGeneration == candidate.entry.policyGeneration
        }
        entries.append(candidate.entry)
        entries = IOSAcceptedHistoryValidation.sorted(entries)
        if entries.count > IOSAcceptedHistoryValidation.maximumEntryCount {
            entries.removeLast(
                entries.count - IOSAcceptedHistoryValidation.maximumEntryCount
            )
        }

        let provisionalRevision: Int64
        if current.revision == Int64.max {
            provisionalRevision = current.revision
        } else {
            provisionalRevision = current.revision + 1
        }
        entries = try trimMutationToEncodedLimit(
            entries,
            provisionalRevision: provisionalRevision,
            current: current
        )

        let revision: Int64
        if entries == current.entries {
            revision = current.revision
        } else {
            let next = current.revision.addingReportingOverflow(1)
            guard !next.overflow else {
                throw IOSAcceptedHistoryError.revisionOverflow
            }
            revision = next.partialValue
        }
        let envelope = try IOSAcceptedHistoryEnvelope(
            revision: revision,
            entries: entries
        )
        return Outcome(
            envelope: envelope,
            retainedEntry: retainedEntry(candidate, in: entries)
        )
    }

    private func trimToEncodedLimit(
        _ source: [IOSAcceptedHistoryEntry],
        revision: Int64
    ) throws -> [IOSAcceptedHistoryEntry] {
        var entries = source
        while true {
            let envelope = try IOSAcceptedHistoryEnvelope(
                revision: revision,
                entries: entries
            )
            if try IOSAcceptedHistoryWireCodec.isWithinEncodedLimit(envelope) {
                return entries
            }
            guard !entries.isEmpty else {
                throw IOSAcceptedHistoryError.writeFailed
            }
            entries.removeLast()
        }
    }

    private func trimMutationToEncodedLimit(
        _ source: [IOSAcceptedHistoryEntry],
        provisionalRevision: Int64,
        current: IOSAcceptedHistoryEnvelope
    ) throws -> [IOSAcceptedHistoryEntry] {
        var entries = source
        while true {
            if entries == current.entries {
                guard try IOSAcceptedHistoryWireCodec
                    .isWithinEncodedLimit(current) else {
                    throw IOSAcceptedHistoryError.invalidRecord
                }
                return entries
            }
            let envelope = try IOSAcceptedHistoryEnvelope(
                revision: provisionalRevision,
                entries: entries
            )
            if try IOSAcceptedHistoryWireCodec.isWithinEncodedLimit(envelope) {
                return entries
            }
            guard !entries.isEmpty else {
                throw IOSAcceptedHistoryError.writeFailed
            }
            entries.removeLast()
        }
    }

    private func exactMembership(
        of candidate: IOSAcceptedHistoryCandidate,
        in envelope: IOSAcceptedHistoryEnvelope
    ) throws -> IOSAcceptedHistoryEntry {
        if let row = envelope.entries.first(where: {
            $0.deliveryID == candidate.entry.deliveryID
        }) {
            guard row.hasSameImmutableBytes(as: candidate.entry) else {
                throw IOSAcceptedHistoryError.collision
            }
            return row
        }
        if envelope.entries.contains(where: {
            $0.transcriptID == candidate.entry.transcriptID
        }) {
            throw IOSAcceptedHistoryError.collision
        }
        throw IOSAcceptedHistoryError.compareAndSwapFailed
    }

    private func retainedEntry(
        _ candidate: IOSAcceptedHistoryCandidate,
        in entries: [IOSAcceptedHistoryEntry]
    ) -> IOSAcceptedHistoryEntry? {
        entries.first {
            $0.deliveryID == candidate.entry.deliveryID
                && $0.hasSameImmutableBytes(as: candidate.entry)
        }
    }

    private func publish(
        _ outcome: Outcome,
        source: Source,
        candidate: IOSAcceptedHistoryCandidate
    ) throws -> IOSAcceptedHistoryRowReceipt {
        let intent = UncertainIntent(
            source: source,
            candidate: candidate,
            outcome: outcome
        )
        do {
            let snapshot: IOSAcceptedHistoryJournalSnapshot = switch source {
            case .missing:
                try journal.create(
                    outcome.envelope,
                    authorization:
                        IOSAcceptedHistoryJournalMutationAuthorization()
                )
            case .existing(let current):
                try journal.replace(
                    outcome.envelope,
                    expected: current,
                    authorization:
                        IOSAcceptedHistoryJournalMutationAuthorization()
                )
            }
            uncertainIntent = nil
            return IOSAcceptedHistoryRowReceipt(
                candidate: candidate,
                snapshot: snapshot,
                retainedEntry: outcome.retainedEntry
            )
        } catch IOSAcceptedHistoryError.commitUncertain {
            uncertainIntent = intent
            throw IOSAcceptedHistoryError.commitUncertain
        }
    }

    private func reconcile(
        _ intent: UncertainIntent,
        candidate: IOSAcceptedHistoryCandidate,
        current: IOSAcceptedHistoryJournalSnapshot?
    ) throws -> IOSAcceptedHistoryRowReceipt {
        guard candidate == intent.candidate else {
            throw IOSAcceptedHistoryError.commitUncertain
        }

        switch (intent.source, current) {
        case (.missing, .none):
            return try publish(
                intent.outcome,
                source: .missing,
                candidate: candidate
            )
        case (.existing(let source), .some(let current))
            where source == current:
            return try publish(
                intent.outcome,
                source: .existing(current),
                candidate: candidate
            )
        case (_, .some(let current))
            where current.envelope == intent.outcome.envelope:
            return try publish(
                intent.outcome,
                source: .existing(current),
                candidate: candidate
            )
        default:
            uncertainIntent = nil
            throw IOSAcceptedHistoryError.compareAndSwapFailed
        }
    }
}
