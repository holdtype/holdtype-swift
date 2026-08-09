#if DEBUG
import CryptoKit
import Darwin
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BCameraAuthorizationLaunchServicesTests {
    @Test func validNoFollowAcknowledgmentPassesAndDigestIsStable() async throws {
        let fixture = try HandshakeFixture()
        defer { fixture.remove() }
        try fixture.writeAcknowledgment()
        let outcome = await fixture.handshake().waitForAcknowledgment()
        #expect(outcome == .acknowledged)
        #expect(fixture.expected.processDigest.count == 64)
        #expect(!fixture.expected.processDigest.contains(String(getpid())))
        let input = Data("\(fixture.configuration.launchToken):\(getpid())".utf8)
        let expected = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
        #expect(fixture.expected.processDigest == expected)
    }

    @Test func malformedModeSymlinkTokenAndDigestFailClosed() async throws {
        for mutation in HandshakeMutation.allCases {
            let fixture = try HandshakeFixture()
            defer { fixture.remove() }
            try fixture.writeAcknowledgment(mutation: mutation)
            #expect(await fixture.handshake().waitForAcknowledgment() == .invalid)
        }
    }

    @Test func missingCallbackEquivalentTimesOutAndCancellationWins() async {
        let configuration = HandshakeFixture.configuration(
            root: URL(fileURLWithPath: "/tmp/unused", isDirectory: true)
        )
        let missing = DevVlogsPhase0BCameraAuthorizationHandshake(
            configuration: configuration,
            timeout: .milliseconds(1),
            sleep: { _ in },
            read: { .missing }
        )
        #expect(await missing.waitForAcknowledgment() == .timedOut)

        let cancelled = DevVlogsPhase0BCameraAuthorizationHandshake(
            configuration: configuration,
            timeout: .seconds(120),
            sleep: { _ in try await Task.sleep(for: .seconds(120)) },
            read: { .missing }
        )
        let task = Task { await cancelled.waitForAcknowledgment() }
        await Task.yield()
        task.cancel()
        #expect(await task.value == .cancelled)
    }

    @Test func changedOrDuplicateReadNeverPublishesAcknowledgment() async {
        let configuration = HandshakeFixture.configuration(
            root: URL(fileURLWithPath: "/tmp/unused", isDirectory: true)
        )
        let expected = DevVlogsPhase0BCameraAuthorizationHandshake(
            configuration: configuration, read: { .missing }
        ).expectedAcknowledgment
        let lock = NSLock()
        var reads = 0
        let handshake = DevVlogsPhase0BCameraAuthorizationHandshake(
            configuration: configuration,
            sleep: { _ in },
            read: {
                lock.withLock {
                    reads += 1
                    if reads == 1 { return .value(expected) }
                    return .value(.init(
                        version: 1, token: expected.token,
                        processDigest: String(repeating: "0", count: 64)
                    ))
                }
            }
        )
        #expect(await handshake.waitForAcknowledgment() == .invalid)
        #expect(lock.withLock { reads == 2 })
    }

    @Test func helperAndScriptUseExactURLClosedResultAndNoForbiddenCapabilities() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let helper = try String(contentsOf: root.appendingPathComponent(
            "script/DevVlogsPhase0BCameraAuthorizationLauncher.swift"
        ), encoding: .utf8)
        for token in ["openApplication(", "createsNewApplicationInstance = true",
                      "addsToRecentItems = false", "promptsUserIfNeeded = false",
                      "allowsRunningApplicationSubstitution = false", "configuration.arguments = []",
                      "process_digest", "openat", "linkat", "O_EXCL", "O_NOFOLLOW",
                      "metadata.st_uid == getuid()", "Set(object.keys) ==", "runSelfTests()"] {
            #expect(helper.contains(token))
        }
        for forbidden in ["AVFoundation", "AVCapture", "codesign", "xattr -d"] {
            #expect(!helper.contains(forbidden))
        }
        #expect(!helper.contains("fields[\"--token\"]"))

        let script = try String(contentsOf: root.appendingPathComponent(
            "script/dev_vlogs_phase_0b_spike.sh"
        ), encoding: .utf8)
        for token in ["xcrun swiftc -D DEBUG -parse-as-library", "permission_helper_pid=$!",
                      "--verify-result", "parse_permission_verified_result", "expected_process_digest",
                      "camera-authorization-ack.json", "set -o noclobber", "permission_terminal_observed",
                      "permission_deadline", "permission_work_deadline",
                      "permission_cleanup_reserve_seconds", "permission_scrub_sensitive_artifacts",
                      "permission_remove_run_root", "timeout_command \"$REPLY\" ln"] {
            #expect(script.contains(token))
        }
        #expect(!script.contains("plutil -extract"))
        #expect(!script.contains("launcher_result_stat"))
        #expect(script.contains("cleanup || prior_status=70"))
        #expect(script.contains("permission_verify_run_root \"$permission_deadline\""))
        let deadline = try #require(script.range(of: "begin_permission_deadline \"$permission_timeout_seconds\""))
        let compile = try #require(script.range(of: "timeout_command \"$REPLY\" xcrun swiftc"))
        #expect(deadline.lowerBound < compile.lowerBound)
        #expect(!script.contains("\"$app_binary\" >\"$permission_operator_log\""))
        for forbidden in ["killall", "pkill", "pgrep", "tccutil", "osascript"] {
            #expect(!script.contains(forbidden))
        }
        #expect(!script.contains("--token \"$permission_launch_token\""))
    }

    @Test func cleanupReserveIsBoundedVerifiedAndFailsClosed() throws {
        let root = try ScriptFixture()
        defer { root.remove() }
        let expectations: [(String, Int32, Int, Bool)] = [
            ("cleanup_normal", 0, 0, false),
            ("cleanup_uncertain", 70, 1, false),
            ("cleanup_scrub_timeout", 70, 1, true),
            ("cleanup_scrub_failure", 70, 1, true),
            ("cleanup_root_timeout", 70, 1, false),
            ("cleanup_root_failure", 70, 1, false),
            ("cleanup_deadline_expired", 70, 1, true),
            ("cleanup_term", 143, 0, false),
            ("cleanup_int", 130, 0, false),
        ]
        for (scenario, status, rootCount, sensitiveRemain) in expectations {
            let start = ProcessInfo.processInfo.systemUptime
            let result = try root.runHook(scenario, timeout: 16)
            #expect(result.status == status)
            #expect(ProcessInfo.processInfo.systemUptime - start < 15)
            let runRoots = try root.runRoots(for: scenario)
            #expect(runRoots.count == rootCount)
            let sensitive = runRoots.flatMap(root.sensitiveArtifacts(in:))
            #expect(sensitive.isEmpty != sensitiveRemain)
            #expect(!result.output.contains(String(repeating: "0", count: 64)))
        }
    }

    @Test func parserHookIsPermissionOnlyAcrossModeSelection() throws {
        let root = try ScriptFixture()
        defer { root.remove() }
        for arguments in [[], ["--help"], ["--unknown"], ["--hardware"],
                          ["--request-camera-permission", "--build-only"]] {
            let ordinary = try root.run(arguments: arguments, hook: nil, timeout: 5)
            let hooked = try root.run(arguments: arguments, hook: "valid", timeout: 5)
            #expect(hooked.status == ordinary.status)
            #expect(hooked.output == ordinary.output)
        }
        let build = try root.run(arguments: ["--build-only"], hook: "valid", timeout: 600)
        #expect(build.status == 0)
        #expect(build.output.contains("build_only=pass hardware=not_run"))
        #expect(!build.output.contains("permission_result_parser_test"))
    }

    @Test func realScriptParserPublishesOnlyAfterStrictVerifiedResult() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let script = root.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh")
        let valid = try BoundedProcess.run(
            executable: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [script.path, "--request-camera-permission"],
            environment: [
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST": "valid",
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS": "20",
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            ],
            currentDirectory: root,
            timeout: 25
        )
        #expect(valid.status == 0)
        #expect(valid.output == "permission_result_parser_test=pass acknowledgment=published\n")
        for mutation in ["extra_key", "wrong_digest"] {
            let rejected = try BoundedProcess.run(
                executable: URL(fileURLWithPath: "/bin/zsh"),
                arguments: [script.path, "--request-camera-permission"],
                environment: [
                    "HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST": mutation,
                    "HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS": "20",
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                ],
                currentDirectory: root,
                timeout: 25
            )
            #expect(rejected.status == 65)
            #expect(rejected.output == "permission_result_parser_test=rejected acknowledgment=absent\n")
        }
    }

    @Test func helperVerifierUsesOneStrictDescriptorSnapshot() throws {
        let fixture = try LauncherVerifierFixture()
        defer { fixture.remove() }
        #expect(try fixture.runSelfTest().status == 0)
        let valid = try fixture.verify(.valid)
        #expect(valid.status == 0)
        #expect(valid.output == "category=launched bundle=true executable=true identifier=true digest=true\n")
        for mutation in LauncherResultMutation.invalidCases {
            #expect(try fixture.verify(mutation).status != 0)
        }
    }
}

