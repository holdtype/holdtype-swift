import CoreFoundation
import Foundation

enum IOSV1ProviderConsentDecision: String, Equatable, Sendable {
    case accepted
    case withdrawn
}

struct IOSV1ProviderConsentRecord: Equatable, Sendable {
    let revision: Int64
    let disclosureVersion: Int64
    let decision: IOSV1ProviderConsentDecision
    let decisionAtMilliseconds: Int64
}

enum IOSV1ProviderConsentSource: Equatable, Sendable {
    case missing
    case record(IOSV1ProviderConsentRecord, Data)
    case unreadable(Data)
    case unavailable

    var acceptedCurrentDisclosure: Bool {
        guard case .record(let record, _) = self else { return false }
        return record.decision == .accepted
            && record.disclosureVersion
                == IOSV1ProviderConsentCoordinator.currentDisclosureVersion
    }
}

enum IOSV1ProviderConsentWireCodec {
    private static let keys: Set<String> = [
        "schemaVersion",
        "revision",
        "disclosureVersion",
        "decision",
        "decisionAtMilliseconds",
    ]

    static func decode(_ data: Data) -> IOSV1ProviderConsentRecord? {
        do {
            try BoundedJSONMemberValidator.validate(
                data,
                limits: .metadataFile(maximumInputByteCount: 4_096)
            )
            guard let object = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                  Set(object.keys) == keys,
                  integer(object["schemaVersion"]) == 1,
                  let revision = integer(object["revision"]),
                  revision > 0,
                  let disclosureVersion = integer(object["disclosureVersion"]),
                  disclosureVersion > 0,
                  let rawDecision = object["decision"] as? String,
                  let decision = IOSV1ProviderConsentDecision(rawValue: rawDecision),
                  let decisionAt = integer(object["decisionAtMilliseconds"])
            else {
                return nil
            }
            return IOSV1ProviderConsentRecord(
                revision: revision,
                disclosureVersion: disclosureVersion,
                decision: decision,
                decisionAtMilliseconds: decisionAt
            )
        } catch {
            return nil
        }
    }

    static func encode(_ record: IOSV1ProviderConsentRecord) throws -> Data {
        let object: [String: Any] = [
            "schemaVersion": 1,
            "revision": record.revision,
            "disclosureVersion": record.disclosureVersion,
            "decision": record.decision.rawValue,
            "decisionAtMilliseconds": record.decisionAtMilliseconds,
        ]
        guard JSONSerialization.isValidJSONObject(object) else {
            throw IOSV1ProviderConsentError.mutationNotSaved
        }
        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    }

    static func canonicalMilliseconds(_ date: Date) throws -> Int64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds >= Double(Int64.min),
              milliseconds <= Double(Int64.max) else {
            throw IOSV1ProviderConsentError.mutationNotSaved
        }
        return Int64(milliseconds.rounded())
    }

    private static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let integer = number.int64Value
        guard number.stringValue == String(integer) else { return nil }
        return integer
    }
}

actor IOSV1ProviderConsentRepository {
    private static let policy = ProtectedAtomicMetadataFilePolicy(
        maximumByteCount: 4_096,
        fileProtection: .complete,
        excludesFromBackup: false
    )

    private let fileURL: URL
    private let fileSystem: any ProtectedAtomicMetadataFileSystem

    init(
        fileURL: URL,
        fileSystem: any ProtectedAtomicMetadataFileSystem =
            FoundationProtectedAtomicMetadataFileSystem()
    ) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
    }

    func observe() -> IOSV1ProviderConsentSource {
        load()
    }

    func accept(
        expected: IOSV1ProviderConsentSource,
        decisionAt: Date
    ) throws -> IOSV1ProviderConsentSource {
        let current = try requireCurrent(expected)
        if case .unreadable = current {
            throw IOSV1ProviderConsentError.unreadableDataRequiresReset
        }
        if case .record(let record, _) = current,
           record.decision == .accepted,
           record.disclosureVersion
            == IOSV1ProviderConsentCoordinator.currentDisclosureVersion {
            return current
        }
        let record = try successor(
            of: current,
            decision: .accepted,
            decisionAt: decisionAt
        )
        return try replace(with: record)
    }

    func withdraw(
        expected: IOSV1ProviderConsentSource,
        decisionAt: Date
    ) throws -> IOSV1ProviderConsentSource {
        let current = try requireCurrent(expected)
        if case .unreadable = current {
            throw IOSV1ProviderConsentError.unreadableDataRequiresReset
        }
        if case .record(let record, _) = current,
           record.decision == .withdrawn {
            return current
        }
        let record = try successor(
            of: current,
            decision: .withdrawn,
            decisionAt: decisionAt
        )
        return try replace(with: record)
    }

    func resetUnreadable(
        expected: IOSV1ProviderConsentSource
    ) throws -> IOSV1ProviderConsentSource {
        let current = try requireCurrent(expected)
        guard case .unreadable = current else {
            throw IOSV1ProviderConsentError.resetRequiresUnreadableObservation
        }
        do {
            try fileSystem.removeFileIfPresent(at: fileURL)
            return .missing
        } catch {
            throw IOSV1ProviderConsentError.mutationNotSaved
        }
    }

    private func load() -> IOSV1ProviderConsentSource {
        do {
            guard let data = try fileSystem.readFileIfPresent(
                at: fileURL,
                policy: Self.policy
            ) else {
                return .missing
            }
            guard let record = IOSV1ProviderConsentWireCodec.decode(data) else {
                return .unreadable(data)
            }
            return .record(record, data)
        } catch {
            return .unavailable
        }
    }

    private func requireCurrent(
        _ expected: IOSV1ProviderConsentSource
    ) throws -> IOSV1ProviderConsentSource {
        let current = load()
        guard current != .unavailable else {
            throw IOSV1ProviderConsentError.localDataUnavailable
        }
        guard current == expected else {
            throw IOSV1ProviderConsentError.staleObservation
        }
        return current
    }

    private func successor(
        of source: IOSV1ProviderConsentSource,
        decision: IOSV1ProviderConsentDecision,
        decisionAt: Date
    ) throws -> IOSV1ProviderConsentRecord {
        let revision: Int64
        switch source {
        case .missing:
            revision = 1
        case .record(let record, _):
            guard record.revision < Int64.max else {
                throw IOSV1ProviderConsentError.revisionOverflow
            }
            revision = record.revision + 1
        case .unreadable:
            throw IOSV1ProviderConsentError.unreadableDataRequiresReset
        case .unavailable:
            throw IOSV1ProviderConsentError.localDataUnavailable
        }
        return IOSV1ProviderConsentRecord(
            revision: revision,
            disclosureVersion:
                IOSV1ProviderConsentCoordinator.currentDisclosureVersion,
            decision: decision,
            decisionAtMilliseconds:
                try IOSV1ProviderConsentWireCodec.canonicalMilliseconds(
                    decisionAt
                )
        )
    }

    private func replace(
        with record: IOSV1ProviderConsentRecord
    ) throws -> IOSV1ProviderConsentSource {
        do {
            let data = try IOSV1ProviderConsentWireCodec.encode(record)
            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: data,
                policy: Self.policy
            )
            return .record(record, data)
        } catch let error as IOSV1ProviderConsentError {
            throw error
        } catch {
            throw IOSV1ProviderConsentError.mutationNotSaved
        }
    }
}
