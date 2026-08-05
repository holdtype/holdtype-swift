//
//  TranscriptionFailureRecoveryStore+BulkDeletion.swift
//  HoldType
//

import Foundation

extension TranscriptionFailureRecoveryStore {
    func removeAllDeletableAttempts() -> SavedRecordingBulkDeletionResult {
        let deletableAttemptIDs = failedAttempts
            .filter(\.canDelete)
            .map(\.id)
        var deletedCount = 0
        var keptCount = 0

        for id in deletableAttemptIDs {
            do {
                if try removeFailedAttempt(id: id) {
                    deletedCount += 1
                } else {
                    keptCount += 1
                }
            } catch {
                keptCount += 1
            }
        }

        return SavedRecordingBulkDeletionResult(
            deletedCount: deletedCount,
            keptCount: keptCount
        )
    }
}
