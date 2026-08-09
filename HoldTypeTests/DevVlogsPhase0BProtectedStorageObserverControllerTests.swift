#if DEBUG
import Foundation
import Testing

struct DevVlogsPhase0BProtectedStorageObserverControllerTests {
    @Test func helpDefaultAndInvalidModesCannotCreatePrivateRoots() throws {
        let before = try privateObserverRoots()
        let help = try run([scriptPath, "--help"])
        #expect(help.status == 0)
        #expect(help.output.contains("--execute"))
        let normal = try run([scriptPath])
        #expect(normal.status == 64)
        let invalid = try run([scriptPath, "--unknown"])
        #expect(invalid.status == 64)
        #expect(try privateObserverRoots() == before)
        for output in [help.output, normal.output, invalid.output] {
            #expect(!output.contains("/private/tmp/holdtype-dev-vlogs-observer."))
        }
    }

    @Test func classifierRowsAreSingleAndFirstApplicable() throws {
        let rows: [([String], String)] = [
            (["conflict", "continuous", "passed", "unchanged", "passed",
              "unchanged", "valid", "none", "absent", "none", "certain", "clear"],
             "environment_conflict"),
            (["clear", "broken", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"],
             "guard_discontinuity"),
            (["clear", "continuous", "failed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"], "build_failed"),
            (["clear", "continuous", "passed", "uncertain", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"], "metadata_uncertain"),
            (["clear", "continuous", "passed", "changed", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"],
             "build_window_change_correlated"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "valid", "all_succeeded", "observed", "outside_only", "certain", "clear"],
             "run_owned_canonical_recovery_write_correlated"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "valid", "all_succeeded", "observed", "outside_only", "certain", "uncertain"],
             "still_unknown"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "invalid", "none", "absent", "none", "certain", "uncertain"],
             "environment_conflict"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "invalid", "none", "absent", "mixed", "certain", "clear"], "still_unknown"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "invalid", "none", "absent", "none", "certain", "clear"], "observer_invalid"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "all_succeeded", "observed", "outside_or_indeterminate",
              "certain", "clear"], "evidence_conflict"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "failed", "observed", "private_only", "certain", "clear"],
             "hosted_test_failed"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "observed", "none", "certain", "clear"],
             "owner_exposed_no_mutation"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "uncertain", "clear"], "cleanup_uncertain"),
            (["clear", "continuous", "passed", "missing_unchanged", "passed",
              "missing_unchanged", "valid", "none", "absent", "none", "certain", "clear"],
             "pass_unchanged"),
        ]
        for (arguments, expected) in rows {
            let quoted = arguments.map(shellQuote).joined(separator: " ")
            let result = try run(["/bin/zsh", "-c",
                "source \(shellQuote(scriptPath)); classify_observer_result \(quoted)"])
            #expect(result.status == 0)
            #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == expected)
            #expect(result.output.split(separator: "\n").count == 1)
        }
    }

    @Test func productionParserBindsRunAndFeedsExactFactsToClassification() throws {
        let owner = observerLine(2, "owner_initialized", "none", "recovery_directory",
                                 "private_task_home", "observed")
        let outside = [
            observerLine(2, "owner_initialized", "none", "recovery_directory",
                         "private_task_home", "observed"),
            observerLine(3, "mutation_begin", "replace_recovery_index", "recovery_index",
                         "outside_private_task_home", "attempted"),
            observerLine(4, "mutation_end", "replace_recovery_index", "recovery_index",
                         "outside_private_task_home", "succeeded"),
        ]
        #expect(try parseStream([readyLine, owner]).output == "valid none observed none\n")
        #expect(try parseStream([readyLine] + outside).output
                == "valid all_succeeded observed outside_only\n")
        #expect(try classifyStream([readyLine] + outside, concurrent: "clear").output
                == "run_owned_canonical_recovery_write_correlated\n")
        #expect(try classifyStream([readyLine] + outside, concurrent: "uncertain").output
                == "still_unknown\n")

        var wrongRun = outside
        wrongRun[1] = observerLine(3, "mutation_begin", "replace_recovery_index",
            "recovery_index", "outside_private_task_home", "attempted", runID: otherRunID)
        let invalid: [[String]] = [
            [readyLine] + wrongRun,
            [readyLine, owner, observerLine(3, "mutation_end", "replace_recovery_index",
                "recovery_index", "private_task_home", "succeeded")],
            [readyLine, owner, observerLine(3, "mutation_begin", "replace_recovery_index",
                "recovery_audio", "private_task_home", "attempted")],
            [readyLine, owner.replacingOccurrences(of: "\"sequence\":2",
                with: "\"sequence\":2,\"sequence\":2")],
            [readyLine, observerLine(3, "owner_initialized", "none", "recovery_directory",
                "private_task_home", "observed")],
        ]
        for lines in invalid { #expect(try parseStream(lines).status != 0) }
    }

    @Test func absoluteInnerAndOuterBoundsStopTermIgnoringCommands() throws {
        let timeout = try timeoutExecutable()
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            timeout_executable=\(shellQuote(timeout))
            deadline=$(( SECONDS + 2 )); cleanup_reserve_seconds=0
            set +e
            run_timed_command 30 0 1 /bin/zsh -c 'trap "" TERM; while true; do :; done'
            inner_status=$?
            marker=$(/usr/bin/mktemp /private/tmp/holdtype-observer-expired.XXXXXXXX)
            /bin/unlink "$marker"; deadline=$SECONDS
            run_timed_command 30 0 1 /usr/bin/touch "$marker"; expired_status=$?
            outer_timeout_seconds=1; outer_kill_after_seconds=1
            outer_supervise /bin/zsh -c 'trap "" TERM; while true; do :; done'
            outer_status=$?
            set -e
            [[ $inner_status != 0 && $expired_status == 124 && ! -e "$marker" &&
               $outer_status != 0 ]] && print bounds=pass
            """])
        #expect(result.status == 0)
        #expect(result.output == "bounds=pass\n")
    }

    @Test func privateArtifactReplacementAndDiagnosticsFailClosed() throws {
        let timeout = try timeoutExecutable()
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath)); timeout_executable=\(shellQuote(timeout))
            deadline=$(( SECONDS + 60 )); cleanup_reserve_seconds=0
            validate_guard() { return 0 }
            setup() {
                run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-pins.XXXXXXXX)
                /bin/chmod 700 "$run_root"; task_home="$run_root/home"
                derived_data="$task_home/DerivedData"; temporary_root="$task_home/tmp"
                bin_root="$run_root/bin"; logs_root="$run_root/logs"; probe="$bin_root/probe"
                /bin/mkdir -m 700 "$task_home" "$derived_data" "$temporary_root" \
                    "$bin_root" "$logs_root" "$run_root/sibling"
                print fixture >"$probe"; /bin/chmod 700 "$probe"
                run_root_identity=$(identity "$run_root" 700)
                task_home_identity=$(identity "$task_home" 700)
                derived_data_identity=$(identity "$derived_data" 700)
                temporary_root_identity=$(identity "$temporary_root" 700)
                bin_root_identity=$(identity "$bin_root" 700)
                logs_root_identity=$(identity "$logs_root" 700)
                probe_identity=$(regular_file_identity "$probe" 700)
            }
            for name in temporary_root logs_root bin_root probe; do
                setup; target=${(P)name}; /bin/mv "$target" "${target}.original"
                if [[ "$name" == probe ]]; then print replacement >"$target"
                else /bin/mkdir -m 700 "$target"; fi
                /bin/chmod 700 "$target"
                set +e; validate_roots; validation_status=$?; set -e
                [[ $validation_status == 70 && -e "${target}.original" && -e "$target" &&
                   -d "$run_root/sibling" ]] || exit 71
                /bin/rm -rf -- "$run_root"
            done
            setup; bounded_status=0
            run_bounded_to_log 5 "$logs_root/private.log" /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; /bin/sleep 0.2; exit 8' \
                >"$run_root/bounded.output" 2>&1 || bounded_status=$?
            cleanup_command_status=0
            run_cleanup_command /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 9' \
                >"$run_root/cleanup.output" 2>&1 || cleanup_command_status=$?
            [[ $bounded_status == 8 && ! -s "$run_root/bounded.output" &&
               $cleanup_command_status == 9 && ! -s "$run_root/cleanup.output" ]] || exit 72
            /bin/rm -rf -- "$run_root"
            deadline=$(( SECONDS + 10 )); set +e
            output=$(run_metadata_probe /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 7' 2>&1); command_status=$?
            outer_timeout_seconds=5; outer_kill_after_seconds=1; set +e
            outer_output=$(outer_supervise /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 9' 2>&1); outer_status=$?
            set -e
            [[ $command_status == 7 && -z "$output" && $outer_status == 9 &&
               -z "$outer_output" ]] && print pins_and_redaction=pass
            """])
        #expect(result.status == 0)
        #expect(result.output == "pins_and_redaction=pass\n")
    }

    @Test func summaryTruthfullyDisclosesTheRejectedLiveHomeDiagnostic() throws {
        let summary = try String(contentsOfFile: summaryPath, encoding: .utf8)
        #expect(summary.contains("inherited the live user\nHome"))
        #expect(summary.contains("No\nprotected content was inspected"))
        #expect(summary.contains("no `Recovery.json` stat, open, read,\nwrite"))
        #expect(!summary.contains("No observer runtime, external volume,\nlive user Home"))
    }

    @Test func exactEvidenceAllowlistAndGuardFirstOrderingAreSourcePinned() throws {
        let source = try String(contentsOfFile: scriptPath, encoding: .utf8)
        let guardStart = try #require(source.range(of: "/usr/bin/caffeinate -dimsu -w $$ &"))
        let privateRoot = try #require(source.range(of: "/usr/bin/mktemp -d"))
        let compile = try #require(source.range(of: "run_bounded_to_log 60"))
        let build = try #require(source.range(of: "build-for-testing"))
        let hosted = try #require(source.range(of: "test-without-building"))
        #expect(guardStart.lowerBound < privateRoot.lowerBound)
        #expect(privateRoot.lowerBound < compile.lowerBound)
        #expect(compile.lowerBound < build.lowerBound)
        #expect(build.lowerBound < hosted.lowerBound)
        let result = try run(["/bin/zsh", "-c",
            "source \(shellQuote(scriptPath)); evidence_relative_paths"])
        #expect(result.output.split(separator: "\n").map(String.init) == [
            "summary.md", "source-feasibility.md", "environment.json", "matrix.csv",
            "measurements.csv", "artifacts.csv", "residuals.md",
            "events/storage-observer-r01.jsonl",
        ])
    }

    @Test func cleanupDeletesStableIdentityAndRetainsReplacementAndSibling() throws {
        let stable = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_cleanup_command() { "$@" }
            run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-cleanup.XXXXXXXX)
            /bin/chmod 700 "$run_root"
            run_root_identity=$(identity "$run_root" 700)
            validate_roots() { return 0 }
            cleanup_run_root
            [[ -z "$run_root" ]] && print stable_removed
            """])
        #expect(stable.status == 0)
        #expect(stable.output == "stable_removed\n")

        let replacement = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_cleanup_command() { "$@" }
            fixture=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-race.XXXXXXXX)
            /bin/chmod 700 "$fixture"
            run_root="$fixture/run"; /bin/mkdir -m 700 "$run_root"
            run_root_identity=$(identity "$run_root" 700)
            sibling="$fixture/sibling"; /bin/mkdir -m 700 "$sibling"
            validate_roots() { return 0 }
            observer_cleanup_test_hook() {
                /bin/mv "$run_root" "${run_root}.original"
                /bin/mkdir -m 700 "$run_root"
            }
            set +e; cleanup_run_root; cleanup_status=$?; set -e
            [[ $cleanup_status == 70 && -n "$run_root" && -d "${run_root}.original" &&
               -d "${run_root}.cleanup" && -d "$sibling" ]] && print replacement_retained
            /bin/rm -rf -- "$fixture"
            """])
        #expect(replacement.status == 0)
        #expect(replacement.output == "replacement_retained\n")
    }

    @Test func productionXCTestRunConfigurationInjectsTheClosedHostedEnvironment() throws {
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-dev-vlogs-observer.XXXXXXXX)
            /bin/chmod 700 "$run_root"
            task_home="$run_root/home"; derived_data="$task_home/DerivedData"
            products="$derived_data/Build/Products"
            /bin/mkdir -m 700 -p "$products"
            source_file="$products/HoldType_fixture.xctestrun"
            /usr/bin/plutil -create xml1 "$source_file"
            /usr/bin/plutil -insert HoldTypeTests -dictionary "$source_file"
            /usr/bin/plutil -insert HoldTypeTests.EnvironmentVariables -dictionary "$source_file"
            /bin/chmod 644 "$source_file"
            run_id=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee
            validate_roots() { return 0 }
            configure_hosted_xctestrun || exit 71
            [[ "$host_task_home" == /tmp/holdtype-dev-vlogs-observer.*/home &&
               "$host_temporary_root" == "$host_task_home/tmp" &&
               -n "$configured_xctestrun_identity" ]] || exit 72
            for key in HOME CFFIXED_USER_HOME TMPDIR HOLDTYPE_AUTOMATION \
                HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_RUN_ID \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_CASE_ID; do
                /usr/bin/plutil -extract "HoldTypeTests.EnvironmentVariables.$key" raw -o - \
                    "$configured_xctestrun" >/dev/null || exit 73
            done
            print xctestrun_environment=pass
            /bin/rm -rf -- "$run_root"
            """])
        #expect(result.status == 0)
        #expect(result.output == "xctestrun_environment=pass\n")
    }

    @Test func syntheticProbeCoversMissingPresentSymlinkAndModePredicates() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let binary = fixture.root.appendingPathComponent("probe").path
        let compile = try run(["/usr/bin/clang", "-std=c11", "-Wall", "-Wextra", "-Werror",
            "-DHTDV_PROBE_SYNTHETIC=1", probePath, "-o", binary])
        #expect(compile.status == 0)
        var environment = ProcessInfo.processInfo.environment
        environment["HTDV_PROBE_FIXTURE_ROOT"] = fixture.root.path
        environment["HTDV_PROBE_FIXTURE_USER"] = "fixture-user"
        let missing = try run([binary], environment: environment)
        #expect(missing.status == 0 && missing.output == "D|M\nI|M\n")
        let recovery = fixture.home.appendingPathComponent(
            "Library/Application Support/HoldType/TranscriptionRecovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        for path in [
            fixture.home.appendingPathComponent("Library"),
            fixture.home.appendingPathComponent("Library/Application Support"),
            fixture.home.appendingPathComponent("Library/Application Support/HoldType"),
            recovery,
        ] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                  ofItemAtPath: path.path)
        }
        let index = recovery.appendingPathComponent("Recovery.json")
        FileManager.default.createFile(atPath: index.path, contents: Data("fixture".utf8),
                                      attributes: [.posixPermissions: 0o600])
        let present = try run([binary], environment: environment)
        #expect(present.status == 0)
        #expect(present.output.split(separator: "\n").count == 2)
        try FileManager.default.removeItem(at: index)
        let indexMissing = try run([binary], environment: environment)
        #expect(indexMissing.status == 0 && indexMissing.output.contains("I|M\n"))
        FileManager.default.createFile(atPath: index.path, contents: Data("fixture".utf8),
                                      attributes: [.posixPermissions: 0o600])
        let linked = recovery.appendingPathComponent("linked-index")
        try FileManager.default.linkItem(at: index, to: linked)
        #expect(try run([binary], environment: environment).status == 65)
        try FileManager.default.removeItem(at: linked)
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: index.path)
        #expect(try run([binary], environment: environment).status == 65)
        try FileManager.default.removeItem(at: index)
        try FileManager.default.createSymbolicLink(at: index,
            withDestinationURL: fixture.root.appendingPathComponent("unopened-target"))
        #expect(try run([binary], environment: environment).status == 65)
    }

    @Test func probeSourcePinsNoEnumerationNoIndexOpenAndPrePostIdentityCheck() throws {
        let source = try String(contentsOfFile: probePath, encoding: .utf8)
        for forbidden in ["readdir(", "opendir(", "fopen(", "read(", "Data(contentsOf:"] {
            #expect(!source.contains(forbidden))
        }
        #expect(source.contains("fstatat(current, \"Recovery.json\", &index_value, AT_SYMLINK_NOFOLLOW)"))
        #expect(source.contains("fstat(fd, &after)"))
        #expect(source.contains("same_identity(&before, &after)"))
        #expect(!source.contains("openat(current, \"Recovery.json\""))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private var scriptPath: String {
        repositoryRoot.appendingPathComponent(
            "script/dev_vlogs_phase_0_b_protected_storage_observer.sh").path
    }
    private var probePath: String {
        repositoryRoot.appendingPathComponent(
            "script/dev_vlogs_phase_0_b_protected_storage_probe.c").path
    }
    private var summaryPath: String {
        repositoryRoot.appendingPathComponent(
            "docs/qa/runs/dev-vlogs-phase-0b-storage-observer-w01/summary.md").path
    }
    private var runID: String { "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee" }
    private var otherRunID: String { "11111111-2222-4333-8444-555555555555" }
    private var readyLine: String {
        observerLine(1, "observer_ready", "none", "observer", "not_applicable", "ready")
    }

    private func observerLine(
        _ sequence: Int,
        _ event: String,
        _ action: String,
        _ category: String,
        _ scope: String,
        _ result: String,
        runID: String? = nil
    ) -> String {
        "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "
            + "{\"schema_version\":1,\"run_id\":\"\(runID ?? self.runID)\","
            + "\"case_id\":\"protected_metadata\",\"sequence\":\(sequence),"
            + "\"event\":\"\(event)\",\"action\":\"\(action)\","
            + "\"category\":\"\(category)\",\"target_scope\":\"\(scope)\","
            + "\"result\":\"\(result)\"}"
    }

    private func parseStream(_ lines: [String]) throws -> (status: Int32, output: String) {
        try runStream(lines, command: "validate_observer_stream \"$stream\" \(runID)")
    }

    private func classifyStream(
        _ lines: [String],
        concurrent: String
    ) throws -> (status: Int32, output: String) {
        try runStream(lines, command:
            "classify_observer_stream_result \"$stream\" \(runID) unchanged passed changed \(concurrent)")
    }

    private func runStream(
        _ lines: [String],
        command: String
    ) throws -> (status: Int32, output: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-observer-stream-\(UUID().uuidString.lowercased())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let stream = root.appendingPathComponent("events.log")
        try (lines.joined(separator: "\n") + "\n").write(to: stream, atomically: true,
                                                          encoding: .utf8)
        return try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath)); run_metadata_probe() { "$@" }
            stream=\(shellQuote(stream.path)); \(command)
            """])
    }

    private func timeoutExecutable() throws -> String {
        let candidates = ["/opt/homebrew/bin/timeout", "/usr/local/bin/timeout", "/usr/bin/timeout"]
        return try #require(candidates.first(where: FileManager.default.isExecutableFile(atPath:)))
    }

    private func makeFixture() throws -> (root: URL, home: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-observer-probe-\(UUID().uuidString.lowercased())")
        let users = root.appendingPathComponent("Users")
        let home = users.appendingPathComponent("fixture-user")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        for path in [root, users, home] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        }
        return (root, home)
    }

    private func privateObserverRoots() throws -> Set<String> {
        let values = try FileManager.default.contentsOfDirectory(atPath: "/private/tmp")
        return Set(values.filter { $0.hasPrefix("holdtype-dev-vlogs-observer.") })
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func run(
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
#endif
