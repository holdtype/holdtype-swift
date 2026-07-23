import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeIOS

struct IOSKeyboardFixProcessorTests {
    @Test func successConsumesOnceAndPublishesProcessingThenExactOutput()
        async throws {
        let request = try makeProcessorTestRequest()
        let now = request.issuedAt.addingTimeInterval(1)
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let signals = IOSKeyboardFixTestSignalProbe()
        let background = IOSKeyboardFixTestBackgroundProbe()
        let inputs = IOSKeyboardFixTestInputProbe()
        let exactOutput = "  Exact transformed output\n"
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: now,
            execute: { input in
                inputs.record(input)
                return exactOutput
            },
            background: background.client,
            signals: signals.client
        )

        let outcome = await processor.processPendingRequest()

        #expect(outcome == .completed(.succeeded))
        #expect(bridge.consumedCount == 1)
        #expect(bridge.results.map(\.phase) == [.processing, .succeeded])
        #expect(bridge.results.last?.outputText == exactOutput)
        #expect(bridge.results.allSatisfy { $0.identity == request.identity })
        #expect(inputs.inputs.count == 1)
        #expect(inputs.inputs.first?.action.id == request.actionIdentifier)
        #expect(inputs.inputs.first?.sourceText == request.sourceText)
        #expect(background.beginCount == 1)
        #expect(background.endCount == 1)
        #expect(
            signals.signals == [
                .processing(
                    requestID: request.requestID,
                    actionIdentifier: request.actionIdentifier
                ),
                .terminal(
                    requestID: request.requestID,
                    actionIdentifier: request.actionIdentifier,
                    outcome: .succeeded
                ),
            ]
        )
    }

    @Test func executorFailuresMapToClosedTerminalCodes() async throws {
        let cases: [
            (
                IOSKeyboardFixExecutionFailure,
                HoldTypeIOS.KeyboardFixFailureCode
            )
        ] = [
            (.providerFailed, .providerFailed),
            (.timedOut, .timedOut),
            (.invalidOutput, .invalidOutput),
            (.translationUnavailable, .translationUnavailable),
            (.persistenceFailed, .persistenceFailed),
        ]

        for (failure, expectedCode) in cases {
            let request = try makeProcessorTestRequest()
            let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
            let processor = makeKeyboardFixProcessor(
                bridge: bridge.client,
                now: request.issuedAt.addingTimeInterval(1),
                execute: { _ in throw failure }
            )

            let outcome = await processor.processPendingRequest()

            #expect(outcome == .completed(.failed(expectedCode)))
            #expect(bridge.results.map(\.phase) == [.processing, .failed])
            #expect(bridge.results.last?.failureCode == expectedCode)
            #expect(bridge.results.last?.outputText == nil)
        }
    }

    @Test func preflightFailuresNeverDispatchTheExecutor() async throws {
        let request = try makeProcessorTestRequest()

        let cases: [
            (
                @Sendable (TextFixAction) async throws ->
                    IOSKeyboardFixSettingsReadiness,
                @Sendable () async throws -> Bool,
                @Sendable () async throws -> Bool,
                HoldTypeIOS.KeyboardFixFailureCode
            )
        ] = [
            ({ _ in .translationUnavailable }, { true }, { true },
             .translationUnavailable),
            ({ _ in .ready }, { false }, { true }, .consentRequired),
            ({ _ in .ready }, { true }, { false }, .credentialUnavailable),
        ]

        for (settings, consent, credential, expectedCode) in cases {
            let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
            let inputs = IOSKeyboardFixTestInputProbe()
            let processor = makeKeyboardFixProcessor(
                bridge: bridge.client,
                now: request.issuedAt.addingTimeInterval(1),
                settings: settings,
                consent: consent,
                credential: credential,
                execute: { input in
                    inputs.record(input)
                    return "Must not execute"
                }
            )

            let outcome = await processor.processPendingRequest()

            #expect(outcome == .completed(.failed(expectedCode)))
            #expect(inputs.inputs.isEmpty)
            #expect(bridge.results.last?.failureCode == expectedCode)
        }
    }

    @Test func missingActionAndCatalogFailureUseClosedLocalCodes()
        async throws {
        let missingRequest = try makeProcessorTestRequest(
            actionIdentifier: "missing.action"
        )
        let missingBridge = IOSKeyboardFixTestBridgeProbe(
            request: missingRequest
        )
        let inputs = IOSKeyboardFixTestInputProbe()
        let missingProcessor = makeKeyboardFixProcessor(
            bridge: missingBridge.client,
            now: missingRequest.issuedAt.addingTimeInterval(1),
            execute: { input in
                inputs.record(input)
                return "Must not execute"
            }
        )

        #expect(
            await missingProcessor.processPendingRequest()
                == .completed(.failed(.actionUnavailable))
        )
        #expect(
            missingBridge.results.last?.failureCode == .actionUnavailable
        )
        #expect(inputs.inputs.isEmpty)

        let catalogRequest = try makeProcessorTestRequest()
        let catalogBridge = IOSKeyboardFixTestBridgeProbe(
            request: catalogRequest
        )
        let catalogProcessor = makeKeyboardFixProcessor(
            bridge: catalogBridge.client,
            now: catalogRequest.issuedAt.addingTimeInterval(1),
            catalog: { throw IOSKeyboardFixProcessorTestError.invalidRequest },
            execute: { _ in "Must not execute" }
        )

        #expect(
            await catalogProcessor.processPendingRequest()
                == .completed(.failed(.persistenceFailed))
        )
        #expect(
            catalogBridge.results.last?.failureCode == .persistenceFailed
        )
    }

    @Test func expiredRequestIsRetiredWithoutProviderOrResultPublication()
        async throws {
        let issuedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let request = try makeProcessorTestRequest(
            issuedAt: issuedAt,
            expiresAt: issuedAt.addingTimeInterval(60)
        )
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let inputs = IOSKeyboardFixTestInputProbe()
        let signals = IOSKeyboardFixTestSignalProbe()
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.expiresAt,
            execute: { input in
                inputs.record(input)
                return "Must not execute"
            },
            signals: signals.client
        )

        let outcome = await processor.processPendingRequest()

        #expect(outcome == .expired)
        #expect(bridge.consumedCount == 1)
        #expect(bridge.results.isEmpty)
        #expect(inputs.inputs.isEmpty)
        #expect(
            signals.signals == [
                .expired(
                    requestID: request.requestID,
                    actionIdentifier: request.actionIdentifier
                )
            ]
        )
    }

    @Test func backgroundExpirationCancelsAndPublishesOneTerminalFailure()
        async throws {
        let request = try makeProcessorTestRequest()
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let background = IOSKeyboardFixTestBackgroundProbe()
        let execution = IOSKeyboardFixTestExecutionGate()
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.issuedAt.addingTimeInterval(1),
            execute: execution.client.execute,
            background: background.client
        )

        let task = Task { await processor.processPendingRequest() }
        try await processorEventually {
            execution.executeCount == 1 && background.beginCount == 1
        }
        background.expire()
        let outcome = await task.value

        #expect(outcome == .completed(.failed(.cancelled)))
        #expect(bridge.results.map(\.phase) == [.processing, .failed])
        #expect(bridge.results.last?.failureCode == .cancelled)
        #expect(background.endCount == 1)
    }

    @Test func concurrentSignalFailsClosedWithoutConsumptionOrQueue()
        async throws {
        let request = try makeProcessorTestRequest()
        let bridge = IOSKeyboardFixTestBridgeProbe(request: request)
        let background = IOSKeyboardFixTestBackgroundProbe()
        let execution = IOSKeyboardFixTestExecutionGate()
        let signals = IOSKeyboardFixTestSignalProbe()
        let processor = makeKeyboardFixProcessor(
            bridge: bridge.client,
            now: request.issuedAt.addingTimeInterval(1),
            execute: execution.client.execute,
            background: background.client,
            signals: signals.client
        )

        let first = Task { await processor.processPendingRequest() }
        try await processorEventually { execution.executeCount == 1 }

        let second = await processor.processPendingRequest()

        #expect(second == .busy)
        #expect(bridge.consumedCount == 1)
        #expect(execution.executeCount == 1)
        #expect(signals.signals.contains(.rejectedWhileBusy))

        await processor.cancelActiveRequest()
        #expect(
            await first.value == .completed(.failed(.cancelled))
        )
    }
}
