import Foundation
import MetricKit
import UIKit

nonisolated struct IOSMetricDiagnosticRecord: Codable, Equatable, Sendable {
    let receivedAt: Date
    let intervalStart: Date
    let intervalEnd: Date
    let crashCount: Int
    let hangCount: Int
    let cpuExceptionCount: Int
    let diskWriteCount: Int
    let payloadJSON: String

    var totalCount: Int {
        crashCount + hangCount + cpuExceptionCount + diskWriteCount
    }
}

nonisolated final class IOSMetricDiagnosticStore: @unchecked Sendable {
    private let directoryURL: URL?
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let maximumAge: TimeInterval
    private let lock = NSLock()

    init(
        rootDirectoryURL: URL? = IOSDiagnosticsStorage.rootDirectoryURL(),
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        maximumAge: TimeInterval = 7 * 24 * 60 * 60
    ) {
        directoryURL = rootDirectoryURL?
            .appendingPathComponent("MetricKit", isDirectory: true)
        self.fileManager = fileManager
        self.now = now
        self.maximumAge = maximumAge
    }

    func store(_ record: IOSMetricDiagnosticRecord) throws {
        guard record.totalCount > 0, let directoryURL else { return }
        try lock.withLock {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try excludeFromBackup(directoryURL)
            let fileURL = directoryURL.appendingPathComponent(
                "metric-\(Self.fileTimestamp(record.receivedAt))-\(UUID().uuidString).json"
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(record).write(
                to: fileURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            try excludeFromBackup(fileURL)
            try pruneLocked()
        }
    }

    func records() throws -> [IOSMetricDiagnosticRecord] {
        try lock.withLock {
            try pruneLocked()
            guard let directoryURL,
                  fileManager.fileExists(atPath: directoryURL.path) else {
                return []
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL in
                guard let data = try? Data(contentsOf: fileURL) else {
                    return nil
                }
                return try? decoder.decode(
                    IOSMetricDiagnosticRecord.self,
                    from: data
                )
            }
            .sorted { $0.receivedAt < $1.receivedAt }
        }
    }

    private func pruneLocked() throws {
        guard let directoryURL,
              fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }
        let cutoff = now().addingTimeInterval(-maximumAge)
        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        for fileURL in files {
            let values = try fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            )
            let recordDate = (try? Data(contentsOf: fileURL))
                .flatMap { data -> IOSMetricDiagnosticRecord? in
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try? decoder.decode(
                        IOSMetricDiagnosticRecord.self,
                        from: data
                    )
                }?
                .receivedAt
                ?? values.contentModificationDate
                ?? .distantPast
            if recordDate < cutoff {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

nonisolated final class IOSMetricKitDiagnosticCollector:
    NSObject,
    MXMetricManagerSubscriber,
    @unchecked Sendable
{
    static let shared = IOSMetricKitDiagnosticCollector()

    private let store: IOSMetricDiagnosticStore
    private let runtimeLog: IOSRuntimeDiagnosticsStore
    private let lock = NSLock()
    private var isStarted = false

    init(
        store: IOSMetricDiagnosticStore = IOSMetricDiagnosticStore(),
        runtimeLog: IOSRuntimeDiagnosticsStore = .app
    ) {
        self.store = store
        self.runtimeLog = runtimeLog
    }

    func start() {
        let shouldStart = lock.withLock {
            guard !isStarted else { return false }
            isStarted = true
            return true
        }
        guard shouldStart else { return }
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // Daily performance aggregates are outside the diagnostics contract.
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            let cpuCount = payload.cpuExceptionDiagnostics?.count ?? 0
            let diskCount = payload.diskWriteExceptionDiagnostics?.count ?? 0
            guard crashCount + hangCount + cpuCount + diskCount > 0,
                  let payloadJSON = String(
                    data: payload.jsonRepresentation(),
                    encoding: .utf8
                  ) else {
                continue
            }
            let record = IOSMetricDiagnosticRecord(
                receivedAt: Date(),
                intervalStart: payload.timeStampBegin,
                intervalEnd: payload.timeStampEnd,
                crashCount: crashCount,
                hangCount: hangCount,
                cpuExceptionCount: cpuCount,
                diskWriteCount: diskCount,
                payloadJSON: payloadJSON
            )
            try? store.store(record)
            recordRuntimeEvents(record)
        }
    }

    private func recordRuntimeEvents(_ record: IOSMetricDiagnosticRecord) {
        let counts: [(IOSDiagnosticMetricKind, Int)] = [
            (.crash, record.crashCount),
            (.hang, record.hangCount),
            (.cpuException, record.cpuExceptionCount),
            (.diskWrite, record.diskWriteCount),
        ]
        for (kind, count) in counts where count > 0 {
            runtimeLog.record(
                .metricDiagnosticsReceived(kind, count: count)
            )
        }
    }
}

nonisolated struct IOSDiagnosticsMetadata: Equatable, Sendable {
    let appVersion: String
    let buildNumber: String
    let operatingSystem: String
    let deviceFamily: String

    @MainActor
    static func current(bundle: Bundle = .main) -> Self {
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let build = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
        let family = switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            "iPad"
        case .phone:
            "iPhone"
        default:
            "iOS device"
        }
        return Self(
            appVersion: version,
            buildNumber: build,
            operatingSystem: UIDevice.current.systemName
                + " "
                + UIDevice.current.systemVersion,
            deviceFamily: family
        )
    }
}

nonisolated struct IOSDiagnosticsSnapshot: Equatable, Sendable {
    let metadata: IOSDiagnosticsMetadata
    let appLines: [String]
    let keyboardLines: [String]
    let metricRecords: [IOSMetricDiagnosticRecord]
    let runtimeReadFailed: Bool

    var recentLines: [String] {
        Array((appLines + keyboardLines).sorted().suffix(100))
    }

    var runtimeEventCount: Int {
        appLines.count + keyboardLines.count
    }

    var crashCount: Int {
        metricRecords.reduce(0) { $0 + $1.crashCount }
    }

    var hangCount: Int {
        metricRecords.reduce(0) { $0 + $1.hangCount }
    }
}

nonisolated final class IOSDiagnosticsService: @unchecked Sendable {
    private let appLog: IOSRuntimeDiagnosticsStore
    private let keyboardLog: IOSRuntimeDiagnosticsStore
    private let metricStore: IOSMetricDiagnosticStore
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let exportDirectoryURL: URL

    init(
        appLog: IOSRuntimeDiagnosticsStore = .app,
        keyboardLog: IOSRuntimeDiagnosticsStore = .keyboard,
        metricStore: IOSMetricDiagnosticStore = IOSMetricDiagnosticStore(),
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        exportDirectoryURL: URL? = nil
    ) {
        self.appLog = appLog
        self.keyboardLog = keyboardLog
        self.metricStore = metricStore
        self.fileManager = fileManager
        self.now = now
        self.exportDirectoryURL = exportDirectoryURL
            ?? fileManager.temporaryDirectory.appendingPathComponent(
                "HoldType-Diagnostics",
                isDirectory: true
            )
    }

    func snapshot(metadata: IOSDiagnosticsMetadata) -> IOSDiagnosticsSnapshot {
        var readFailed = false
        let appLines: [String]
        let keyboardLines: [String]
        let metricRecords: [IOSMetricDiagnosticRecord]
        do {
            appLines = try appLog.recentLines(limit: 1_000)
        } catch {
            appLines = []
            readFailed = true
        }
        do {
            keyboardLines = try keyboardLog.recentLines(limit: 1_000)
        } catch {
            keyboardLines = []
            readFailed = true
        }
        do {
            metricRecords = try metricStore.records()
        } catch {
            metricRecords = []
            readFailed = true
        }
        return IOSDiagnosticsSnapshot(
            metadata: metadata,
            appLines: appLines,
            keyboardLines: keyboardLines,
            metricRecords: metricRecords,
            runtimeReadFailed: readFailed
        )
    }

    func copyText(from snapshot: IOSDiagnosticsSnapshot) -> String {
        guard !snapshot.recentLines.isEmpty else {
            return "No HoldType runtime events have been recorded yet."
        }
        return snapshot.recentLines.joined(separator: "\n")
    }

    func makeDiagnosticFile(
        from snapshot: IOSDiagnosticsSnapshot
    ) throws -> URL {
        do {
            try fileManager.createDirectory(
                at: exportDirectoryURL,
                withIntermediateDirectories: true
            )
            try removePreviousExports()
            let fileURL = exportDirectoryURL.appendingPathComponent(
                "HoldType-Diagnostics-\(Self.fileTimestamp(now())).txt"
            )
            try diagnosticText(snapshot).write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
            appLog.record(.diagnosticsExported(.succeeded))
            return fileURL
        } catch {
            appLog.record(.diagnosticsExported(.failed))
            throw error
        }
    }

    private func diagnosticText(_ snapshot: IOSDiagnosticsSnapshot) -> String {
        var sections = [
            "HoldType Diagnostics",
            "Created: \(Self.isoTimestamp(now()))",
            "App version: \(snapshot.metadata.appVersion)",
            "Build: \(snapshot.metadata.buildNumber)",
            "Operating system: \(snapshot.metadata.operatingSystem)",
            "Device family: \(snapshot.metadata.deviceFamily)",
            "",
            "Privacy",
            "This file excludes dictated text, transcripts, prompts, API keys, "
                + "dictionary content, raw audio, host-app identity, and "
                + "provider payloads.",
            "",
            "Runtime Events (last 48 hours)",
        ]
        let cutoff = now().addingTimeInterval(-48 * 60 * 60)
        let recentLines = ((try? appLog.recentLines(limit: 2_000, since: cutoff)) ?? [])
            + ((try? keyboardLog.recentLines(limit: 2_000, since: cutoff)) ?? [])
        if recentLines.isEmpty {
            sections.append("No runtime events recorded.")
        } else {
            sections.append(contentsOf: recentLines.sorted())
        }
        sections.append("")
        sections.append("Delivered Crash and Hang Diagnostics")
        if snapshot.metricRecords.isEmpty {
            sections.append("No crash diagnostics have been delivered to HoldType.")
        } else {
            for record in snapshot.metricRecords {
                sections.append(
                    "Received \(Self.isoTimestamp(record.receivedAt)); "
                        + "crashes=\(record.crashCount) "
                        + "hangs=\(record.hangCount) "
                        + "cpu_exceptions=\(record.cpuExceptionCount) "
                        + "disk_writes=\(record.diskWriteCount)"
                )
                sections.append(record.payloadJSON)
            }
        }
        return sections.joined(separator: "\n") + "\n"
    }

    private func removePreviousExports() throws {
        guard fileManager.fileExists(atPath: exportDirectoryURL.path) else {
            return
        }
        for fileURL in try fileManager.contentsOfDirectory(
            at: exportDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) where fileURL.lastPathComponent.hasPrefix("HoldType-Diagnostics-") {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return formatter.string(from: date)
    }
}
