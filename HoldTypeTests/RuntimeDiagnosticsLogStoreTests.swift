//
//  RuntimeDiagnosticsLogStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import Testing
@testable import HoldType

struct RuntimeDiagnosticsLogStoreTests {
    @Test func recordStoresSanitizedRecentLines() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let logDate = Date(timeIntervalSince1970: 1_783_333_503)
        let store = RuntimeDiagnosticsLogStore(
            directoryURL: rootURL,
            now: { logDate }
        )

        store.record(
            RuntimeDiagnosticEvent(
                category: "dictation",
                name: "transcription failed",
                severity: .error,
                fields: [
                    "error category": "network unavailable",
                    "output intent": "standard",
                ]
            )
        )

        let lines = try store.recentLogLines(limit: 10)

        #expect(lines.count == 1)
        #expect(lines[0].contains("category=dictation"))
        #expect(lines[0].contains("event=transcription_failed"))
        #expect(lines[0].contains("severity=error"))
        #expect(lines[0].contains("error_category=network_unavailable"))
        #expect(lines[0].contains("output_intent=standard"))
    }

    @Test func exportRecentLogsUsesSinceWindow() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        var currentDate = Date(timeIntervalSince1970: 1_783_000_000)
        let store = RuntimeDiagnosticsLogStore(
            directoryURL: rootURL.appendingPathComponent("RuntimeLogs", isDirectory: true),
            now: { currentDate }
        )

        store.record(RuntimeDiagnosticEvent(category: "dictation", name: "old_event"))
        currentDate = Date(timeIntervalSince1970: 1_783_333_503)
        store.record(RuntimeDiagnosticEvent(category: "dictation", name: "new_event"))

        let bundleURL = rootURL.appendingPathComponent("Bundle", isDirectory: true)
        let export = try store.exportRecentLogs(
            to: bundleURL,
            since: Date(timeIntervalSince1970: 1_783_300_000)
        )

        let unwrappedExport = try #require(export)
        #expect(unwrappedExport.relativePath == "RuntimeLogs/runtime-events.log")
        #expect(unwrappedExport.lineCount == 1)

        let exportedText = try String(
            contentsOf: bundleURL.appendingPathComponent(unwrappedExport.relativePath),
            encoding: .utf8
        )
        #expect(exportedText.contains("event=new_event"))
        #expect(!exportedText.contains("event=old_event"))
    }

    @Test func pruneRemovesOnlyOldRuntimeLogFiles() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let oldFileURL = rootURL.appendingPathComponent("runtime-20260701.log")
        let unrelatedFileURL = rootURL.appendingPathComponent("notes.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "old\n".write(to: oldFileURL, atomically: true, encoding: .utf8)
        try "keep\n".write(to: unrelatedFileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 10)],
            ofItemAtPath: oldFileURL.path
        )

        let store = RuntimeDiagnosticsLogStore(
            directoryURL: rootURL,
            now: { Date(timeIntervalSince1970: 1_783_333_503) },
            maximumAge: 60,
            maximumTotalByteCount: 1024
        )

        try store.prune()

        #expect(!FileManager.default.fileExists(atPath: oldFileURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedFileURL.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-runtime-logs-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
