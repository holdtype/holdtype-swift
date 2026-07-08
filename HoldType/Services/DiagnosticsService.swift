//
//  DiagnosticsService.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit
import Foundation
import OSLog

enum DiagnosticReportsDirectoryStatus: Equatable {
    case available
    case missing
}

struct DiagnosticReportItem: Equatable, Identifiable {
    var id: String {
        fileURL.path
    }

    let fileURL: URL
    let byteCount: Int64
    let createdAt: Date

    var fileName: String {
        fileURL.lastPathComponent
    }
}

struct DiagnosticReportSummary: Equatable {
    let directoryURL: URL
    let directoryStatus: DiagnosticReportsDirectoryStatus
    let items: [DiagnosticReportItem]

    var fileCount: Int {
        items.count
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}

struct DiagnosticAppMetadata: Codable, Equatable {
    let appName: String
    let bundleIdentifier: String
    let appVersion: String
    let buildNumber: String

    static func current(bundle: Bundle = .main) -> DiagnosticAppMetadata {
        DiagnosticAppMetadata(
            appName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "HoldType",
            bundleIdentifier: bundle.bundleIdentifier ?? "app.holdtype.HoldType",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }
}

struct DiagnosticBundleManifest: Codable, Equatable {
    let createdAt: Date
    let app: DiagnosticAppMetadata
    let diagnosticReportsDirectoryPath: String
    let includedCrashReportFileNames: [String]
    let includedRuntimeLogFileNames: [String]
    let runtimeLogLineCount: Int
    let excludedContent: [String]
}

struct DiagnosticBundleResult: Equatable {
    let bundleURL: URL
    let includedCrashReports: [DiagnosticReportItem]
    let runtimeLogExport: RuntimeDiagnosticLogExport?
}

enum DiagnosticsLogEvent: Equatable {
    case crashReportRefreshCompleted(reportCount: Int)
    case crashReportRefreshMissingDirectory
    case crashReportRefreshFailed
    case diagnosticBundleExported(reportCount: Int)
    case diagnosticBundleExportFailed
    case diagnosticRevealRequested
    case diagnosticPathCopied
}

protocol DiagnosticsEventLogging {
    func record(_ event: DiagnosticsLogEvent)
}

struct OSLogDiagnosticsEventLogger: DiagnosticsEventLogging {
    private let logger: Logger
    private let runtimeLogRecorder: any RuntimeDiagnosticLogRecording

    init(
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "app.holdtype.HoldType",
            category: "Diagnostics"
        ),
        runtimeLogRecorder: any RuntimeDiagnosticLogRecording = RuntimeDiagnosticsLogStore.shared
    ) {
        self.logger = logger
        self.runtimeLogRecorder = runtimeLogRecorder
    }

    func record(_ event: DiagnosticsLogEvent) {
        switch event {
        case .crashReportRefreshCompleted(let reportCount):
            logger.info("Crash report refresh completed: \(reportCount, privacy: .public) reports")
        case .crashReportRefreshMissingDirectory:
            logger.info("Crash report refresh completed: missing directory")
        case .crashReportRefreshFailed:
            logger.error("Crash report refresh failed")
        case .diagnosticBundleExported(let reportCount):
            logger.info("Diagnostic bundle exported: \(reportCount, privacy: .public) reports")
        case .diagnosticBundleExportFailed:
            logger.error("Diagnostic bundle export failed")
        case .diagnosticRevealRequested:
            logger.info("Diagnostic reveal requested")
        case .diagnosticPathCopied:
            logger.info("Diagnostic path copied")
        }

        runtimeLogRecorder.record(event.runtimeDiagnosticEvent)
    }
}

private extension DiagnosticsLogEvent {
    var runtimeDiagnosticEvent: RuntimeDiagnosticEvent {
        switch self {
        case .crashReportRefreshCompleted(let reportCount):
            return RuntimeDiagnosticEvent(
                category: "diagnostics",
                name: "crash_report_refresh_completed",
                fields: ["report_count": String(reportCount)]
            )
        case .crashReportRefreshMissingDirectory:
            return RuntimeDiagnosticEvent(
                category: "diagnostics",
                name: "crash_report_refresh_missing_directory"
            )
        case .crashReportRefreshFailed:
            return RuntimeDiagnosticEvent(
                category: "diagnostics",
                name: "crash_report_refresh_failed",
                severity: .error
            )
        case .diagnosticBundleExported(let reportCount):
            return RuntimeDiagnosticEvent(
                category: "diagnostics",
                name: "diagnostic_bundle_exported",
                fields: ["report_count": String(reportCount)]
            )
        case .diagnosticBundleExportFailed:
            return RuntimeDiagnosticEvent(
                category: "diagnostics",
                name: "diagnostic_bundle_export_failed",
                severity: .error
            )
        case .diagnosticRevealRequested:
            return RuntimeDiagnosticEvent(category: "diagnostics", name: "diagnostic_reveal_requested")
        case .diagnosticPathCopied:
            return RuntimeDiagnosticEvent(category: "diagnostics", name: "diagnostic_path_copied")
        }
    }
}

enum DiagnosticsServiceError: Error, Equatable, LocalizedError {
    case listingFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .listingFailed:
            return "Crash reports could not be read."
        case .exportFailed:
            return "Diagnostic bundle could not be exported."
        }
    }
}

