#if DEBUG
import CryptoKit
import Darwin
import Foundation
import Testing
@testable import HoldType

struct DevVlogsPhase0BHardwareEvidenceHandoffTests {
    @Test func retainedSnapshotSurvivesRawCleanupAndIsExactlyConsumable() throws {
        let result = try runScenario("valid")
        defer { remove(result.outerRoot) }
        #expect(result.status == 0)
        #expect(result.output.contains("hardware_evidence_handoff=validated"))
        #expect(result.output.contains("cleanup=runtime_owner_exact_root"))

        let token = try #require(rootToken(in: result.output))
        #expect(token.range(of: #"^holdtype-dv-p0b-handoff\.[A-Za-z0-9]{6,32}$"#,
                            options: .regularExpression) != nil)
        let retainedRoot = result.outerRoot.appendingPathComponent(token, isDirectory: true)
        let snapshot = retainedRoot.appendingPathComponent("events.jsonl")
        let remaining = try FileManager.default.contentsOfDirectory(
            at: result.outerRoot, includingPropertiesForKeys: nil
        )
        #expect(remaining.filter {
            $0.lastPathComponent.hasPrefix("holdtype-dv-p0b.")
        }.isEmpty)
        var value = stat()
        #expect(lstat(snapshot.path, &value) == 0)
        #expect(value.st_nlink == 1)
        #expect(value.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG))
        #expect(value.st_mode & 0o777 == 0o400)

        let data = try Data(contentsOf: snapshot)
        #expect(Array(SHA256.hash(data: data)).count == 32)
        let lines = data.split(separator: 0x0A)
        #expect(lines.count == 2)
        let objects = try lines.map {
            try #require(JSONSerialization.jsonObject(with: Data($0)) as? [String: Any])
        }
        #expect(objects[0]["result"] as? String == "started")
        #expect(objects[1]["result"] as? String == "failed")
        #expect(objects[1]["preservation_failure_dimension"] as? String ==
                "encoded_payload_mismatch")

        try FileManager.default.removeItem(at: retainedRoot)
        #expect(!FileManager.default.fileExists(atPath: retainedRoot.path))

        let ready = try runScenario("valid_ready")
        defer { remove(ready.outerRoot) }
        #expect(ready.status == 0)
        let readyToken = try #require(rootToken(in: ready.output))
        let readyRoot = ready.outerRoot.appendingPathComponent(readyToken, isDirectory: true)
        let readyData = try Data(contentsOf: readyRoot.appendingPathComponent("events.jsonl"))
        let readyTerminal = try #require(JSONSerialization.jsonObject(
            with: Data(readyData.split(separator: 0x0A)[1])
        ) as? [String: Any])
        #expect(readyTerminal["result"] as? String == "ready")
        #expect((readyTerminal["videoEvidence"] as? [String: Any])?["matched"] as? Bool == true)
        try FileManager.default.removeItem(at: readyRoot)

        let cancelled = try runScenario("valid_cancelled")
        defer { remove(cancelled.outerRoot) }
        #expect(cancelled.status == 0)
        #expect(cancelled.output.contains("result=cancelled category=capture_stop"))
        let cancelledToken = try #require(rootToken(in: cancelled.output))
        try FileManager.default.removeItem(
            at: cancelled.outerRoot.appendingPathComponent(cancelledToken, isDirectory: true)
        )
    }

    @Test func productionRouteRejectsOwnershipRaceAndSchemaMatrix() throws {
        let invalid = [
            "zero", "multiple", "add_after_list", "remove_after_list", "source_replacement",
            "source_parent_swap", "raw_root_swap", "destination_parent_swap", "wrong_owner",
            "symlink", "source_ancestor_symlink", "destination_ancestor_symlink", "hardlink",
            "wrong_source_mode", "wrong_source_type", "wrong_source_parent_mode",
            "wrong_destination_mode", "destination_collision", "malformed", "oversize",
            "duplicate_top", "duplicate_nested", "unexpected_schema", "extra_nested",
            "missing_stage_key", "false_stage", "wrong_case", "wrong_ids", "wrong_order",
            "missing_start", "missing_terminal", "duplicate_terminal", "ready_plus_failure",
            "unexpected_event", "arbitrary_category", "arbitrary_dimension",
            "wrong_result_dimension", "arbitrary_device", "identifier_too_long", "private_data",
            "nonfinite_metric", "out_of_range_metric", "unexpected_metric", "wrong_unit",
            "wrong_disposition", "wrong_metric_value", "duplicate_metric",
            "missing_required_metric", "ready_extra_video_key", "ready_count_mismatch",
            "ready_unmatched", "ready_wrong_method", "ready_bad_device_label",
            "ready_bad_device_class",
        ]
        for scenario in invalid {
            let result = try runScenario(scenario)
            #expect(result.status != 0, "Expected \(scenario) to fail closed")
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            #expect(!result.output.contains("hardware_evidence_test=pass"))
            #expect(result.output.contains("cleanup=runtime_owner_exact_root"))
            #expect(!result.output.contains("/Users/"))
            #expect(!result.output.contains(result.outerRoot.path))
            remove(result.outerRoot)
        }
    }

    @Test func deadlineAndSignalTrapsRetainNoValidatedSnapshot() throws {
        let timeout = try runScenario("slow_validator")
        defer { remove(timeout.outerRoot) }
        #expect(timeout.status != 0)
        #expect(!timeout.output.contains("hardware_evidence_handoff=validated"))

        for signal in [SIGTERM, SIGINT] {
            let result = try run(
                arguments: ["--hardware", "--camera-id", "fake-camera", "--case-id", "handoff-test"],
                scenario: "slow_validator", timeout: 8, signalAfterLaunch: signal
            )
            #expect(result.status != 0)
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            remove(result.outerRoot)
        }
    }

    @Test func hookIsHardwareOnlyAndEveryProcessWaitIsBounded() throws {
        for arguments in [["--help"], ["--unknown"], ["--hardware"],
                          ["--request-camera-permission", "--build-only"]] {
            let ordinary = try run(arguments: arguments, scenario: nil, timeout: 8)
            defer { remove(ordinary.outerRoot) }
            let hooked = try run(arguments: arguments, scenario: "valid", timeout: 8)
            defer { remove(hooked.outerRoot) }
            #expect(hooked.status == ordinary.status)
            #expect(hooked.output == ordinary.output)
            #expect(!hooked.output.contains("hardware_evidence_handoff"))
        }
    }

    @Test func scriptContractPinsAncestryAndRetainsOutsideRawRoot() throws {
        let source = try String(contentsOf: scriptURL, encoding: .utf8)
        #expect(source.contains("walk_absolute"))
        #expect(source.contains("os.O_NOFOLLOW"))
        #expect(source.contains("object_pairs_hook=unique_object"))
        #expect(source.contains("parse_constant=lambda _: fail()"))
        #expect(source.contains("holdtype-dv-p0b-handoff.XXXXXX"))
        #expect(source.contains("cleanup=runtime_owner_exact_root"))
        #expect(source.contains("hardware_timeout_seconds=$(( capture_duration + 300 ))"))
        #expect(!source.contains("capture_duration + 360"))
        #expect(!source.contains("waitUntilExit"))
        #expect(!source.contains("killall"))
        let prepare = try #require(source.range(of: "prepare_hardware_evidence_handoff\n"))
        let launch = try #require(source.range(of: "HOLDTYPE_DEV_VLOGS_PHASE_0B_EVENT_LOG="))
        let validate = try #require(source.range(of: "validate_and_handoff_hardware_evidence ||"))
        let cleanup = try #require(source.range(of: "raw_media_cleanup=scheduled"))
        #expect(prepare.lowerBound < launch.lowerBound)
        #expect(launch.lowerBound < validate.lowerBound)
        #expect(validate.lowerBound < cleanup.lowerBound)
    }

    private func runScenario(_ scenario: String) throws -> ScriptResult {
        try run(
            arguments: ["--hardware", "--camera-id", "fake-camera", "--case-id", "handoff-test"],
            scenario: scenario,
            timeout: 8
        )
    }

    private func run(
        arguments: [String], scenario: String?, timeout: TimeInterval,
        signalAfterLaunch: Int32? = nil
    ) throws -> ScriptResult {
        let outerRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "dv-p0b-handoff-tests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: outerRoot, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let outputURL = outerRoot.appendingPathComponent("process-output")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["TMPDIR"] = outerRoot.path + "/"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let scenario {
            environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST"] = scenario
        }
        process.environment = environment
        process.currentDirectoryURL = repositoryRoot
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        try process.run()
        if let signalAfterLaunch {
            Thread.sleep(forTimeInterval: 0.25)
            kill(process.processIdentifier, signalAfterLaunch)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            process.terminate()
            let termDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < termDeadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            let killDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < killDeadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        try outputHandle.close()
        guard !process.isRunning else {
            remove(outerRoot)
            throw HandoffTestError.processDidNotExit
        }
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        try FileManager.default.removeItem(at: outputURL)
        return ScriptResult(status: process.terminationStatus, output: output, outerRoot: outerRoot)
    }

    private func rootToken(in output: String) -> String? {
        output.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            .first { $0.hasPrefix("root_token=") }?.dropFirst("root_token=".count)
            .description
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private var scriptURL: URL {
        repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh")
    }
}

private struct ScriptResult {
    let status: Int32
    let output: String
    let outerRoot: URL
}

private enum HandoffTestError: Error {
    case processDidNotExit
}
#endif
