import Foundation
import HoldTypeDomain

/// Prepared metadata has no audio content. The async write must complete before
/// the recorder receives the lease; cancellation never abandons an in-flight write.
nonisolated enum RecordingCapturePreparation {
    static func persist(_ lease: RecordingCaptureLease, in directory: URL, prepareDirectory: Bool, fileManager manager: FileManager = .default) throws {
        DictationStartTiming.mark("journal_begin")
        defer { DictationStartTiming.mark("journal_end") }
        if prepareDirectory || !manager.fileExists(atPath: directory.path) {
            do { try manager.createDirectory(at: directory, withIntermediateDirectories: true) }
            catch { throw RecordingCaptureJournalError.directoryUnavailable }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = directory
            try? url.setResourceValues(values)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(PersistedRecordingCapture(lease))
        let marker = directory.appendingPathComponent(".HoldType-Capture-\(lease.id.uuidString.lowercased()).json")
        do { try data.write(to: marker, options: .atomic) }
        catch { throw RecordingCaptureJournalError.journalWriteFailed }
    }

}
