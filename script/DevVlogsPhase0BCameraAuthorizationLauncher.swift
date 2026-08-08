#if DEBUG
import AppKit
import Darwin
import Foundation

private struct RunContext {
    static let resultName = "camera-authorization-launch.json"
    let runRoot: String
    let token: String

    static func parse(environment: [String: String]) -> Self? {
        guard let root = environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT"],
              root.hasPrefix("/"),
              let token = environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN"],
              token.count == 64, token.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        return Self(runRoot: root, token: token.lowercased())
    }
}

private struct LaunchArguments {
    let appURL: URL
    let executableURL: URL
    let bundleIdentifier: String
    let timeoutSeconds: Double

    static func parse(_ values: [String]) -> Self? {
        var fields: [String: String] = [:]
        var index = 1
        while index + 1 < values.count {
            guard fields[values[index]] == nil else { return nil }
            fields[values[index]] = values[index + 1]
            index += 2
        }
        guard index == values.count,
              Set(fields.keys) == ["--app-url", "--executable-url", "--bundle-id", "--timeout"],
              let app = fields["--app-url"], let executable = fields["--executable-url"],
              let identifier = fields["--bundle-id"],
              let rawTimeout = fields["--timeout"], let timeout = Double(rawTimeout),
              timeout.isFinite, timeout > 0, timeout <= 120 else { return nil }
        return Self(
            appURL: URL(fileURLWithPath: app).standardizedFileURL.resolvingSymlinksInPath(),
            executableURL: URL(fileURLWithPath: executable).standardizedFileURL.resolvingSymlinksInPath(),
            bundleIdentifier: identifier,
            timeoutSeconds: timeout
        )
    }
}

private struct RunningApplicationIdentity: Sendable {
    let bundleURL: URL?
    let executableURL: URL?
    let bundleIdentifier: String?
    let processIdentifier: pid_t

    init(_ application: NSRunningApplication) {
        bundleURL = application.bundleURL
        executableURL = application.executableURL
        bundleIdentifier = application.bundleIdentifier
        processIdentifier = application.processIdentifier
    }

    init(bundleURL: URL?, executableURL: URL?, bundleIdentifier: String?, processIdentifier: pid_t) {
        self.bundleURL = bundleURL
        self.executableURL = executableURL
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

private enum LaunchOutcome: Sendable {
    case success(RunningApplicationIdentity)
    case rejected
    case timedOut
    case cancelled
}

private final class LaunchGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<LaunchOutcome, Never>?
    private var terminal: LaunchOutcome?
    private var timeoutTask: Task<Void, Never>?

    func wait(
        timeoutSeconds: Double,
        launch: (@escaping @Sendable (RunningApplicationIdentity?) -> Void) -> Void
    ) async -> LaunchOutcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let earlyOutcome = lock.withLock { () -> LaunchOutcome? in
                    guard let terminal else {
                        self.continuation = continuation
                        return nil
                    }
                    return terminal
                }
                guard let earlyOutcome else {
                    let timeout = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(timeoutSeconds))
                        self?.finish(.timedOut)
                    }
                    lock.withLock { timeoutTask = timeout }
                    launch { [weak self] identity in
                        self?.finish(identity.map(LaunchOutcome.success) ?? .rejected)
                    }
                    return
                }
                continuation.resume(returning: earlyOutcome)
            }
        } onCancel: {
            finish(.cancelled)
        }
    }

    private func finish(_ outcome: LaunchOutcome) {
        let pair = lock.withLock { () -> (CheckedContinuation<LaunchOutcome, Never>?, Task<Void, Never>?)? in
            guard terminal == nil else { return nil }
            terminal = outcome
            let value = self.continuation
            self.continuation = nil
            let timeout = timeoutTask
            timeoutTask = nil
            return (value, timeout)
        }
        guard let pair else { return }
        pair.1?.cancel()
        pair.0?.resume(returning: outcome)
    }
}

private struct Result: Codable {
    let version: Int
    let category: String
    let bundleURLMatches: Bool
    let executableURLMatches: Bool
    let bundleIdentifierMatches: Bool
    let launchMonotonicMilliseconds: Int64
    let processDigest: String?

    private enum CodingKeys: String, CodingKey {
        case version, category
        case bundleURLMatches = "bundle_url_matches"
        case executableURLMatches = "executable_url_matches"
        case bundleIdentifierMatches = "bundle_identifier_matches"
        case launchMonotonicMilliseconds = "launch_monotonic_ms"
        case processDigest = "process_digest"
    }
}

private struct VerifiedResult {
    let category: String
    let bundleURLMatches: Bool
    let executableURLMatches: Bool
    let bundleIdentifierMatches: Bool
    let digestMatches: Bool

