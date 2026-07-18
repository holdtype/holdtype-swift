//
//  DiagnosticsServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/6/26.
//

import Foundation
import Testing
@testable import HoldType

struct DiagnosticsServiceTests {

    @Test func summaryListsHoldTypeCrashReportsNewestFirst() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let service = DiagnosticsService(
            diagnosticReportsDirectoryURL: reportsURL,
            diagnosticBundlesDirectoryURL: rootURL.appendingPathComponent("Bundles", isDirectory: true),
            runtimeLogStore: RuntimeDiagnosticsLogStore(
                directoryURL: rootURL.appendingPathComponent("RuntimeLogs", isDirectory: true)
            )
        )
        let olderURL = try writeReport(named: "HoldType-2026-07-06-120000.ips", bytes: 3, in: reportsURL)
        let newerURL = try writeReport(named: "app.holdtype.HoldType-2026-07-06-130000.crash", bytes: 5, in: reportsURL)
        _ = try writeReport(named: "OtherApp-2026-07-06.ips", bytes: 10, in: reportsURL)
        _ = try writeReport(named: "HoldType-note.txt", bytes: 10, in: reportsURL)
        try setDates(fileURL: olderURL, timestamp: 10)
        try setDates(fileURL: newerURL, timestamp: 20)

        let summary = try service.summary()

