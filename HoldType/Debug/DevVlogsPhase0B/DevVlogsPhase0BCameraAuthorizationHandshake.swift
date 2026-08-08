#if DEBUG
import Darwin
import Foundation

enum DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome: Equatable {
    case acknowledged
    case invalid
    case timedOut
    case cancelled
}

protocol DevVlogsPhase0BCameraAuthorizationAcknowledging: Sendable {
    func waitForAcknowledgment() async -> DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome
}

struct DevVlogsPhase0BCameraAuthorizationHandshake: DevVlogsPhase0BCameraAuthorizationAcknowledging {
    typealias Sleep = @Sendable (Duration) async throws -> Void
    static let fileName = "camera-authorization-ack.json"
    static let operationalTimeout = Duration.seconds(120)

    let configuration: DevVlogsPhase0BCameraAuthorizationConfiguration
    let timeout: Duration
    let sleep: Sleep
    private let read: @Sendable () -> ReadResult

    init(
        configuration: DevVlogsPhase0BCameraAuthorizationConfiguration,
        timeout: Duration = operationalTimeout,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        read: (@Sendable () -> ReadResult)? = nil
    ) {
        self.configuration = configuration
        self.timeout = timeout
        self.sleep = sleep
        self.read = read ?? { Self.readFile(configuration: configuration) }
    }

    func waitForAcknowledgment() async -> DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        var accepted: Acknowledgment?
        while ContinuousClock.now < deadline {
            guard !Task.isCancelled else { return .cancelled }
            switch read() {
            case .missing:
                do { try await sleep(.milliseconds(50)) } catch { return .cancelled }
            case .invalid:
                return .invalid
            case .value(let value):
                guard value == expectedAcknowledgment else { return .invalid }
                if let accepted {
                    return accepted == value ? .acknowledged : .invalid
                }
                accepted = value
                do { try await sleep(.milliseconds(10)) } catch { return .cancelled }
            }
        }
        return accepted == nil ? .timedOut : .invalid
    }

    var expectedAcknowledgment: Acknowledgment {
        Acknowledgment(
            version: 1,
            token: configuration.launchToken,
            processDigest: Self.processDigest(token: configuration.launchToken, pid: getpid())
        )
    }

    static func processDigest(token: String, pid: pid_t) -> String {
        SHA256.hex(Data("\(token):\(pid)".utf8))
    }

    enum ReadResult: Equatable, Sendable {
        case missing
        case invalid
        case value(Acknowledgment)
    }

    struct Acknowledgment: Codable, Equatable, Sendable {
        let version: Int
        let token: String
        let processDigest: String

        private enum CodingKeys: String, CodingKey {
            case version, token
            case processDigest = "process_digest"
        }
    }

    private static func readFile(
        configuration: DevVlogsPhase0BCameraAuthorizationConfiguration
    ) -> ReadResult {
        let rootFD = Darwin.open(
            configuration.runRoot.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard rootFD >= 0 else { return .invalid }
        defer { Darwin.close(rootFD) }
        var rootStat = stat()
        guard fstat(rootFD, &rootStat) == 0,
              (rootStat.st_mode & S_IFMT) == S_IFDIR,
              rootStat.st_uid == getuid(),
              rootStat.st_mode & 0o777 == 0o700 else { return .invalid }

        let fileFD = Darwin.openat(
            rootFD,
            fileName,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        if fileFD < 0 { return errno == ENOENT ? .missing : .invalid }
        defer { Darwin.close(fileFD) }
        var fileStat = stat()
        guard fstat(fileFD, &fileStat) == 0,
              (fileStat.st_mode & S_IFMT) == S_IFREG,
              fileStat.st_uid == getuid(),
              fileStat.st_mode & 0o777 == 0o600,
              fileStat.st_nlink == 1,
              (1 ... 1_024).contains(fileStat.st_size) else { return .invalid }

        var data = Data(count: Int(fileStat.st_size))
        let count = data.withUnsafeMutableBytes { buffer in
            Darwin.read(fileFD, buffer.baseAddress, buffer.count)
        }
        guard count == data.count,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["version", "token", "process_digest"],
              let acknowledgment = try? JSONDecoder().decode(Acknowledgment.self, from: data)
        else { return .invalid }
        return .value(acknowledgment)
    }
}

private enum SHA256 {
    private static let initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    ]

    static func hex(_ input: Data) -> String {
        var message = input
        let bitCount = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        withUnsafeBytes(of: bitCount.bigEndian) { message.append(contentsOf: $0) }
        var hash = initial
        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 64)
            for index in 0 ..< 16 {
                let start = offset + index * 4
                words[index] = message[start ..< start + 4].reduce(0) { ($0 << 8) | UInt32($1) }
            }
            for index in 16 ..< 64 {
                let s0 = rotate(words[index - 15], 7) ^ rotate(words[index - 15], 18) ^ (words[index - 15] >> 3)
                let s1 = rotate(words[index - 2], 17) ^ rotate(words[index - 2], 19) ^ (words[index - 2] >> 10)
                words[index] = words[index - 16] &+ s0 &+ words[index - 7] &+ s1
            }
            var values = hash
            for index in 0 ..< 64 {
                let s1 = rotate(values[4], 6) ^ rotate(values[4], 11) ^ rotate(values[4], 25)
                let choice = (values[4] & values[5]) ^ (~values[4] & values[6])
                let temporary1 = values[7] &+ s1 &+ choice &+ constants[index] &+ words[index]
                let s0 = rotate(values[0], 2) ^ rotate(values[0], 13) ^ rotate(values[0], 22)
                let majority = (values[0] & values[1]) ^ (values[0] & values[2]) ^ (values[1] & values[2])
                let temporary2 = s0 &+ majority
                values = [temporary1 &+ temporary2, values[0], values[1], values[2],
                          values[3] &+ temporary1, values[4], values[5], values[6]]
            }
            for index in 0 ..< 8 { hash[index] &+= values[index] }
        }
        return hash.map { String(format: "%08x", $0) }.joined()
    }

    private static func rotate(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}
#endif
