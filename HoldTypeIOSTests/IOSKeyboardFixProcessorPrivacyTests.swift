import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeIOS

struct IOSKeyboardFixProcessorPrivacyTests {
    @Test func descriptionsAndMirrorsNeverExposePrivatePayloads()
        async throws {
        let sourceSecret = "SOURCE-SECRET-8472"
        let promptSecret = "PROMPT-SECRET-2931"
        let outputSecret = "OUTPUT-SECRET-5610"
        let action = try TextFixAction(
            id: "user.private-fix",
            kind: .customPrompt,
            title: "Private Fix",
            icon: .custom,
            prompt: promptSecret
        )
        let catalog = try TextFixCatalog(
            actions: Array(TextFixCatalog.defaults.actions.prefix(2)) + [action]
        )
        let request = try makeProcessorTestRequest(
            actionIdentifier: action.id,
            sourceText: sourceSecret
        )
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let inputs = IOSKeyboardFixTestInputProbe()
        let signals = IOSKeyboardFixTestSignalProbe()
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.issuedAt.addingTimeInterval(1),
            catalog: { catalog },
            execute: { input in
                inputs.record(input)
                return outputSecret
            },
            signals: signals.client
        )

        let outcome = await processor.processPendingRequest()
        let input = try #require(inputs.inputs.first)
        let terminal = try #require(bridge.results.last)
        let projections = [
            String(describing: processor),
            String(reflecting: processor),
            String(describing: input),
            String(reflecting: input),
            mirrorProjection(input),
            String(describing: outcome),
            String(reflecting: outcome),
            String(describing: terminal),
            String(reflecting: terminal),
            mirrorProjection(terminal),
        ] + signals.signals.flatMap {
            [String(describing: $0), String(reflecting: $0)]
        }

        for projection in projections {
            #expect(!projection.contains(sourceSecret))
            #expect(!projection.contains(promptSecret))
            #expect(!projection.contains(outputSecret))
            #expect(!projection.contains(request.documentIdentifier))
            #expect(!projection.contains(request.sourceFingerprint))
        }
    }
}

private func mirrorProjection(_ value: Any) -> String {
    Mirror(reflecting: value).children.map { child in
        "\(child.label ?? "<nil>")=\(String(describing: child.value))"
    }.joined(separator: ",")
}
