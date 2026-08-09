#if DEBUG
import CryptoKit
import Darwin
import Foundation
import Testing
@testable import HoldType

struct DevVlogsPhase0BHardwareEvidenceHandoffTests {
    @Test func retainedSnapshotSurvivesRawCleanupAndConsumerUsesItExactlyOnce() throws {
        for scenario in [
            "valid", "valid_ready", "valid_cancelled",
            "valid_preservation_cancelled", "valid_preservation_timed_out",
        ] {
            let result = try runScenario(scenario)
            defer { remove(result.outerRoot) }
            #expect(result.status == 0)
            #expect(result.output.contains("hardware_evidence_handoff=validated"))
            #expect(result.output.contains("cleanup=trusted_debug_consumer_once"))

            let authority = try authority(in: result.output)
            let retainedRoot = result.outerRoot.appendingPathComponent(
                authority.rootToken, isDirectory: true
            )
            let snapshot = retainedRoot.appendingPathComponent("events.jsonl")
            #expect(rawRoots(in: result.outerRoot).isEmpty)
            try assertSnapshot(snapshot, authority: authority)

            let consumed = try runConsumer(authority, in: result.outerRoot)
            #expect(consumed.status == 0)
            #expect(consumed.output.contains("hardware_evidence_consumer=consumed"))
            #expect(consumed.output.contains("cleanup=trusted_debug_exact_path"))
            #expect(!FileManager.default.fileExists(atPath: retainedRoot.path))

            let duplicate = try runConsumer(authority, in: result.outerRoot)
            #expect(duplicate.status != 0)
            #expect(!duplicate.output.contains("hardware_evidence_consumer=consumed"))
        }
    }

    @Test func everyProtectedOrdinaryFailureFormPublishesAndConsumes() throws {
        let categories = [
            "audio_start", "camera_permission_required", "camera_permission_denied",
            "camera_selection_disconnected", "camera_start_device_unavailable",
            "camera_selection_busy", "camera_configuration_video_input",
            "camera_configuration_movie_output", "camera_configuration_sample_output",
            "camera_start_timed_out", "camera_first_frame_unavailable",
            "camera_recording_failed", "camera_interruption_disconnected",
            "camera_session_runtime_failure", "camera_session_not_capturing", "camera_unknown",
            "capture_stop", "camera_probe", "passthrough_incompatible",
            "passthrough_export_failed", "finalization", "final_probe",
        ]
        for category in categories {
            let result = try runScenario("valid_failure_\(category)")
            defer { remove(result.outerRoot) }
            #expect(result.status == 0, "Expected \(category) to pass")
            #expect(result.output.contains("result=failed category=\(category)"))
            let authority = try authority(in: result.output)
            #expect(try runConsumer(authority, in: result.outerRoot).status == 0)
        }
    }

