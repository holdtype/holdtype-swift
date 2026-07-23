import Foundation
import Testing
@testable import HoldTypeIOS

struct IOSKeyboardFixProcessorDiagnosticsTests {
    @Test func successRecordsRequestProviderAndClosedResult() async throws {
        let fixture = try AppFixDiagnosticFixture()
        defer { fixture.remove() }
        let request = try makeProcessorTestRequest()
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.issuedAt.addingTimeInterval(1),
            execute: { _ in "Improved output" },
            diagnostics: fixture.client
        )

        #expect(
            await processor.processPendingRequest()
                == .completed(.succeeded)
        )

        let lines = try fixture.store.recentLines(limit: 20)
        #expect(lines.containsTextFix(.request, .started))
        #expect(lines.containsTextFix(.processing, .started))
        #expect(lines.containsTextFix(.provider, .started))
        #expect(lines.containsTextFix(.result, .succeeded))
        #expect(lines.allSatisfy { !$0.contains(request.actionIdentifier) })
        #expect(lines.allSatisfy { !$0.contains(request.sourceText) })
    }

    @Test func terminalFailuresProjectTimeoutCancellationAndBlock()
        async throws {
        let cases: [
            (
                IOSKeyboardFixExecutionFailure,
                HoldTypeIOS.IOSDiagnosticTextFixOutcome
            )
        ] = [
            (.timedOut, .timedOut),
            (.cancelled, .cancelled),
            (.providerFailed, .failed),
        ]

        for (failure, expected) in cases {
            let fixture = try AppFixDiagnosticFixture()
            defer { fixture.remove() }
            let request = try makeProcessorTestRequest()
            let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
            let processor = makeKeyboardFixProcessor(
                bridge: bridge.client,
                now: request.issuedAt.addingTimeInterval(1),
                execute: { _ in throw failure },
                diagnostics: fixture.client
            )

            _ = await processor.processPendingRequest()

            #expect(
                try fixture.store.recentLines(limit: 20)
                    .containsTextFix(.result, expected)
            )
        }

        let blockedFixture = try AppFixDiagnosticFixture()
        defer { blockedFixture.remove() }
        let blockedRequest = try makeProcessorTestRequest()
        let blockedBridge = IOSKeyboardFixTestBridgeProbe(
            request: blockedRequest
        )
        let blockedProcessor = makeKeyboardFixProcessor(
            bridge: blockedBridge.client,
            now: blockedRequest.issuedAt.addingTimeInterval(1),
            consent: { false },
            execute: { _ in "Must not execute" },
            diagnostics: blockedFixture.client
        )

        _ = await blockedProcessor.processPendingRequest()

        let blockedLines = try blockedFixture.store.recentLines(limit: 20)
        #expect(blockedLines.containsTextFix(.result, .blocked))
        #expect(!blockedLines.containsTextFix(.provider, .started))
    }

    @Test func busyExpiredAndBridgePathsRemainDistinct() async throws {
        let busyFixture = try AppFixDiagnosticFixture()
        defer { busyFixture.remove() }
        let request = try makeProcessorTestRequest()
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let execution = IOSKeyboardFixTestExecutionGate()
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.issuedAt.addingTimeInterval(1),
            execute: execution.client.execute,
            diagnostics: busyFixture.client
        )
        let first = Task { await processor.processPendingRequest() }
        try await waitForFixDiagnosticExecution {
            execution.executeCount == 1
        }

        #expect(await processor.processPendingRequest() == .busy)
        await processor.cancelActiveRequest()
        _ = await first.value
        #expect(
            try busyFixture.store.recentLines(limit: 20)
                .containsTextFix(.processing, .busy)
        )

        let expiredFixture = try AppFixDiagnosticFixture()
        defer { expiredFixture.remove() }
        let expiredRequest = try makeProcessorTestRequest()
        let expiredBridge = IOSKeyboardFixTestBridgeProbe(
            request: expiredRequest
        )
        let expiredProcessor = makeKeyboardFixProcessor(
            bridge: expiredBridge.client,
            now: expiredRequest.expiresAt,
            execute: { _ in "Must not execute" },
            diagnostics: expiredFixture.client
        )
        #expect(await expiredProcessor.processPendingRequest() == .expired)
        #expect(
            try expiredFixture.store.recentLines(limit: 20)
                .containsTextFix(.request, .expired)
        )

        let bridgeFixture = try AppFixDiagnosticFixture()
        defer { bridgeFixture.remove() }
        let failedBridge = IOSKeyboardFixBridgeClient(
            consumeRequest: { _ in
                throw AppFixDiagnosticFailure.injected
            },
            publishResult: { _ in }
        )
        let bridgeProcessor = makeKeyboardFixProcessor(
            bridge: failedBridge,
            now: request.issuedAt,
            execute: { _ in "Must not execute" },
            diagnostics: bridgeFixture.client
        )
        #expect(
            await bridgeProcessor.processPendingRequest()
                == .bridgeUnavailable
        )
        #expect(
            try bridgeFixture.store.recentLines(limit: 20)
                .containsTextFix(.request, .bridgeUnavailable)
        )
    }
}

private final class AppFixDiagnosticFixture {
    let root: URL
    let store: HoldTypeIOS.IOSRuntimeDiagnosticsStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HoldType-AppFixDiagnostics-\(UUID().uuidString)",
            isDirectory: true
        )
        store = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL: root
        )
    }

    var client: HoldTypeIOS.IOSRuntimeTextFixDiagnosticClient {
        HoldTypeIOS.IOSRuntimeTextFixDiagnosticClient { [store] event in
            store.record(event)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private enum AppFixDiagnosticFailure: Error {
    case injected
}

private func waitForFixDiagnosticExecution(
    _ condition: @escaping @Sendable () -> Bool
) async throws {
    for _ in 0..<500 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    throw IOSKeyboardFixProcessorTestError.timedOut
}

private extension [String] {
    func containsTextFix(
        _ stage: HoldTypeIOS.IOSDiagnosticTextFixStage,
        _ outcome: HoldTypeIOS.IOSDiagnosticTextFixOutcome
    ) -> Bool {
        contains {
            $0.contains("stage=\(stage.rawValue)")
                && $0.contains("outcome=\(outcome.rawValue)")
        }
    }
}
