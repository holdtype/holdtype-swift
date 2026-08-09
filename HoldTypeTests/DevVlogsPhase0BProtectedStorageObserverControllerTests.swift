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
              "invalid", "none", "absent", "mixed", "certain", "clear"], "still_unknown"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "invalid", "none", "absent", "none", "certain", "clear"], "observer_invalid"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "succeeded_outside_or_indeterminate", "observed", "outside_only",
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

    @Test func exactEvidenceAllowlistAndGuardFirstOrderingAreSourcePinned() throws {
        let source = try String(contentsOfFile: scriptPath, encoding: .utf8)
        let guardStart = try #require(source.range(of: "/usr/bin/caffeinate -dimsu -w $$ &"))
        let privateRoot = try #require(source.range(of: "/usr/bin/mktemp -d"))
        let compile = try #require(source.range(of: "run_bounded 60 /usr/bin/clang"))
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
