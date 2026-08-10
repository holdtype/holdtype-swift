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
            "camera_selection_disconnected", "camera_start_device_unavailable", "camera_selection_busy",
            "camera_configuration_video_input", "camera_configuration_movie_output",
            "camera_configuration_sample_output", "camera_start_timed_out", "camera_first_frame_unavailable",
            "camera_recording_failed", "camera_interruption_disconnected", "camera_session_runtime_failure",
            "camera_session_not_capturing", "camera_unknown", "capture_stop", "camera_probe",
            "passthrough_incompatible", "passthrough_export_failed", "finalization", "final_probe",
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
    @Test func protectedIdentifierAndZeroNominalFPSFormsPublishAndConsume() throws {
        for (scenario, caseID) in [
            ("valid", "-leading-hyphen"), ("valid", "_leading-underscore"),
            ("valid_nominal_zero_derived_positive", "zero-nominal-failure"),
            ("valid_ready_nominal_zero_derived_positive", "zero-nominal-ready"),
        ] {
            let result = try runScenario(scenario, caseID: caseID)
            defer { remove(result.outerRoot) }
            #expect(result.status == 0, "Expected \(scenario) / \(caseID) to pass")
            let authority = try authority(in: result.output)
            #expect(try runConsumer(authority, in: result.outerRoot, caseID: caseID).status == 0)
        }
    }
    @Test func productionRouteRejectsOwnershipMutationSchemaAndPrivateDataMatrix() throws {
        let invalid = [
            "zero", "multiple", "add_after_list", "remove_after_list", "source_replacement",
            "same_size_mutation", "source_parent_swap", "raw_root_swap", "destination_parent_swap",
            "wrong_owner", "symlink", "source_ancestor_symlink", "destination_ancestor_symlink",
            "hardlink", "wrong_source_mode", "wrong_source_type", "wrong_source_parent_mode",
            "wrong_destination_mode", "destination_collision", "malformed", "oversize", "duplicate_top",
            "duplicate_nested", "unexpected_schema", "extra_nested", "missing_stage_key", "false_stage",
            "wrong_case", "wrong_ids", "invalid_run_id", "invalid_attempt_id", "wrong_order", "missing_start",
            "missing_terminal", "duplicate_terminal", "ready_plus_failure", "unexpected_event",
            "arbitrary_category", "impossible_failure_category", "arbitrary_dimension",
            "wrong_result_dimension", "arbitrary_device", "identifier_too_long", "private_data",
            "private_subtype", "nonfinite_metric", "out_of_range_metric", "unexpected_metric", "wrong_unit",
            "wrong_disposition", "wrong_metric_value", "duplicate_metric", "missing_required_metric",
            "preservation_extra_duration", "backward_timestamp", "ready_extra_video_key",
            "ready_count_mismatch", "ready_unmatched", "ready_wrong_method", "ready_bad_device_label",
            "ready_bad_device_class", "ready_missing_audio_duration", "ready_missing_video_metric",
            "ready_missing_fps", "ready_impossible_audio_metric", "ready_with_failure_category",
            "ordinary_failure_metrics", "ordinary_failure_device", "published_digest_mismatch",
            "published_identity_mismatch", "failed_output_replacement",
        ]
        for scenario in invalid {
            let result = try runScenario(scenario)
            #expect(result.status != 0, "Expected \(scenario) to fail closed")
            #expect(!result.output.contains("hardware_evidence_handoff=validated"))
            #expect(!result.output.contains("hardware_evidence_test=pass"))
            #expect(!result.output.contains("/Users/"))
            #expect(!result.output.contains(result.outerRoot.path))
            #expect(result.output.contains("hardware_evidence_publish=retained"))
            #expect(result.output.contains("residual_class=raw_and_handoff"))
            #expect(result.output.contains("raw_root_token=holdtype-dv-p0b."))
            #expect(result.output.contains("handoff_root_token=holdtype-dv-p0b-handoff."))
            #expect(!rawRoots(in: result.outerRoot).isEmpty)
            #expect(!handoffRoots(in: result.outerRoot).isEmpty)
            for key in ["raw_root_token=", "handoff_root_token="] {
                let field = try #require(result.output.split(whereSeparator: \.isWhitespace)
                    .first { $0.hasPrefix(key) })
                let token = String(field.dropFirst(key.count))
                #expect(FileManager.default.fileExists(atPath:
                    result.outerRoot.appendingPathComponent(token).path))
            }
            if scenario == "raw_root_swap" {
                #expect(result.output.contains("original_raw_root_token=holdtype-dv-p0b."))
            } else if scenario == "destination_parent_swap" {
                #expect(result.output.contains(
                    "original_handoff_root_token=holdtype-dv-p0b-handoff."
                ))
            } else if scenario == "same_size_mutation" {
                let event = try #require(rawRoots(in: result.outerRoot).first)
                    .appendingPathComponent("hardware-raw/evidence/events.jsonl")
                #expect(try Data(contentsOf: event).first == 0x20)
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
            let consumed = try runConsumer(
                authority, in: result.outerRoot,
                caseID: mutation == .caseSchema ? "other-case" : "handoff-test",
                consumerScenario: mutation == .cleanup ? "snapshot_cleanup_mismatch" : nil
            )
            #expect(consumed.status != 0)
            #expect(consumed.output.contains("hardware_evidence_consumer=retained"))
            #expect(consumed.output.contains(
                mutation == .cleanup ? "cleanup=partial_snapshot_removed" : "cleanup=not_attempted"
            ))
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
    @Test func publisherAndConsumerTERMAndINTRetainEvidenceWithoutCollateralEffects() throws {
        for signal in [SIGTERM, SIGINT] {
            let publisherRoot = try makeOuterRoot()
            defer { remove(publisherRoot) }
            let publisherSentinel = try installSentinel(in: publisherRoot)
            let publisher = try run(
                arguments: hardwareArguments, scenario: "slow_publisher_execution", timeout: 8,
                signalAfterOutput: "hardware_evidence_publisher=pinned", signal: signal,
                outerRoot: publisherRoot
            )
            #expect(publisher.status == (signal == SIGTERM ? 143 : 130))
            #expect(publisher.output.contains("hardware_evidence_publish=retained reason=signal"))
            #expect(!rawRoots(in: publisherRoot).isEmpty)
            #expect(!handoffRoots(in: publisherRoot).isEmpty)
            try assertSentinelSurvived(publisherSentinel, output: publisher.output)

            let consumerRoot = try makeOuterRoot()
            defer { remove(consumerRoot) }
            let produced = try runScenario("valid", outerRoot: consumerRoot)
            let authority = try authority(in: produced.output)
            let consumerSentinel = try installSentinel(in: consumerRoot)
            let consumer = try runConsumer(
                authority, in: consumerRoot, consumerScenario: "slow_consumer_execution",
                signalAfterOutput: "hardware_evidence_consumer=pinned", signal: signal
            )
            #expect(consumer.status == (signal == SIGTERM ? 143 : 130))
            #expect(consumer.output.contains("hardware_evidence_consumer=retained reason=signal"))
            try assertSnapshot(
                consumerRoot.appendingPathComponent(authority.rootToken)
                    .appendingPathComponent("events.jsonl"), authority: authority
            )
            try assertSentinelSurvived(consumerSentinel, output: consumer.output)
        }
    }
    @Test func preAttemptConfigurationDiagnosticIsRetainedClosedAndConsumedOnce() throws {
        let result = try run(arguments: hardwareArguments, scenario: nil, timeout: 8,
                             configurationScenario: "automation_not_enabled")
        defer { remove(result.outerRoot) }
        #expect(result.status == 65); #expect(result.output.contains("hardware_configuration_handoff=validated"))
        #expect(result.output.contains("configuration_stage=automation_not_enabled")); #expect(result.output.contains("attempt=zero ready=zero"))
        #expect(rawRoots(in: result.outerRoot).isEmpty)
        let retained = try authority(in: result.output)
        #expect(retained.snapshotFile == "configuration.json")
        let snapshot = result.outerRoot.appendingPathComponent(retained.rootToken).appendingPathComponent(retained.snapshotFile)
        try assertSnapshot(snapshot, authority: retained)
        #expect(try runConsumer(retained, in: result.outerRoot).status == 0)
        for scenario in ["invalid_missing_lf", "invalid_crlf", "invalid_extra_lf",
                         "invalid_duplicate", "invalid_nul", "invalid_non_ascii",
                         "invalid_trailing", "invalid_extra", "invalid_private", "invalid_category", "invalid_empty"] {
            let rejected = try run(arguments: hardwareArguments, scenario: nil, timeout: 8,
                                   configurationScenario: scenario)
            #expect(rejected.status == 65); #expect(rejected.output.contains("hardware_configuration_test=rejected"))
            #expect(!rejected.output.contains("hardware_configuration_handoff=validated")); #expect(!rejected.output.contains("/Users/"))
            #expect(rawRoots(in: rejected.outerRoot).isEmpty); #expect(handoffRoots(in: rejected.outerRoot).isEmpty)
            remove(rejected.outerRoot)
        }
        for scenario in ["identity_mode", "identity_hardlink", "identity_replace", "identity_sibling"] {
            let retained = try run(arguments: hardwareArguments, scenario: nil, timeout: 8,
                                   configurationScenario: scenario)
            #expect(retained.status == 70); #expect(retained.output.contains("reason=identity_mismatch"))
            #expect(!retained.output.contains("hardware_configuration_handoff=validated"))
            let roots = handoffRoots(in: retained.outerRoot)
            #expect(rawRoots(in: retained.outerRoot).isEmpty); #expect(roots.count == 1)
            let names = try FileManager.default.contentsOfDirectory(atPath: try #require(roots.first).path)
            #expect(names.contains(".configuration-diagnostic")); #expect(!names.contains("configuration.json"))
            remove(retained.outerRoot)
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
    private var hardwareArguments: [String] { ["--hardware", "--camera-id", "fake-camera", "--case-id", "handoff-test"] }
    private func runScenario(
        _ scenario: String, caseID: String = "handoff-test", outerRoot: URL? = nil
    ) throws -> ScriptResult {
        try run(arguments: ["--hardware", "--camera-id", "fake-camera", "--case-id", caseID],
                scenario: scenario, timeout: 8, outerRoot: outerRoot)
    }
    private func runConsumer(
        _ authority: HandoffAuthority, in outerRoot: URL, caseID: String = "handoff-test",
        consumerScenario: String? = nil, signalAfterOutput: String? = nil,
        signal: Int32? = nil
    ) throws -> ScriptResult {
        try run(arguments: [
            "--consume-hardware-evidence", "--root-token", authority.rootToken,
            "--root-device", String(authority.rootDevice), "--root-inode", String(authority.rootInode),
            "--snapshot-device", String(authority.snapshotDevice),
            "--snapshot-inode", String(authority.snapshotInode),
            "--snapshot-sha256", authority.snapshotDigest, "--case-id", caseID,
        ], scenario: nil, timeout: 8, signalAfterOutput: signalAfterOutput, signal: signal,
           outerRoot: outerRoot, consumerScenario: consumerScenario)
    }
    private func run(
        arguments: [String], scenario: String?, timeout: TimeInterval,
        signalAfterOutput: String? = nil, signal: Int32? = nil,
        preparationScenario: String? = nil, outerRoot suppliedRoot: URL? = nil,
        consumerScenario: String? = nil, configurationScenario: String? = nil
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
        environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONSUMER_TEST"] = consumerScenario
        environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONFIGURATION_TEST"] = configurationScenario
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
        let line = try #require(output.split(separator: "\n").first { $0.contains("_handoff=validated") })
        let fields = Dictionary(uniqueKeysWithValues: line.split(whereSeparator: \.isWhitespace)
            .compactMap { item -> (String, String)? in
                let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            })
        return .init(rootToken: try #require(fields["root_token"]),
                     rootDevice: try #require(fields["root_device"].flatMap(UInt64.init)),
                     rootInode: try #require(fields["root_inode"].flatMap(UInt64.init)),
                     snapshotDevice: try #require(fields["snapshot_device"].flatMap(UInt64.init)),
                     snapshotInode: try #require(fields["snapshot_inode"].flatMap(UInt64.init)),
                     snapshotDigest: try #require(fields["snapshot_sha256"]), snapshotFile: try #require(fields["file"]))
    }
    private func mutateConfiguration(
        _ file: URL, mutation: String, authority: HandoffAuthority
    ) throws -> HandoffAuthority {
        var text = try String(contentsOf: file, encoding: .utf8)
        switch mutation {
        case "duplicate": text = text.replacingOccurrences(
            of: "\"category\":", with: "\"category\":\"invalid_configuration\",\"category\":")
        case "extra": text = text.replacingOccurrences(of: "}\n", with: ",\"extra\":true}\n")
        case "category": text = text.replacingOccurrences(
            of: "\"category\":\"invalid_configuration\"", with: "\"category\":\"private\"")
        default: text = text.replacingOccurrences(
            of: "\"configuration_stage\":\"unknown\"", with: "\"configuration_stage\":\"/Users/private\"")
        }
        chmod(file.path, 0o600)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 0); try handle.write(contentsOf: Data(text.utf8))
        try handle.synchronize(); try handle.close(); chmod(file.path, 0o400)
        let digest = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        return .init(rootToken: authority.rootToken, rootDevice: authority.rootDevice,
                     rootInode: authority.rootInode, snapshotDevice: authority.snapshotDevice,
                     snapshotInode: authority.snapshotInode, snapshotDigest: digest, snapshotFile: authority.snapshotFile)
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
        case .rootSchema:
            FileManager.default.createFile(
                atPath: root.appendingPathComponent("unexpected").path, contents: Data()
            )
        case .rootMode:
            chmod(root.path, 0o755)
        case .snapshotMode:
            chmod(snapshot.path, 0o600)
        case .caseSchema, .cleanup:
            break
        }
    }

    private func makeOuterRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "dv-p0b-handoff-tests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        return root
    }

    private func installSentinel(in root: URL) throws -> SignalSentinel {
        let file = root.appendingPathComponent("unrelated-sentinel")
        try Data("unrelated".utf8).write(to: file, options: .withoutOverwriting)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        return SignalSentinel(file: file, process: process)
    }

    private func assertSentinelSurvived(_ sentinel: SignalSentinel, output: String) throws {
        #expect(sentinel.process.isRunning)
        #expect(try String(contentsOf: sentinel.file, encoding: .utf8) == "unrelated")
        #expect(!output.contains(sentinel.file.path))
        let ownedPIDs = output.split(whereSeparator: \.isWhitespace).compactMap { field -> Int32? in
            let text = String(field)
            guard text.hasPrefix("worker_pid=") || text.hasPrefix("producer_pid=") else {
                return nil
            }
            return Int32(text.split(separator: "=", maxSplits: 1)[1])
        }
        #expect(Set(ownedPIDs).count == 2)
        for ownedPID in Set(ownedPIDs) { #expect(kill(ownedPID, 0) != 0) }
        sentinel.process.terminate()
        let deadline = Date().addingTimeInterval(1)
        while sentinel.process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        if sentinel.process.isRunning { kill(sentinel.process.processIdentifier, SIGKILL) }
        sentinel.process.waitUntilExit()
    }

    private func rawRoots(in root: URL) -> [URL] {
        roots(in: root, prefix: "holdtype-dv-p0b.").filter {
            !$0.lastPathComponent.hasPrefix("holdtype-dv-p0b-handoff.")
        }
    }
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
    let snapshotFile: String
}

private enum ConsumerMutation: CaseIterable {
    case digest, snapshotIdentity, rootIdentity, rootSchema, rootMode, snapshotMode, caseSchema, cleanup
}
private struct SignalSentinel { let file: URL; let process: Process }
private struct ScriptResult { let status: Int32; let output: String; let outerRoot: URL }
private enum HandoffTestError: Error { case processDidNotExit }
#endif
