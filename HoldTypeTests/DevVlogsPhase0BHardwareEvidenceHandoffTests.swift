#if DEBUG
import Foundation
import Testing
@testable import HoldType

struct DevVlogsPhase0BHardwareEvidenceHandoffTests {
    @Test func productionHandoffAcceptsOneValidStreamAndRejectsEveryInvalidShape() throws {
        let valid = try runScenario("valid")
        #expect(valid.status == 0)
        #expect(valid.output.contains("hardware_evidence_handoff=validated"))
        #expect(valid.output.contains("category=video_preservation_failed"))
        #expect(valid.output.contains("preservation_error=encoded_payload_mismatch"))
        #expect(valid.output.contains("hardware_evidence_test=pass raw_cleanup=pending"))

        let invalid = [
            "zero", "multiple", "symlink", "hardlink", "malformed", "wrong_case",
            "missing_start", "missing_terminal", "duplicate_terminal", "ready_plus_failure",
            "oversize", "unexpected_schema", "unexpected_event", "private_data",
        ]
        for scenario in invalid {
            let result = try runScenario(scenario)
            #expect(result.status != 0, "Expected \(scenario) to fail closed")
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            #expect(!result.output.contains("hardware_evidence_test=pass"))
        }
    }

    @Test func scriptContractIsExplicitIsolatedBoundedAndCopiesBeforeCleanup() throws {
        let source = try String(contentsOf: scriptURL, encoding: .utf8)
        let start = try #require(source.range(of: "prepare_hardware_evidence_handoff\n"))
        let hardware = source[start.lowerBound...]
        let validate = try #require(hardware.range(of: "validate_and_handoff_hardware_evidence"))
        let cleanupClaim = try #require(hardware.range(of: "raw_media_cleanup=scheduled"))
        #expect(validate.lowerBound < cleanupClaim.lowerBound)
        #expect(hardware.contains("HOLDTYPE_DEV_VLOGS_PHASE_0B_EVENT_LOG=\"$hardware_event_source\""))
        #expect(source.contains("--signal=TERM --kill-after=1s 5s"))
        #expect(source.contains("hardware_timeout_seconds=$(( capture_duration + 300 ))"))
        #expect(!source.contains("capture_duration + 360"))
        #expect(source.contains("capture_supervisor_pid=$!"))
        #expect(source.contains("terminate_capture_supervisor"))
        #expect(!source.contains("killall"))
        let testHook = try #require(source.range(
            of: "if [[ \"$mode\" == \"--hardware\" && -n " +
                "\"${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST:-}\" ]]"
        ))
        let permissionHook = try #require(source.range(
            of: "if [[ \"$mode\" == \"--request-camera-permission\" ]]; then",
            range: testHook.upperBound..<source.endIndex
        ))
        #expect(testHook.lowerBound < permissionHook.lowerBound)
    }

    private func runScenario(_ scenario: String) throws -> (status: Int32, output: String) {
        let outerRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "dv-p0b-handoff-tests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: outerRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outerRoot) }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path, "--hardware", "--camera-id", "fake-camera",
            "--case-id", "handoff-test",
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["TMPDIR"] = outerRoot.path + "/"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST"] = scenario
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, output)
    }

    private var scriptURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh")
    }
}
#endif
