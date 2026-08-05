enum FailedTranscriptionRetryOutputMode: Equatable {
    case saveOnly
    case followAutomaticInsertion
}

enum FailedTranscriptionRetryAuthorization: Equatable {
    case ordinary
    case confirmedDuplicateSubmission
}