        #expect(summary.directoryStatus == .available)
        #expect(summary.items.map(\.fileName) == [
            "app.holdtype.HoldType-2026-07-06-130000.crash",
            "HoldType-2026-07-06-120000.ips",
        ])
        #expect(summary.items.map(\.byteCount) == [5, 3])
    }

    @Test func summaryReturnsMissingStateWhenDiagnosticDirectoryDoesNotExist() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("Missing", isDirectory: true)
        let service = DiagnosticsService(diagnosticReportsDirectoryURL: reportsURL)

        let summary = try service.summary()

        #expect(summary.directoryStatus == .missing)
        #expect(summary.items.isEmpty)
        #expect(summary.directoryURL == reportsURL)
    }

    @Test func summaryRejectsNonDirectoryDiagnosticReportsPath() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("DiagnosticReports")
        try Data(repeating: 0x01, count: 1).write(to: reportsURL)
        let service = DiagnosticsService(diagnosticReportsDirectoryURL: reportsURL)

        #expect(throws: DiagnosticsServiceError.listingFailed) {
            try service.summary()
        }
    }

    @Test func exportDiagnosticBundleCopiesRecentReportsAndWritesRedactedMetadata() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let bundlesURL = rootURL.appendingPathComponent("Bundles", isDirectory: true)
        let runtimeLogsURL = rootURL.appendingPathComponent("RuntimeLogs", isDirectory: true)
        let exportDate = Date(timeIntervalSince1970: 1_783_333_503)
        let runtimeLogStore = RuntimeDiagnosticsLogStore(
            directoryURL: runtimeLogsURL,
            now: { exportDate }
        )
        runtimeLogStore.record(
            RuntimeDiagnosticEvent(
                category: "dictation",
                name: "transcription_failed",
                severity: .error,
                fields: ["error_category": "network_unavailable"]
            )
        )
        let reportURL = try writeReport(named: "HoldType-2026-07-06-132424.ips", bytes: 4, in: reportsURL)
        try setDates(fileURL: reportURL, timestamp: 20)
        let service = DiagnosticsService(
            diagnosticReportsDirectoryURL: reportsURL,
            diagnosticBundlesDirectoryURL: bundlesURL,
            now: { exportDate },
            uuidProvider: { UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")! },
            appMetadataProvider: {
                DiagnosticAppMetadata(
                    appName: "HoldType",
                    bundleIdentifier: "app.holdtype.HoldType",
                    appVersion: "1.2.3",
                    buildNumber: "45"
                )
            },
            runtimeLogStore: runtimeLogStore
        )

        let result = try service.exportDiagnosticBundle()
        let copiedReportURL = result.bundleURL
            .appendingPathComponent("CrashReports", isDirectory: true)
            .appendingPathComponent("HoldType-2026-07-06-132424.ips")
        let exportedRuntimeLogURL = result.bundleURL
            .appendingPathComponent("RuntimeLogs", isDirectory: true)
            .appendingPathComponent("runtime-events.log")
        let readmeURL = result.bundleURL.appendingPathComponent("README.txt")

        #expect(FileManager.default.fileExists(atPath: copiedReportURL.path))
        #expect(FileManager.default.fileExists(atPath: exportedRuntimeLogURL.path))
        #expect(FileManager.default.fileExists(atPath: readmeURL.path))

        let manifest = try manifest(in: result.bundleURL)

        #expect(manifest.app.bundleIdentifier == "app.holdtype.HoldType")
        #expect(manifest.includedCrashReportFileNames == ["HoldType-2026-07-06-132424.ips"])
        #expect(manifest.includedRuntimeLogFileNames == ["RuntimeLogs/runtime-events.log"])
        #expect(manifest.runtimeLogLineCount == 1)
        #expect(manifest.excludedContent.contains("API keys"))
        #expect(manifest.excludedContent.contains("transcripts"))
        #expect(manifest.excludedContent.contains("raw audio"))
        let runtimeLogText = try String(contentsOf: exportedRuntimeLogURL, encoding: .utf8)
        #expect(runtimeLogText.contains("event=transcription_failed"))
    }

    @Test func exportDiagnosticBundleWorksWhenNoCrashReportsExist() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportsURL, withIntermediateDirectories: true)
        let service = DiagnosticsService(
            diagnosticReportsDirectoryURL: reportsURL,
            diagnosticBundlesDirectoryURL: rootURL.appendingPathComponent("Bundles", isDirectory: true),
            runtimeLogStore: RuntimeDiagnosticsLogStore(
                directoryURL: rootURL.appendingPathComponent("RuntimeLogs", isDirectory: true)
            )
        )

        let result = try service.exportDiagnosticBundle()

        let manifest = try manifest(in: result.bundleURL)

        #expect(manifest.includedCrashReportFileNames.isEmpty)
        #expect(manifest.includedRuntimeLogFileNames.isEmpty)
        #expect(manifest.runtimeLogLineCount == 0)
        #expect(FileManager.default.fileExists(atPath: result.bundleURL.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: result.bundleURL.appendingPathComponent("README.txt").path))
    }

    @Test func diagnosticsActionsEmitCompactLogEvents() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let reportsURL = rootURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        let eventLogger = SpyDiagnosticsEventLogger()
        let service = DiagnosticsService(
            diagnosticReportsDirectoryURL: reportsURL,
            diagnosticBundlesDirectoryURL: rootURL.appendingPathComponent("Bundles", isDirectory: true),
            eventLogger: eventLogger
        )
        _ = try writeReport(named: "HoldType-2026-07-06-132424.ips", bytes: 4, in: reportsURL)

        _ = try service.summary()
        _ = try service.exportDiagnosticBundle()

        #expect(eventLogger.events.contains(.crashReportRefreshCompleted(reportCount: 1)))
        #expect(eventLogger.events.contains(.diagnosticBundleExported(reportCount: 1)))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-diagnostics-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func manifest(in bundleURL: URL) throws -> DiagnosticBundleManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            DiagnosticBundleManifest.self,
            from: Data(
                contentsOf: bundleURL.appendingPathComponent("manifest.json")
            )
        )
    }

    private func writeReport(named fileName: String, bytes: Int, in directoryURL: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try Data(repeating: 0x01, count: bytes).write(to: fileURL)
        return fileURL
    }

    private func setDates(fileURL: URL, timestamp: TimeInterval) throws {
        let date = Date(timeIntervalSince1970: timestamp)
        try FileManager.default.setAttributes(
            [
                .creationDate: date,
                .modificationDate: date,
            ],
            ofItemAtPath: fileURL.path
        )
    }
}

private final class SpyDiagnosticsEventLogger: DiagnosticsEventLogging {
    private(set) var events: [DiagnosticsLogEvent] = []

    func record(_ event: DiagnosticsLogEvent) {
        events.append(event)
    }
}
