import Foundation

struct TranscriptHistoryGroup: Identifiable {
    let day: Date
    let title: String
    let rows: [TranscriptHistoryRow]

    var id: Date { day }
}

enum TranscriptHistoryRow: Identifiable {
    case transcript(TranscriptHistoryEntry)
    case failed(FailedTranscriptionAttempt)

    var id: String {
        switch self {
        case .transcript(let entry):
            return "transcript-\(entry.id.uuidString)"
        case .failed(let attempt):
            return "failed-\(attempt.id.uuidString)"
        }
    }

    var createdAt: Date {
        switch self {
        case .transcript(let entry):
            return entry.createdAt
        case .failed(let attempt):
            return attempt.updatedAt
        }
    }
}
