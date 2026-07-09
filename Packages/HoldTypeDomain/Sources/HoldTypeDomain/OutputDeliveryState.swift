public enum InsertionAttemptOutcome: String, Codable, Equatable, Sendable {
    case confirmedInserted = "confirmedInserted"
    case submittedUnverified = "submittedUnverified"
}

/// Observer-scoped delivery state, separate from acknowledgement transport and persistence.
public enum OutputDeliveryState: Equatable, Sendable {
    case pending
    case automaticallyEligible
    case explicitActionRequired
    case insertionOutcome(InsertionAttemptOutcome)
    case recoverablePreAttemptFailure
    case expired
}
