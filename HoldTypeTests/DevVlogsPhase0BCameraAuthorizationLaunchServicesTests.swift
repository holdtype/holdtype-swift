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
                      "process_digest", "O_EXCL", "O_NOFOLLOW", "runSelfTests()"] {
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
                      "permission_launcher_result", "expected_process_digest", "shasum -a 256",
                      "camera-authorization-ack.json", "set -o noclobber", "permission_terminal_observed",
                      "stat -f '%u:%Lp:%HT:%l:%z'", "permission_deadline", "timeout_command \"$REPLY\" ln"] {
            #expect(script.contains(token))
        }
        #expect(!script.contains("\"$app_binary\" >\"$permission_operator_log\""))
        for forbidden in ["killall", "pkill", "pgrep", "tccutil", "osascript"] {
            #expect(!script.contains(forbidden))
        }
        #expect(!script.contains("--token \"$permission_launch_token\""))
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
