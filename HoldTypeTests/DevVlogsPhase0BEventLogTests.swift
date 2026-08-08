#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BEventLogTests {
    @Test func jsonlContainsOnlyCompactRedactedFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("events.jsonl")
        let log = DevVlogsPhase0BJSONLEventLog(fileURL: fileURL)

        try log.record(
            DevVlogsPhase0BEvent(
                runID: "run-1",
                caseID: "fake",
                attemptID: "attempt-1",
                monotonicMilliseconds: 1_250,
                action: "attempt_terminal",
                result: .ready,
                deviceClass: .continuity,
                redactedDeviceLabel: "continuity_camera",
                metrics: [
                    .init(name: "video_duration", value: 10, unit: "s", disposition: "evidence_only"),
                ]
            )
        )

        let payload = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(payload.hasSuffix("\n"))
        #expect(payload.contains("continuity_camera"))
        #expect(!payload.contains(directory.path))
        #expect(!payload.contains("sensitive-device-id"))
        #expect(!payload.contains("NSError"))
        #expect(!payload.contains("userInfo"))
    }
}
#endif
