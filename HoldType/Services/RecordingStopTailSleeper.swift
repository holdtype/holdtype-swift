import Foundation

protocol RecordingStopTailSleeping {
    func sleep(seconds: TimeInterval) async throws
}

struct TaskRecordingStopTailSleeper: RecordingStopTailSleeping {
    func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