private enum LauncherResultMutation: CaseIterable {
    case valid, missingKey, extraKey, wrongVersion, malformed, oversized, symlink
    case wrongMode, wrongRootMode, wrongType, wrongToken, wrongDigest, extraLink

    static var invalidCases: [Self] { allCases.filter { $0 != .valid } }
}

private final class LauncherVerifierFixture {
    private let root: URL
    private let launcher: URL
    private let result: URL
    private let token = String(repeating: "a", count: 64)
    private let expectedPID = ProcessInfo.processInfo.processIdentifier

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        launcher = root.appendingPathComponent("launcher")
        result = root.appendingPathComponent("camera-authorization-launch.json")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]
        )
        chmod(root.path, 0o700)
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let compile = try BoundedProcess.run(
            executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["swiftc", "-D", "DEBUG", "-D", "DEV_VLOGS_PHASE_0B_LAUNCHER_TESTING",
                        "-parse-as-library", "-framework", "AppKit", "-framework", "Foundation",
                        repository.appendingPathComponent(
                            "script/DevVlogsPhase0BCameraAuthorizationLauncher.swift"
                        ).path, "-o", launcher.path],
            environment: [:], currentDirectory: repository, timeout: 60
        )
        guard compile.status == 0 else { throw ProcessFailure.failed }
    }

    func runSelfTest() throws -> BoundedProcess.Result {
        try BoundedProcess.run(
            executable: launcher, arguments: ["--self-test"], environment: [:],
            currentDirectory: root, timeout: 10
        )
    }

    func verify(_ mutation: LauncherResultMutation) throws -> BoundedProcess.Result {
        try? FileManager.default.removeItem(at: result)
        try? FileManager.default.removeItem(at: root.appendingPathComponent("linked-result"))
        var object = validObject()
        switch mutation {
        case .missingKey: object.removeValue(forKey: "category")
        case .extraKey: object["private"] = "rejected"
        case .wrongVersion: object["version"] = 2
        case .wrongToken: break
        case .wrongDigest: object["process_digest"] = String(repeating: "0", count: 64)
        default: break
        }
        if mutation == .malformed {
            try Data("private-payload".utf8).write(to: result)
        } else if mutation == .oversized {
            try Data(repeating: 65, count: 1_025).write(to: result)
        } else if mutation == .symlink {
            let target = root.appendingPathComponent("target-result")
            try JSONSerialization.data(withJSONObject: object).write(to: target)
            try FileManager.default.createSymbolicLink(at: result, withDestinationURL: target)
        } else if mutation == .wrongType {
            try FileManager.default.createDirectory(at: result, withIntermediateDirectories: false)
        } else {
            try JSONSerialization.data(withJSONObject: object).write(to: result)
            chmod(result.path, mutation == .wrongMode ? 0o644 : 0o600)
            if mutation == .extraLink {
                try FileManager.default.linkItem(at: result, to: root.appendingPathComponent("linked-result"))
            }
        }
        let environmentToken = mutation == .wrongToken ? String(repeating: "b", count: 64) : token
        if mutation == .wrongRootMode { chmod(root.path, 0o755) }
        defer { chmod(root.path, 0o700) }
        return try BoundedProcess.run(
            executable: launcher, arguments: ["--verify-result"],
            environment: [
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT": root.path,
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN": environmentToken,
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_EXPECTED_PID": String(expectedPID),
            ], currentDirectory: root, timeout: 10
        )
    }

    private func validObject() -> [String: Any] {
        let input = Data("\(token):\(expectedPID)".utf8)
        let digest = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
        return [
            "version": 1, "category": "launched", "bundle_url_matches": true,
            "executable_url_matches": true, "bundle_identifier_matches": true,
            "launch_monotonic_ms": 1, "process_digest": digest,
        ]
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private enum ProcessFailure: Error { case failed, timedOut }

private final class ScriptFixture {
    private let repository: URL
    private let parent: URL
    private let script: URL
    private let path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    init() throws {
        repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        script = repository.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh")
        parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
    }

    func runHook(_ scenario: String, timeout: TimeInterval) throws -> BoundedProcess.Result {
        let temporary = parent.appendingPathComponent(scenario)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        return try run(
            arguments: ["--request-camera-permission"], hook: scenario, timeout: timeout,
            extraEnvironment: ["TMPDIR": temporary.path,
                               "HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS": "14"]
        )
    }

    func run(
        arguments: [String], hook: String?, timeout: TimeInterval,
        extraEnvironment: [String: String] = [:]
    ) throws -> BoundedProcess.Result {
        var environment = extraEnvironment
        environment["PATH"] = path
        if let hook { environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST"] = hook }
        return try BoundedProcess.run(
            executable: URL(fileURLWithPath: "/bin/zsh"), arguments: [script.path] + arguments,
            environment: environment, currentDirectory: repository, timeout: timeout
        )
    }

    func runRoots(for scenario: String) throws -> [URL] {
        let directory = parent.appendingPathComponent(scenario)
        return try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("holdtype-dv-p0b.") }
    }

    func sensitiveArtifacts(in root: URL) -> [URL] {
        ["camera-authorization-launch.json", "camera-authorization-ack.json",
         ".camera-authorization-ack.test", "permission-launcher.log"].map(root.appendingPathComponent)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func remove() { try? FileManager.default.removeItem(at: parent) }
}

private enum BoundedProcess {
    struct Result { let status: Int32; let output: String }

    static func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL,
        timeout: TimeInterval
    ) throws -> Result {
        let process = Process()
        let output = Pipe()
        let completion = DispatchSemaphore(value: 0)
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, value in value }
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { _ in completion.signal() }
        try process.run()
        guard completion.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            guard completion.wait(timeout: .now() + 2) == .success else {
                Darwin.kill(process.processIdentifier, SIGKILL)
                _ = completion.wait(timeout: .now() + 2)
                throw ProcessFailure.timedOut
            }
            throw ProcessFailure.timedOut
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return .init(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

private enum HandshakeMutation: CaseIterable {
    case malformed, wrongMode, symlink, wrongToken, wrongDigest
}

@MainActor
private final class HandshakeFixture {
    let root: URL
    let configuration: DevVlogsPhase0BCameraAuthorizationConfiguration
    let expected: DevVlogsPhase0BCameraAuthorizationHandshake.Acknowledgment

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        chmod(root.path, 0o700)
        configuration = Self.configuration(root: root)
        expected = DevVlogsPhase0BCameraAuthorizationHandshake(
            configuration: configuration, read: { .missing }
        ).expectedAcknowledgment
    }

    static func configuration(root: URL) -> DevVlogsPhase0BCameraAuthorizationConfiguration {
        .init(runRoot: root, caseID: "camera-authorization",
              launchToken: String(repeating: "a", count: 64))
    }

    func handshake() -> DevVlogsPhase0BCameraAuthorizationHandshake {
        .init(configuration: configuration, timeout: .milliseconds(10), sleep: { _ in })
    }

    func writeAcknowledgment(mutation: HandshakeMutation? = nil) throws {
        let file = root.appendingPathComponent(DevVlogsPhase0BCameraAuthorizationHandshake.fileName)
        if mutation == .symlink {
            let target = root.appendingPathComponent("target")
            try Data("{}".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
            return
        }
        let value = DevVlogsPhase0BCameraAuthorizationHandshake.Acknowledgment(
            version: 1,
            token: mutation == .wrongToken ? String(repeating: "b", count: 64) : expected.token,
            processDigest: mutation == .wrongDigest ? String(repeating: "0", count: 64) : expected.processDigest
        )
        let data = mutation == .malformed ? Data("private-payload".utf8) : try JSONEncoder().encode(value)
        try data.write(to: file, options: .withoutOverwriting)
        chmod(file.path, mutation == .wrongMode ? 0o644 : 0o600)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
#endif