protocol DiagnosticsManaging {
    var diagnosticReportsDirectoryURL: URL { get }
    var diagnosticBundlesDirectoryURL: URL { get }
    var runtimeLogsDirectoryURL: URL { get }

    func summary() throws -> DiagnosticReportSummary
    func runtimeLogSummary(limit: Int) throws -> DiagnosticRuntimeLogSummary
    func exportDiagnosticBundle() throws -> DiagnosticBundleResult
    func revealInFinder(_ fileURL: URL)
    func copyPath(_ fileURL: URL)
}

struct DiagnosticsService: DiagnosticsManaging {
    static let shared = DiagnosticsService()

    private static let supportedCrashReportExtensions = Set(["ips", "crash"])
    private static let maximumCrashReportsInBundle = 5
    private static let runtimeLogExportWindow: TimeInterval = 48 * 60 * 60

    let diagnosticReportsDirectoryURL: URL
    let diagnosticBundlesDirectoryURL: URL
    var runtimeLogsDirectoryURL: URL {
        runtimeLogStore.directoryURL
    }

    private let fileManager: FileManager
    private let now: () -> Date
    private let uuidProvider: () -> UUID
    private let appMetadataProvider: () -> DiagnosticAppMetadata
    private let eventLogger: any DiagnosticsEventLogging
    private let runtimeLogStore: any RuntimeDiagnosticLogManaging

    init(
        diagnosticReportsDirectoryURL: URL? = nil,
        diagnosticBundlesDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        uuidProvider: @escaping () -> UUID = UUID.init,
        appMetadataProvider: @escaping () -> DiagnosticAppMetadata = { DiagnosticAppMetadata.current() },
        eventLogger: any DiagnosticsEventLogging = OSLogDiagnosticsEventLogger(),
        runtimeLogStore: any RuntimeDiagnosticLogManaging = RuntimeDiagnosticsLogStore.shared
    ) {
        self.fileManager = fileManager
        self.diagnosticReportsDirectoryURL = diagnosticReportsDirectoryURL
            ?? Self.defaultDiagnosticReportsDirectoryURL(fileManager: fileManager)
        self.diagnosticBundlesDirectoryURL = diagnosticBundlesDirectoryURL
            ?? Self.defaultDiagnosticBundlesDirectoryURL(fileManager: fileManager)
        self.now = now
        self.uuidProvider = uuidProvider
        self.appMetadataProvider = appMetadataProvider
        self.eventLogger = eventLogger
        self.runtimeLogStore = runtimeLogStore
    }

    func summary() throws -> DiagnosticReportSummary {
        let directoryURL = diagnosticReportsDirectoryURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            eventLogger.record(.crashReportRefreshMissingDirectory)
            return DiagnosticReportSummary(
                directoryURL: directoryURL,
                directoryStatus: .missing,
                items: []
            )
        }