    var normalized: String {
        "category=\(category) bundle=\(bundleURLMatches) executable=\(executableURLMatches) "
            + "identifier=\(bundleIdentifierMatches) digest=\(digestMatches)"
    }
}

private struct ResultStore {
    let context: RunContext

    func publish(_ result: Result) -> Bool {
        guard let data = try? JSONEncoder().encode(result), (1 ... 1_024).contains(data.count),
              let rootFD = openRoot() else { return false }
        defer { Darwin.close(rootFD) }
        let temporary = ".launcher-result-\(UUID().uuidString)"
        var fileFD = Darwin.openat(
            rootFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600
        )
        guard fileFD >= 0 else { return false }
        var completed = false
        defer {
            if fileFD >= 0 { Darwin.close(fileFD) }
            if !completed { Darwin.unlinkat(rootFD, temporary, 0) }
        }
        guard fchmod(fileFD, 0o600) == 0, writeAll(data, to: fileFD), fsync(fileFD) == 0,
              Darwin.close(fileFD) == 0 else { return false }
        fileFD = -1
        completed = Darwin.linkat(rootFD, temporary, rootFD, RunContext.resultName, 0) == 0
        _ = Darwin.unlinkat(rootFD, temporary, 0)
        return completed
    }

    func verify(
        expectedPID: pid_t,
        afterOpen: ((Int32) -> Void)? = nil
    ) -> VerifiedResult? {
        guard let rootFD = openRoot() else { return nil }
        defer { Darwin.close(rootFD) }
        let fileFD = Darwin.openat(rootFD, RunContext.resultName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fileFD >= 0 else { return nil }
        defer { Darwin.close(fileFD) }
        var metadata = stat()
        guard fstat(fileFD, &metadata) == 0,
              (metadata.st_mode & S_IFMT) == S_IFREG,
              metadata.st_uid == getuid(), metadata.st_mode & 0o777 == 0o600,
              metadata.st_nlink == 1, (1 ... 1_024).contains(metadata.st_size) else { return nil }
        afterOpen?(rootFD)
        guard let data = readExactly(count: Int(metadata.st_size), from: fileFD),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["version", "category", "bundle_url_matches",
                                   "executable_url_matches", "bundle_identifier_matches",
                                   "launch_monotonic_ms", "process_digest"],
              object["version"] as? Int == 1,
              let category = object["category"] as? String,
              ["launched", "identity_mismatch", "launch_rejected",
               "launch_timed_out", "launch_cancelled"].contains(category),
              let bundle = object["bundle_url_matches"] as? Bool,
              let executable = object["executable_url_matches"] as? Bool,
              let identifier = object["bundle_identifier_matches"] as? Bool,
              let launchTime = object["launch_monotonic_ms"] as? Int64, launchTime >= 0 else { return nil }
        let expectedDigest = digest(token: context.token, pid: expectedPID)
        let processDigest = object["process_digest"] as? String
        let digestMatches = processDigest == expectedDigest
        if category == "launched" {
            guard bundle, executable, identifier, digestMatches else { return nil }
        } else if let processDigest {
            guard processDigest.count == 64,
                  processDigest.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        }
        return VerifiedResult(
            category: category, bundleURLMatches: bundle, executableURLMatches: executable,
            bundleIdentifierMatches: identifier, digestMatches: digestMatches
        )
    }

    private func openRoot() -> Int32? {
        let descriptor = Darwin.open(context.runRoot, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              (metadata.st_mode & S_IFMT) == S_IFDIR,
              metadata.st_uid == getuid(), metadata.st_mode & 0o777 == 0o700 else {
            Darwin.close(descriptor)
            return nil
        }
        return descriptor
    }

    private func writeAll(_ data: Data, to descriptor: Int32) -> Bool {
        data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(descriptor, bytes.baseAddress?.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { return false }
                offset += count
            }
            return true
        }
    }

    private func readExactly(count: Int, from descriptor: Int32) -> Data? {
        var data = Data(count: count)
        let complete = data.withUnsafeMutableBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let amount = Darwin.read(descriptor, bytes.baseAddress?.advanced(by: offset), bytes.count - offset)
                guard amount > 0 else { return false }
                offset += amount
            }
            var extra: UInt8 = 0
            return Darwin.read(descriptor, &extra, 1) == 0
        }
        return complete ? data : nil
    }
}

