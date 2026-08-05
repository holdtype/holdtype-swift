//
//  TranscriptHistoryBulkClearSummary.swift
//  HoldType
//

import Foundation

struct TranscriptHistoryBulkClearSummary: Equatable {
    let acceptedTranscriptCount: Int
    let deletableSavedRecordingCount: Int
    let processingSavedRecordingCount: Int

    init(
        acceptedTranscriptCount: Int,
        savedRecordings: [FailedTranscriptionAttempt]
    ) {
        self.acceptedTranscriptCount = acceptedTranscriptCount
        deletableSavedRecordingCount = savedRecordings.filter(\.canDelete).count
        processingSavedRecordingCount = savedRecordings.filter { !$0.canDelete }.count
    }

    var canClear: Bool {
        acceptedTranscriptCount > 0 || deletableSavedRecordingCount > 0
    }

    var confirmationMessage: String {
        let acceptedTranscriptNoun = acceptedTranscriptCount == 1
            ? "transcript"
            : "transcripts"
        let savedRecordingNoun = deletableSavedRecordingCount == 1
            ? "recording"
            : "recordings"
        var parts = [
            "This will delete \(acceptedTranscriptCount) accepted \(acceptedTranscriptNoun)",
            "\(deletableSavedRecordingCount) saved \(savedRecordingNoun), including their recovery audio."
        ]

        if processingSavedRecordingCount > 0 {
            let processingDescription = processingSavedRecordingCount == 1
                ? "recording is"
                : "recordings are"
            parts.append(
                "\(processingSavedRecordingCount) \(processingDescription) still processing and will be kept."
            )
        }

        return parts.joined(separator: " ")
    }
}

struct SavedRecordingBulkDeletionResult: Equatable {
    let deletedCount: Int
    let keptCount: Int
}
