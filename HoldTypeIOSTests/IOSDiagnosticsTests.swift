import Foundation
import Testing
@testable import HoldTypeIOS

struct IOSDiagnosticsTests {
    @Test func runtimeLogsAreTypedSeparatedAndContentFree() throws {
        let root = temporaryDiagnosticsRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = diagnosticDate("2026-07-15T09:30:00.000Z")
        let app = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL: root,
            now: { now }
        )
        let keyboard = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .keyboard,
            rootDirectoryURL: root,
            now: { now }
        )

        app.record(
            .voiceStartRequested(origin: .foreground, action: .translate)
        )
        keyboard.record(
            .keyboardCommand(
                .start,
                action: .improve,
                outcome: .succeeded
            )
        )

        let appLine = try #require(app.recentLines(limit: 10).first)
        let keyboardLine = try #require(
            keyboard.recentLines(limit: 10).first
        )
        #expect(appLine.contains("process=app"))
        #expect(appLine.contains("event=voice_start_requested"))
        #expect(appLine.contains("action=translate"))
        #expect(keyboardLine.contains("process=keyboard"))
        #expect(keyboardLine.contains("command=start"))
        #expect(keyboardLine.contains("action=improve"))
        #expect(!appLine.contains("transcript"))
        #expect(!keyboardLine.contains("typed_text"))
    }

    @Test func runtimeRetentionPrunesExpiredDays() throws {
        let root = temporaryDiagnosticsRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let clock = DiagnosticClock(
            diagnosticDate("2026-07-01T10:00:00.000Z")
        )
        let store = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL: root,
            now: { clock.value }
        )

        store.record(.appLaunched)
        clock.value = diagnosticDate("2026-07-15T10:00:00.000Z")
        store.record(.scenePhase(.active))

        let lines = try store.recentLines(limit: 10)
        #expect(lines.count == 1)
        #expect(lines[0].contains("event=scene_phase_changed"))
    }

    @Test func exportUsesOneReadableFileAndFortyEightHourWindow() throws {
        let root = temporaryDiagnosticsRoot()
        let exportRoot = root.appendingPathComponent("Exports")
        defer { try? FileManager.default.removeItem(at: root) }
        let clock = DiagnosticClock(
            diagnosticDate("2026-07-12T08:00:00.000Z")
        )
        let app = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL: root,
            now: { clock.value }
        )
        let keyboard = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .keyboard,
            rootDirectoryURL: root,
            now: { clock.value }
        )
        let metrics = IOSMetricDiagnosticStore(
            rootDirectoryURL: root,
            now: { clock.value }
        )
        app.record(.appLaunched)
        clock.value = diagnosticDate("2026-07-15T08:00:00.000Z")
        app.record(.scenePhase(.active))
        keyboard.record(.keyboardState(.sessionReady))
        try metrics.store(
            IOSMetricDiagnosticRecord(
                receivedAt: clock.value,
                intervalStart: diagnosticDate(
                    "2026-07-14T00:00:00.000Z"
                ),
                intervalEnd: diagnosticDate(
                    "2026-07-15T00:00:00.000Z"
                ),
                crashCount: 1,
                hangCount: 0,
                cpuExceptionCount: 0,
                diskWriteCount: 0,
                payloadJSON: "{\"diagnosticMetaData\":{}}"
            )
        )
        let service = IOSDiagnosticsService(
            appLog: app,
            keyboardLog: keyboard,
            metricStore: metrics,
            now: { clock.value },
            exportDirectoryURL: exportRoot
        )
        let snapshot = service.snapshot(
            metadata: IOSDiagnosticsMetadata(
                appVersion: "1.2.3",
                buildNumber: "45",
                operatingSystem: "iOS 26.0",
                deviceFamily: "iPhone"
            )
        )

        let fileURL = try service.makeDiagnosticFile(from: snapshot)
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let exports = try FileManager.default.contentsOfDirectory(
            at: exportRoot,
            includingPropertiesForKeys: nil
        )

        #expect(exports == [fileURL])
        #expect(text.contains("HoldType Diagnostics"))
        #expect(text.contains("App version: 1.2.3"))
        #expect(text.contains("event=scene_phase_changed"))
        #expect(text.contains("process=keyboard"))
        #expect(!text.contains("2026-07-12T08:00:00.000Z"))
        #expect(text.contains("crashes=1"))
        #expect(text.contains("diagnosticMetaData"))
        #expect(text.contains("excludes dictated text"))
    }

    @Test func metricStoreIgnoresEmptyAndPrunesExpiredDelivery() throws {
        let root = temporaryDiagnosticsRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let clock = DiagnosticClock(
            diagnosticDate("2026-07-01T10:00:00.000Z")
        )
        let store = IOSMetricDiagnosticStore(
            rootDirectoryURL: root,
            now: { clock.value }
        )
        try store.store(
            IOSMetricDiagnosticRecord(
                receivedAt: clock.value,
                intervalStart: clock.value,
                intervalEnd: clock.value,
                crashCount: 1,
                hangCount: 0,
                cpuExceptionCount: 0,
                diskWriteCount: 0,
                payloadJSON: "{}"
            )
        )
        #expect(try store.records().count == 1)

        clock.value = diagnosticDate("2026-07-15T10:00:00.000Z")
        #expect(try store.records().isEmpty)

        try store.store(
            IOSMetricDiagnosticRecord(
                receivedAt: clock.value,
                intervalStart: clock.value,
                intervalEnd: clock.value,
                crashCount: 0,
                hangCount: 0,
                cpuExceptionCount: 0,
                diskWriteCount: 0,
                payloadJSON: "{}"
            )
        )
        #expect(try store.records().isEmpty)
    }
}

private final class DiagnosticClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Date

    init(_ value: Date) {
        storedValue = value
    }

    var value: Date {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

private func temporaryDiagnosticsRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
        "HoldType-IOSDiagnosticsTests-\(UUID().uuidString)",
        isDirectory: true
    )
}

private func diagnosticDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds,
    ]
    return formatter.date(from: value)!
}