@main
private enum LauncherMain {
    static func main() async {
#if DEV_VLOGS_PHASE_0B_LAUNCHER_TESTING
        if CommandLine.arguments == [CommandLine.arguments[0], "--self-test"] {
            exit(await runSelfTests() ? 0 : 1)
        }
#endif
        let environment = ProcessInfo.processInfo.environment
        guard let context = RunContext.parse(environment: environment) else { exit(64) }
        if CommandLine.arguments == [CommandLine.arguments[0], "--verify-result"] {
            guard let rawPID = environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_EXPECTED_PID"],
                  let pid = pid_t(rawPID), pid > 0,
                  let verified = ResultStore(context: context).verify(expectedPID: pid) else { exit(65) }
            print(verified.normalized)
            exit(0)
        }
        guard let arguments = LaunchArguments.parse(CommandLine.arguments) else { exit(64) }
        let configuration = makeConfiguration()
        let started = Int64(ProcessInfo.processInfo.systemUptime * 1_000)
        let outcome = await LaunchGate().wait(timeoutSeconds: arguments.timeoutSeconds) { completion in
            NSWorkspace.shared.openApplication(
                at: arguments.appURL,
                configuration: configuration
            ) { application, _ in
                completion(application.map(RunningApplicationIdentity.init))
            }
        }
        let result = makeResult(outcome: outcome, arguments: arguments, context: context, started: started)
        guard ResultStore(context: context).publish(result) else { exit(74) }
        exit(result.category == "launched" ? 0 : 1)
    }

    private static func makeConfiguration(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        configuration.hides = false
        configuration.hidesOthers = false
        configuration.arguments = []
        configuration.allowsRunningApplicationSubstitution = false
        configuration.environment = allowlistedEnvironment(environment)
        return configuration
    }

    private static func makeResult(
        outcome: LaunchOutcome,
        arguments: LaunchArguments,
        context: RunContext,
        started: Int64
    ) -> Result {
        switch outcome {
        case .success(let identity):
            let bundleMatch = canonical(identity.bundleURL) == arguments.appURL
            let executableMatch = canonical(identity.executableURL) == arguments.executableURL
            let identifierMatch = identity.bundleIdentifier == arguments.bundleIdentifier
            return Result(
                version: 1,
                category: bundleMatch && executableMatch && identifierMatch ? "launched" : "identity_mismatch",
                bundleURLMatches: bundleMatch,
                executableURLMatches: executableMatch,
                bundleIdentifierMatches: identifierMatch,
                launchMonotonicMilliseconds: started,
                processDigest: digest(token: context.token, pid: identity.processIdentifier)
            )
        case .rejected:
            return failure("launch_rejected", started)
        case .timedOut:
            return failure("launch_timed_out", started)
        case .cancelled:
            return failure("launch_cancelled", started)
        }
    }