    @Test func productionRouteRejectsOwnershipMutationSchemaAndPrivateDataMatrix() throws {
        let invalid = [
            "zero", "multiple", "add_after_list", "remove_after_list", "source_replacement",
            "same_size_mutation", "source_parent_swap", "raw_root_swap",
            "destination_parent_swap", "wrong_owner", "symlink", "source_ancestor_symlink",
            "destination_ancestor_symlink", "hardlink", "wrong_source_mode",
            "wrong_source_type", "wrong_source_parent_mode", "wrong_destination_mode",
            "destination_collision", "malformed", "oversize", "duplicate_top",
            "duplicate_nested", "unexpected_schema", "extra_nested", "missing_stage_key",
            "false_stage", "wrong_case", "wrong_ids", "invalid_run_id", "invalid_attempt_id",
            "wrong_order", "missing_start", "missing_terminal", "duplicate_terminal",
            "ready_plus_failure", "unexpected_event", "arbitrary_category",
            "impossible_failure_category", "arbitrary_dimension", "wrong_result_dimension",
            "arbitrary_device", "identifier_too_long", "private_data", "private_subtype",
            "nonfinite_metric", "out_of_range_metric", "unexpected_metric", "wrong_unit",
            "wrong_disposition", "wrong_metric_value", "duplicate_metric",
            "missing_required_metric", "preservation_extra_duration", "backward_timestamp",
            "ready_extra_video_key", "ready_count_mismatch", "ready_unmatched",
            "ready_wrong_method", "ready_bad_device_label", "ready_bad_device_class",
            "ready_missing_audio_duration", "ready_missing_video_metric", "ready_missing_fps",
            "ready_impossible_audio_metric", "ready_with_failure_category",
            "ordinary_failure_metrics", "ordinary_failure_device", "published_digest_mismatch",
            "published_identity_mismatch", "failed_output_replacement",
        ]
        let retained = Set([
            "same_size_mutation", "raw_root_swap", "destination_parent_swap", "symlink",
            "source_ancestor_symlink", "destination_ancestor_symlink", "hardlink",
            "wrong_destination_mode", "published_digest_mismatch",
            "published_identity_mismatch", "failed_output_replacement",
        ])
        for scenario in invalid {
            let result = try runScenario(scenario)
            #expect(result.status != 0, "Expected \(scenario) to fail closed")
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            #expect(!result.output.contains("hardware_evidence_test=pass"))
            #expect(!result.output.contains("/Users/"))
            #expect(!result.output.contains(result.outerRoot.path))
            if retained.contains(scenario) {
                #expect(result.output.contains("retained"))
                #expect(!rawRoots(in: result.outerRoot).isEmpty ||
                        !handoffRoots(in: result.outerRoot).isEmpty)
                if scenario == "raw_root_swap" {
                    #expect(result.output.contains(
                        "original_root_token=holdtype-dv-p0b."
                    ))
                } else if scenario == "destination_parent_swap" {
                    #expect(result.output.contains(
                        "original_root_token=holdtype-dv-p0b-handoff."
                    ))
                }
            } else {
                #expect(rawRoots(in: result.outerRoot).isEmpty)
                #expect(handoffRoots(in: result.outerRoot).isEmpty)
            }
            remove(result.outerRoot)
        }
    }

    @Test func consumerDetectsPostExitDigestSnapshotAndRootReplacementWithoutCleanup() throws {
        for mutation in ConsumerMutation.allCases {
            let result = try runScenario("valid")
            defer { remove(result.outerRoot) }
            let authority = try authority(in: result.output)
            try mutate(mutation, authority: authority, outerRoot: result.outerRoot)
            let consumed = try runConsumer(authority, in: result.outerRoot)
            #expect(consumed.status != 0)
            #expect(consumed.output.contains("hardware_evidence_consumer=retained"))
            #expect(consumed.output.contains("cleanup=not_attempted"))
            #expect(!consumed.output.contains("hardware_evidence_consumer=consumed"))
            #expect(!handoffRoots(in: result.outerRoot).isEmpty)
            if case .rootIdentity = mutation {
                #expect(consumed.output.contains(
                    "expected_root_token=\(authority.rootToken)original"
                ))
            }
        }
    }

    @Test func deadlineAndPreparationSignalsAreBoundedAndOwned() throws {
        let timeout = try runScenario("slow_validator")
        defer { remove(timeout.outerRoot) }
        #expect(timeout.status != 0)
        #expect(!timeout.output.contains("hardware_evidence_handoff=validated"))
        #expect(rawRoots(in: timeout.outerRoot).isEmpty)
        #expect(handoffRoots(in: timeout.outerRoot).isEmpty)

        for signal in [SIGTERM, SIGINT] {
            let result = try run(
                arguments: hardwareArguments, scenario: nil, timeout: 8,
                signalAfterOutput: "hardware_evidence_preparation=owned", signal: signal,
                preparationScenario: "slow"
            )
            #expect(result.status != 0)
            #expect(result.output.contains("hardware_evidence_preparation=owned"))
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            #expect(rawRoots(in: result.outerRoot).isEmpty)
            #expect(handoffRoots(in: result.outerRoot).isEmpty)
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

    @Test func scriptContractStatesTheNarrowTrustedBoundary() throws {
        let source = try String(contentsOf: scriptURL, encoding: .utf8)
        for token in [
            "object_pairs_hook=unique_object", "source_digest_mismatch",
            "snapshot_post_validation_mismatch", "trusted_debug_consumer_once",
            "--consume-hardware-evidence", "hardware_evidence_preparation=owned",
            "Under the accepted Phase 0B Debug trust boundary only",
        ] {
            #expect(source.contains(token))
        }
        #expect(source.contains("hardware_timeout_seconds=$(( capture_duration + 300 ))"))
        #expect(!source.contains("capture_duration + 360"))
        #expect(!source.contains("waitUntilExit"))
        #expect(!source.contains("killall"))
        let prepare = try #require(source.range(of: "prepare_hardware_evidence_handoff\n"))
        let launch = try #require(source.range(of: "HOLDTYPE_DEV_VLOGS_PHASE_0B_EVENT_LOG="))
        let validate = try #require(source.range(
            of: "validate_and_handoff_hardware_evidence ||", options: .backwards
        ))
        let cleanup = try #require(source.range(of: "raw_media_cleanup=scheduled"))
        #expect(prepare.lowerBound < launch.lowerBound)
        #expect(launch.lowerBound < validate.lowerBound)
        #expect(validate.lowerBound < cleanup.lowerBound)
    }

    private var hardwareArguments: [String] {
        ["--hardware", "--camera-id", "fake-camera", "--case-id", "handoff-test"]
    }

    private func runScenario(_ scenario: String) throws -> ScriptResult {
        try run(arguments: hardwareArguments, scenario: scenario, timeout: 8)
    }

    private func runConsumer(_ authority: HandoffAuthority, in outerRoot: URL) throws -> ScriptResult {
        try run(arguments: [
            "--consume-hardware-evidence", "--root-token", authority.rootToken,
            "--root-device", String(authority.rootDevice), "--root-inode", String(authority.rootInode),
            "--snapshot-device", String(authority.snapshotDevice),
            "--snapshot-inode", String(authority.snapshotInode),
            "--snapshot-sha256", authority.snapshotDigest, "--case-id", "handoff-test",
        ], scenario: nil, timeout: 8, outerRoot: outerRoot)
    }

    private func run(
        arguments: [String], scenario: String?, timeout: TimeInterval,
        signalAfterOutput: String? = nil, signal: Int32? = nil,
        preparationScenario: String? = nil, outerRoot suppliedRoot: URL? = nil
    ) throws -> ScriptResult {
        let outerRoot = suppliedRoot ?? FileManager.default.temporaryDirectory.appendingPathComponent(
            "dv-p0b-handoff-tests-\(UUID().uuidString)", isDirectory: true
        )
        if suppliedRoot == nil {
            try FileManager.default.createDirectory(
                at: outerRoot, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let outputURL = outerRoot.appendingPathComponent("process-output-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["TMPDIR"] = outerRoot.path + "/"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST"] = scenario
        environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_PREPARATION_TEST"] = preparationScenario
        process.environment = environment
        process.currentDirectoryURL = repositoryRoot
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        if let signalAfterOutput, let signal {
            while process.isRunning && Date() < deadline {
                let output = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
                if output.contains(signalAfterOutput) { kill(process.processIdentifier, signal); break }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        if process.isRunning {
            process.terminate()
            let termDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < termDeadline { Thread.sleep(forTimeInterval: 0.01) }
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            let killDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < killDeadline { Thread.sleep(forTimeInterval: 0.01) }
        }
        try outputHandle.close()
        guard !process.isRunning else { throw HandoffTestError.processDidNotExit }
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        try FileManager.default.removeItem(at: outputURL)
        return ScriptResult(status: process.terminationStatus, output: output, outerRoot: outerRoot)
    }

    private func authority(in output: String) throws -> HandoffAuthority {
        let line = try #require(output.split(separator: "\n").first {
            $0.contains("hardware_evidence_handoff=validated")
        })
        let fields = Dictionary(uniqueKeysWithValues: line.split(whereSeparator: \.isWhitespace)
            .compactMap { item -> (String, String)? in
                let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            })
        let rootDeviceText = try #require(fields["root_device"])
        let rootInodeText = try #require(fields["root_inode"])
        let snapshotDeviceText = try #require(fields["snapshot_device"])
        let snapshotInodeText = try #require(fields["snapshot_inode"])
        return HandoffAuthority(
            rootToken: try #require(fields["root_token"]),
            rootDevice: try #require(UInt64(rootDeviceText)),
            rootInode: try #require(UInt64(rootInodeText)),
            snapshotDevice: try #require(UInt64(snapshotDeviceText)),
            snapshotInode: try #require(UInt64(snapshotInodeText)),
            snapshotDigest: try #require(fields["snapshot_sha256"])
        )
    }

    private func assertSnapshot(_ url: URL, authority: HandoffAuthority) throws {
        var value = stat()
        #expect(lstat(url.path, &value) == 0)
        #expect(UInt64(value.st_dev) == authority.snapshotDevice)
        #expect(UInt64(value.st_ino) == authority.snapshotInode)
        #expect(value.st_nlink == 1)
        #expect(value.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG))
        #expect(value.st_mode & 0o777 == 0o400)
        let data = try Data(contentsOf: url)
        #expect(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() ==
                authority.snapshotDigest)
    }

    private func mutate(
        _ mutation: ConsumerMutation, authority: HandoffAuthority, outerRoot: URL
    ) throws {
        let root = outerRoot.appendingPathComponent(authority.rootToken, isDirectory: true)
        let snapshot = root.appendingPathComponent("events.jsonl")
        switch mutation {
        case .digest:
            chmod(snapshot.path, 0o600)
            let handle = try FileHandle(forWritingTo: snapshot)
            try handle.write(contentsOf: Data(" ".utf8))
            try handle.synchronize()
            try handle.close()
            chmod(snapshot.path, 0o400)
        case .snapshotIdentity:
            let data = try Data(contentsOf: snapshot)
            try FileManager.default.moveItem(
                at: snapshot, to: root.appendingPathComponent("events-original")
            )
            FileManager.default.createFile(atPath: snapshot.path, contents: data,
                                           attributes: [.posixPermissions: 0o400])
        case .rootIdentity:
            let original = outerRoot.appendingPathComponent(authority.rootToken + "original")
            try FileManager.default.moveItem(at: root, to: original)
            try FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.copyItem(
                at: original.appendingPathComponent("events.jsonl"), to: snapshot
            )
            chmod(snapshot.path, 0o400)
        }
    }

    private func rawRoots(in root: URL) -> [URL] { roots(in: root, prefix: "holdtype-dv-p0b.") }
    private func handoffRoots(in root: URL) -> [URL] {
        roots(in: root, prefix: "holdtype-dv-p0b-handoff.")
    }
    private func roots(in root: URL, prefix: String) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix(prefix) } ?? []
    }
    private func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private var scriptURL: URL {
        repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh")
    }
}

private struct HandoffAuthority {
    let rootToken: String
    let rootDevice: UInt64
    let rootInode: UInt64
    let snapshotDevice: UInt64
    let snapshotInode: UInt64
    let snapshotDigest: String
}

private enum ConsumerMutation: CaseIterable { case digest, snapshotIdentity, rootIdentity }
private struct ScriptResult { let status: Int32; let output: String; let outerRoot: URL }
private enum HandoffTestError: Error { case processDidNotExit }
#endif
