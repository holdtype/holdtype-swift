import Foundation

nonisolated enum KeyboardFixCancellationPhase:
    String,
    Codable,
    Sendable {
    case requested
    case acknowledged
}

/// Payload-free, identity-bound cancellation handshake. The extension keeps
/// the cancelled request active until the containing app acknowledges cleanup
/// or this marker expires.
nonisolated struct KeyboardFixCancellationRecord:
    Codable,
    Equatable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let requestID: UUID
    let issuedAt: Date
    let expiresAt: Date
    let phase: KeyboardFixCancellationPhase
    let acknowledgedAt: Date?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case requestID
        case issuedAt
        case expiresAt
        case phase
        case acknowledgedAt
    }

    init?(
        requestID: UUID,
        issuedAt: Date,
        expiresAt: Date
    ) {
        guard KeyboardFixBridgeValidation.hasValidLifetime(
            issuedAt: issuedAt,
            expiresAt: expiresAt
        ) else {
            return nil
        }
        schemaVersion = Self.schemaVersion
        self.requestID = requestID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        phase = .requested
        acknowledgedAt = nil
    }

    func acknowledging(at date: Date) -> Self? {
        guard phase == .requested,
              isValid(at: date)
        else {
            return nil
        }
        return Self(
            schemaVersion: schemaVersion,
            requestID: requestID,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            phase: .acknowledged,
            acknowledgedAt: date
        )
    }

    func isValid(at date: Date) -> Bool {
        guard schemaVersion == Self.schemaVersion,
              issuedAt <= date,
              expiresAt > date,
              KeyboardFixBridgeValidation.hasValidLifetime(
                  issuedAt: issuedAt,
                  expiresAt: expiresAt
              )
        else {
            return false
        }
        return switch phase {
        case .requested:
            acknowledgedAt == nil
        case .acknowledged:
            acknowledgedAt.map {
                $0 >= issuedAt && $0 < expiresAt
            } ?? false
        }
    }

    var description: String {
        "KeyboardFixCancellationRecord(phase: \(phase.rawValue))"
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "phase": phase.rawValue,
                "payload": "<none>",
            ]
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(phase, forKey: .phase)
        if let acknowledgedAt {
            try container.encode(
                acknowledgedAt,
                forKey: .acknowledgedAt
            )
        } else {
            try container.encodeNil(forKey: .acknowledgedAt)
        }
    }

    init(from decoder: Decoder) throws {
        try KeyboardFixBridgeStrictDecoding.requireExactKeys(
            Set(CodingKeys.allCases.map(\.stringValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(
            Int.self,
            forKey: .schemaVersion
        )
        let requestID = try container.decode(
            UUID.self,
            forKey: .requestID
        )
        let issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        let expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        let phase = try container.decode(
            KeyboardFixCancellationPhase.self,
            forKey: .phase
        )
        let acknowledgedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .acknowledgedAt
        )
        guard schemaVersion == Self.schemaVersion,
              KeyboardFixBridgeValidation.hasValidLifetime(
                  issuedAt: issuedAt,
                  expiresAt: expiresAt
              ),
              Self.hasValidPhase(
                  phase,
                  acknowledgedAt: acknowledgedAt,
                  issuedAt: issuedAt,
                  expiresAt: expiresAt
              )
        else {
            throw KeyboardFixBridgeStrictDecoding.invalidRecord(from: decoder)
        }
        self.init(
            schemaVersion: schemaVersion,
            requestID: requestID,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            phase: phase,
            acknowledgedAt: acknowledgedAt
        )
    }

    private init(
        schemaVersion: Int,
        requestID: UUID,
        issuedAt: Date,
        expiresAt: Date,
        phase: KeyboardFixCancellationPhase,
        acknowledgedAt: Date?
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.phase = phase
        self.acknowledgedAt = acknowledgedAt
    }

    private static func hasValidPhase(
        _ phase: KeyboardFixCancellationPhase,
        acknowledgedAt: Date?,
        issuedAt: Date,
        expiresAt: Date
    ) -> Bool {
        switch phase {
        case .requested:
            acknowledgedAt == nil
        case .acknowledged:
            acknowledgedAt.map {
                $0 >= issuedAt && $0 < expiresAt
            } ?? false
        }
    }
}