    private static func allowlistedEnvironment(_ environment: [String: String]) -> [String: String] {
        let keys = [
            "HOME", "TMPDIR", "PATH", "HOLDTYPE_AUTOMATION",
            "HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI",
            "HOLDTYPE_DEV_VLOGS_PHASE_0B_REQUEST_CAMERA_PERMISSION",
            "HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT",
            "HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID",
            "HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN",
        ]
        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            environment[key].map { (key, $0) }
        })
    }

    private static func canonical(_ url: URL?) -> URL? {
        url?.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func failure(_ category: String, _ started: Int64) -> Result {
        Result(version: 1, category: category, bundleURLMatches: false,
               executableURLMatches: false, bundleIdentifierMatches: false,
               launchMonotonicMilliseconds: started, processDigest: nil)
    }

#if DEV_VLOGS_PHASE_0B_LAUNCHER_TESTING
    private static func runSelfTests() async -> Bool {
        let token = String(repeating: "a", count: 64)
        let values = ["launcher", "--app-url", "/tmp/HoldType.app", "--executable-url",
                      "/tmp/HoldType.app/Contents/MacOS/HoldType", "--bundle-id", "com.holdtype.app",
                      "--timeout", "1"]
        let environment = ["HOME": "/tmp/home", "PRIVATE_SECRET": "forbidden",
                           "HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT": "/tmp/run",
                           "HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN": token]
        guard let arguments = LaunchArguments.parse(values),
              let context = RunContext.parse(environment: environment) else { return false }
        let configuration = makeConfiguration(environment: environment)
        guard configuration.activates, configuration.createsNewApplicationInstance,
              !configuration.addsToRecentItems, !configuration.promptsUserIfNeeded,
              !configuration.hides, !configuration.hidesOthers, configuration.arguments == [],
              configuration.environment["HOME"] == "/tmp/home",
              configuration.environment["PRIVATE_SECRET"] == nil else { return false }

        let identity = RunningApplicationIdentity(
            bundleURL: arguments.appURL,
            executableURL: arguments.executableURL,
            bundleIdentifier: arguments.bundleIdentifier,
            processIdentifier: 42
        )
        let success = await LaunchGate().wait(timeoutSeconds: 1) { callback in
            callback(identity)
            callback(nil)
        }
        guard case .success = success,
              makeResult(outcome: success, arguments: arguments, context: context, started: 1).category ==
                "launched",
              digest(token: token, pid: 42) ==
                "ba7b37304e3cb9f89a69f30ebdb57fcaff24f01516546bfb59c6f7bb63c1dbf1" else {
            return false
        }
        let rejection = await LaunchGate().wait(timeoutSeconds: 1) { $0(nil) }
        guard case .rejected = rejection else { return false }

        let lateCallback = CallbackBox()
        let timeoutGate = LaunchGate()
        let timedOut = await timeoutGate.wait(timeoutSeconds: 0.001) { lateCallback.store($0) }
        guard case .timedOut = timedOut else { return false }
        lateCallback.call(identity)
        let afterLate = await timeoutGate.wait(timeoutSeconds: 1) { $0(identity) }
        guard case .timedOut = afterLate else { return false }

        let cancellationGate = LaunchGate()
        let cancellationTask = Task {
            await cancellationGate.wait(timeoutSeconds: 120) { lateCallback.store($0) }
        }
        cancellationTask.cancel()
        guard case .cancelled = await cancellationTask.value else { return false }
        let root = NSTemporaryDirectory() + "holdtype-launcher-selftest-\(UUID().uuidString)"
        guard mkdir(root, 0o700) == 0 else { return false }
        defer { Darwin.unlink(root + "/" + RunContext.resultName); rmdir(root) }
        let store = ResultStore(context: .init(runRoot: root, token: token))
        let valid = makeResult(outcome: success, arguments: arguments, context: context, started: 1)
        guard store.publish(valid), !store.publish(valid),
              store.verify(expectedPID: 42)?.normalized ==
                "category=launched bundle=true executable=true identifier=true digest=true" else { return false }
        guard Darwin.unlink(root + "/" + RunContext.resultName) == 0, store.publish(valid) else { return false }
        let snapshot = store.verify(expectedPID: 42) { rootFD in
            _ = Darwin.unlinkat(rootFD, RunContext.resultName, 0)
            _ = store.publish(failure("launch_rejected", 1))
        }
        guard snapshot?.category == "launched" else { return false }
        return true
    }
#endif
}

#if DEV_VLOGS_PHASE_0B_LAUNCHER_TESTING
private final class CallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (@Sendable (RunningApplicationIdentity?) -> Void)?

    func store(_ callback: @escaping @Sendable (RunningApplicationIdentity?) -> Void) {
        lock.withLock { self.callback = callback }
    }

    func call(_ identity: RunningApplicationIdentity?) {
        lock.withLock { callback }?(identity)
    }
}
#endif

private func digest(token: String, pid: pid_t) -> String {
    SHA256.hex(Data("\(token):\(pid)".utf8))
}

private enum SHA256 {
    private static let initial: [UInt32] = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    ]
    static func hex(_ input: Data) -> String {
        var message = input; let bits = UInt64(message.count) * 8; message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        withUnsafeBytes(of: bits.bigEndian) { message.append(contentsOf: $0) }
        var hash = initial
        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 64)
            for index in 0..<16 { let start = offset + index * 4; words[index] = message[start..<start+4].reduce(0) { ($0 << 8) | UInt32($1) } }
            for index in 16..<64 { let s0 = rotate(words[index-15],7)^rotate(words[index-15],18)^(words[index-15]>>3); let s1 = rotate(words[index-2],17)^rotate(words[index-2],19)^(words[index-2]>>10); words[index] = words[index-16]&+s0&+words[index-7]&+s1 }
            var v = hash
            for index in 0..<64 { let s1=rotate(v[4],6)^rotate(v[4],11)^rotate(v[4],25); let ch=(v[4]&v[5])^(~v[4]&v[6]); let t1=v[7]&+s1&+ch&+constants[index]&+words[index]; let s0=rotate(v[0],2)^rotate(v[0],13)^rotate(v[0],22); let maj=(v[0]&v[1])^(v[0]&v[2])^(v[1]&v[2]); let t2=s0&+maj; v=[t1&+t2,v[0],v[1],v[2],v[3]&+t1,v[4],v[5],v[6]] }
            for index in 0..<8 { hash[index] &+= v[index] }
        }
        return hash.map { String(format: "%08x", $0) }.joined()
    }
    private static func rotate(_ value: UInt32, _ count: UInt32) -> UInt32 { (value >> count) | (value << (32-count)) }
}
#endif