        guard isDirectory.boolValue else {
            eventLogger.record(.crashReportRefreshFailed)
            throw DiagnosticsServiceError.listingFailed
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            let items = fileURLs.compactMap(diagnosticReportItem(for:))
                .sorted { lhs, rhs in
                    lhs.createdAt > rhs.createdAt
                }

            eventLogger.record(.crashReportRefreshCompleted(reportCount: items.count))
            return DiagnosticReportSummary(
                directoryURL: directoryURL,
                directoryStatus: .available,
                items: items
            )
        } catch {
            eventLogger.record(.crashReportRefreshFailed)
            throw DiagnosticsServiceError.listingFailed
        }
    }

    func runtimeLogSummary(limit: Int) throws -> DiagnosticRuntimeLogSummary {
        DiagnosticRuntimeLogSummary(
            directoryURL: runtimeLogStore.directoryURL,
            recentLines: try runtimeLogStore.recentLogLines(limit: limit)
        )
    }

    func exportDiagnosticBundle() throws -> DiagnosticBundleResult {
        do {
            let currentSummary = try summary()
            try fileManager.createDirectory(
                at: diagnosticBundlesDirectoryURL,
                withIntermediateDirectories: true
            )

            let bundleURL = diagnosticBundlesDirectoryURL
                .appendingPathComponent(bundleDirectoryName(), isDirectory: true)
            let crashReportsURL = bundleURL.appendingPathComponent("CrashReports", isDirectory: true)
            try fileManager.createDirectory(at: crashReportsURL, withIntermediateDirectories: true)

            let includedReports = try copyCrashReports(
                currentSummary.items.prefix(Self.maximumCrashReportsInBundle),
                to: crashReportsURL
            )
            let runtimeLogExport = try? runtimeLogStore.exportRecentLogs(
                to: bundleURL,
                since: now().addingTimeInterval(-Self.runtimeLogExportWindow)
            )
            let manifest = DiagnosticBundleManifest(
                createdAt: now(),
                app: appMetadataProvider(),
                diagnosticReportsDirectoryPath: currentSummary.directoryURL.path,
                includedCrashReportFileNames: includedReports.map(\.fileName),
                includedRuntimeLogFileNames: runtimeLogExport.map { [$0.relativePath] } ?? [],
                runtimeLogLineCount: runtimeLogExport?.lineCount ?? 0,
                excludedContent: Self.excludedContentDescriptions
            )

            try writeManifest(manifest, to: bundleURL)
            try writeReadme(manifest: manifest, to: bundleURL)

            eventLogger.record(.diagnosticBundleExported(reportCount: includedReports.count))
            return DiagnosticBundleResult(
                bundleURL: bundleURL,
                includedCrashReports: includedReports,
                runtimeLogExport: runtimeLogExport
            )
        } catch let error as DiagnosticsServiceError {
            eventLogger.record(.diagnosticBundleExportFailed)
            throw error
        } catch {
            eventLogger.record(.diagnosticBundleExportFailed)
            throw DiagnosticsServiceError.exportFailed
        }
    }

    func revealInFinder(_ fileURL: URL) {
        eventLogger.record(.diagnosticRevealRequested)

        if isDirectory(at: fileURL) {
            NSWorkspace.shared.open(fileURL)
            return
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            return
        }

        let parentURL = fileURL.deletingLastPathComponent()
        if isDirectory(at: parentURL) {
            NSWorkspace.shared.open(parentURL)
        }
    }

    func copyPath(_ fileURL: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL.path, forType: .string)
        eventLogger.record(.diagnosticPathCopied)
    }

    private func diagnosticReportItem(for fileURL: URL) -> DiagnosticReportItem? {
        guard isSupportedHoldTypeReport(fileURL) else {
            return nil
        }

        guard let values = try? fileURL.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ),
            values.isRegularFile == true else {
            return nil
        }

        return DiagnosticReportItem(
            fileURL: fileURL,
            byteCount: Int64(values.fileSize ?? 0),
            createdAt: values.creationDate ?? values.contentModificationDate ?? .distantPast
        )
    }

    private func isSupportedHoldTypeReport(_ fileURL: URL) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        guard Self.supportedCrashReportExtensions.contains(fileExtension) else {
            return false
        }

        let fileName = fileURL.lastPathComponent.lowercased()
        return fileName.hasPrefix("holdtype")
            || fileName.hasPrefix("app.holdtype.holdtype")
            || fileName.contains("app.holdtype.holdtype")
    }

    private func copyCrashReports(
        _ reports: ArraySlice<DiagnosticReportItem>,
        to crashReportsURL: URL
    ) throws -> [DiagnosticReportItem] {
        var includedReports: [DiagnosticReportItem] = []

        for report in reports {
            let destinationURL = crashReportsURL.appendingPathComponent(report.fileName)

            guard fileManager.fileExists(atPath: report.fileURL.path) else {
                throw DiagnosticsServiceError.exportFailed
            }

            do {
                try fileManager.copyItem(at: report.fileURL, to: destinationURL)
                includedReports.append(report)
            } catch {
                throw DiagnosticsServiceError.exportFailed
            }
        }

        return includedReports
    }

    private func writeManifest(_ manifest: DiagnosticBundleManifest, to bundleURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let manifestURL = bundleURL.appendingPathComponent("manifest.json")
            try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        } catch {
            throw DiagnosticsServiceError.exportFailed
        }
    }

    private func writeReadme(manifest: DiagnosticBundleManifest, to bundleURL: URL) throws {
        let readme = """
        HoldType Diagnostic Bundle

        Created: \(ISO8601DateFormatter().string(from: manifest.createdAt))
        App: \(manifest.app.appName)
        Bundle ID: \(manifest.app.bundleIdentifier)
        Version: \(manifest.app.appVersion) (\(manifest.app.buildNumber))

        Included crash reports: \(manifest.includedCrashReportFileNames.count)
        Included runtime log lines: \(manifest.runtimeLogLineCount)

        This bundle is local-only. It excludes API keys, transcripts, prompts,
        dictionary entries, nearby text context, raw audio, provider payloads,
        authorization headers, and full provider responses.
        """

        do {
            try readme.write(
                to: bundleURL.appendingPathComponent("README.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw DiagnosticsServiceError.exportFailed
        }
    }

    private func bundleDirectoryName() -> String {
        let uuidPrefix = String(uuidProvider().uuidString.prefix(8)).lowercased()
        return "HoldType-Diagnostics-\(Self.fileTimestamp(from: now()))-\(uuidPrefix)"
    }

    private func isDirectory(at fileURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static let excludedContentDescriptions = [
        "API keys",
        "authorization headers",
        "transcripts",
        "prompts",
        "custom dictionary contents",
        "nearby text context",
        "raw audio",
        "provider payloads",
        "full provider responses",
    ]

    private static func defaultDiagnosticReportsDirectoryURL(fileManager: FileManager) -> URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)

        return libraryURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DiagnosticReports", isDirectory: true)
    }

    private static func defaultDiagnosticBundlesDirectoryURL(fileManager: FileManager) -> URL {
        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return cachesRoot
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
