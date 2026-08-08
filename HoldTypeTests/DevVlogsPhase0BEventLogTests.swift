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
                result: .failed,
                category: .cameraSelectionBusy,
                deviceClass: .continuity,
                redactedDeviceLabel: "continuity_camera",
                metrics: [
                    .init(name: "video_duration", value: 10, unit: "s", disposition: "evidence_only"),
                ],
                videoEvidence: .init(
                    cameraMediaSubtype: "hvc1",
                    finalizedMediaSubtype: "hvc1",
                    finalizedAudioMediaSubtype: "aac ",
                    cameraFormat: "hvc1:1920x1080:descriptions_1",
                    finalizedFormat: "hvc1:1920x1080:descriptions_1",
                    preservationMethod: "stored_sample_exact_v1",
                    preservedSampleCount: 600,
                    preservedEncodedByteCount: 4_000_000,
                    matched: true
                )
            )
        )

        let payload = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(payload.hasSuffix("\n"))
        #expect(payload.contains("continuity_camera"))
        #expect(payload.contains("camera_selection_busy"))
        #expect(payload.contains("stored_sample_exact_v1"))
        #expect(payload.contains("hvc1"))
        #expect(!payload.contains("digest"))
        #expect(!payload.contains(directory.path))
        #expect(!payload.contains("sensitive-device-id"))
        #expect(!payload.contains("NSError"))
        #expect(!payload.contains("userInfo"))
    }
}
#endif
