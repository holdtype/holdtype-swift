import Foundation
import Testing
@testable import HoldTypeIOS

struct IOSRuntimeTextFixDiagnosticsTests {
    @Test func formattingUsesOnlyClosedTagsAndNeverPrivateCanaries()
        throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HoldType-TextFixDiagnostics-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL: root,
            now: {
                Date(timeIntervalSince1970: 1_750_000_000)
            }
        )
        let actionIdentifier = "CUSTOM-ACTION-PROMPT-CANARY-9321"
        let requestID = UUID(
            uuidString: "A0000000-0000-0000-0000-000000000091"
        )!
        let diagnostics = HoldTypeIOS.IOSRuntimeTextFixDiagnosticClient {
            event in
            store.record(event)
        }

        diagnostics.record(
            .provider,
            actionIdentifier: actionIdentifier,
            requestID: requestID,
            outcome: .timedOut
        )

        let line = try #require(store.recentLines(limit: 1).first)
        #expect(line.contains("category=text_fix"))
        #expect(line.contains("event=text_fix"))
        #expect(line.contains("stage=provider"))
        #expect(line.contains("outcome=timed_out"))
        #expect(line.contains("action_tag="))
        #expect(line.contains("request_tag="))

        let forbiddenValues = [
            actionIdentifier,
            requestID.uuidString,
            "SOURCE-CANARY-1122",
            "PROMPT-CANARY-3344",
            "RESULT-CANARY-5566",
            "sk-key-canary-7788",
        ]
        for value in forbiddenValues {
            #expect(!line.contains(value))
        }
        let forbiddenFields = [
            "source=",
            "prompt=",
            "result=",
            "context=",
            "api_key=",
            "provider_body=",
        ]
        for field in forbiddenFields {
            #expect(!line.contains(field))
        }
    }

    @Test func bridgeFailureCodesUseClosedDiagnosticOutcomes() {
        #expect(
            HoldTypeIOS.KeyboardFixFailureCode.timedOut.diagnosticOutcome
                == .timedOut
        )
        #expect(
            HoldTypeIOS.KeyboardFixFailureCode.cancelled.diagnosticOutcome
                == .cancelled
        )
        #expect(
            HoldTypeIOS.KeyboardFixFailureCode.requestInvalid
                .diagnosticOutcome == .stale
        )
        #expect(
            HoldTypeIOS.KeyboardFixFailureCode.consentRequired
                .diagnosticOutcome == .blocked
        )
        #expect(
            HoldTypeIOS.KeyboardFixFailureCode.persistenceFailed
                .diagnosticOutcome == .bridgeUnavailable
        )
    }
}
