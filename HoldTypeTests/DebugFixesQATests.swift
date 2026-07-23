import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct DebugFixesQATests {
    @Test func configurationRequiresEveryExactSanitizedGate() {
        let valid = makeEnvironment()
        #expect(DebugFixesQAConfiguration.resolve(environment: valid) != nil)

        for key in [
            KeychainInteractionPolicy.automationEnvironmentKey,
            KeychainInteractionPolicy.authenticationUIEnvironmentKey,
            DebugFixesQAConfiguration.enabledEnvironmentKey,
            DebugFixesQAConfiguration.modeEnvironmentKey,
        ] {
            var missing = valid
            missing.removeValue(forKey: key)
            #expect(DebugFixesQAConfiguration.resolve(environment: missing) == nil)
        }

        var looseAutomation = valid
        looseAutomation[
            KeychainInteractionPolicy.automationEnvironmentKey
        ] = "true"
        #expect(DebugFixesQAConfiguration.resolve(environment: looseAutomation) == nil)

        var looseEnable = valid
        looseEnable[
            DebugFixesQAConfiguration.enabledEnvironmentKey
        ] = "yes"
        #expect(DebugFixesQAConfiguration.resolve(environment: looseEnable) == nil)

        var badMode = valid
        badMode[DebugFixesQAConfiguration.modeEnvironmentKey] = "SUCCESS"
        #expect(DebugFixesQAConfiguration.resolve(environment: badMode) == nil)
    }

    @Test func outputAndLaunchValidationIsStrictAndBounded() {
        var blankOutput = makeEnvironment()
        blankOutput[DebugFixesQAConfiguration.outputEnvironmentKey] = " \n "
        #expect(DebugFixesQAConfiguration.resolve(environment: blankOutput) == nil)

        let maximumOutput = String(
            repeating: "x",
            count: DebugFixesQAConfiguration.maximumOutputByteCount
        )
        #expect(
            DebugFixesQAConfiguration.resolve(
                environment: makeEnvironment(output: maximumOutput)
            ) != nil
        )
        #expect(
            DebugFixesQAConfiguration.resolve(
                environment: makeEnvironment(output: maximumOutput + "x")
            ) == nil
        )

        var failureWithOutput = makeEnvironment(
            mode: .failure,
            output: "not allowed"
        )
        #expect(DebugFixesQAConfiguration.resolve(environment: failureWithOutput) == nil)

        failureWithOutput.removeValue(
            forKey: DebugFixesQAConfiguration.outputEnvironmentKey
        )
        #expect(DebugFixesQAConfiguration.resolve(environment: failureWithOutput) != nil)

        var looseLaunch = makeEnvironment()
        looseLaunch[
            DebugFixesQAConfiguration.showPaletteEnvironmentKey
        ] = "true"
        #expect(DebugFixesQAConfiguration.resolve(environment: looseLaunch) == nil)
    }

    @Test func ordinaryDebugUsesTheProductionFactory() {
        var productionFactoryCallCount = 0

        _ = FixesRuntime.makeSharedRuntime(environment: [:]) {
            productionFactoryCallCount += 1
            return FixesRuntime()
        }

        #expect(productionFactoryCallCount == 1)
    }

    @Test func controlledRuntimeNeverConstructsTheProductionProviderBoundary() {
        var productionFactoryCallCount = 0

        _ = FixesRuntime.makeSharedRuntime(
            environment: makeEnvironment()
        ) {
            productionFactoryCallCount += 1
            return FixesRuntime()
        }

        #expect(productionFactoryCallCount == 0)
    }

    @Test func controlledSuccessReturnsOnlyTheFixedOutput() async throws {
        let outputCanary = "QA-OUTPUT-CANARY-419"
        let service = try makeService(
            environment: makeEnvironment(output: outputCanary)
        )

        let output = try await execute(service)

        #expect(output == outputCanary)
    }

    @Test func controlledFailureAndTimeoutAreBoundedProviderOutcomes() async throws {
        let failureService = try makeService(
            environment: makeEnvironment(mode: .failure, output: nil)
        )
        await #expect(
            throws: DebugFixesQAExecutionError.controlledFailure
        ) {
            try await execute(failureService)
        }

        let timeoutService = DebugFixesQAExecutionService(
            configuration: try #require(
                DebugFixesQAConfiguration.resolve(
                    environment: makeEnvironment(
                        mode: .timeout,
                        output: nil
                    )
                )
            ),
            timeoutDelay: .milliseconds(1)
        )
        await #expect(
            throws: OpenAITextTransformationServiceError.timedOut
        ) {
            try await execute(timeoutService)
        }
    }

    @Test func controlledCancellationCooperatesWithinABoundedWindow() async throws {
        let service = DebugFixesQAExecutionService(
            configuration: try #require(
                DebugFixesQAConfiguration.resolve(
                    environment: makeEnvironment(
                        mode: .cancel,
                        output: nil
                    )
                )
            ),
            cancellationWindow: .seconds(1)
        )
        let task = Task { @MainActor in
            try await execute(service)
        }

        await Task.yield()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func payloadDescriptionsAndMirrorsStayRedacted() throws {
        let canary = "PAYLOAD-CANARY-882"
        let configuration = try #require(
            DebugFixesQAConfiguration.resolve(
                environment: makeEnvironment(output: canary)
            )
        )
        let service = DebugFixesQAExecutionService(
            configuration: configuration
        )
        let credentialResolver = DebugFixesQACredentialResolver()
        let serialized = [
            String(describing: configuration),
            String(reflecting: configuration),
            String(describing: service),
            String(reflecting: service),
            String(describing: configuration.customMirror.children),
            String(describing: service.customMirror.children),
            String(describing: credentialResolver),
            String(reflecting: credentialResolver),
        ].joined(separator: "\n")

        #expect(!serialized.contains(canary))
        #expect(serialized.contains("<redacted>"))
        #expect(
            String(
                describing: try credentialResolver
                    .resolveOpenAICredential()
            ).contains("<redacted>")
        )
    }

    @Test func launchTriggerIsOptInDelayedAndDoesNotActivateAnything() {
        var scheduledDelay: Int?
        var scheduledPresentation: (@MainActor () -> Void)?
        var showCount = 0

        DebugFixesQALaunch.requestIfNeeded(
            environment: makeEnvironment(),
            showPalette: {
                showCount += 1
            },
            schedulePresentation: { delay, presentation in
                scheduledDelay = delay
                scheduledPresentation = presentation
            }
        )
        #expect(scheduledDelay == nil)
        #expect(showCount == 0)

        DebugFixesQALaunch.requestIfNeeded(
            environment: makeEnvironment(showsPaletteOnLaunch: true),
            showPalette: {
                showCount += 1
            },
            schedulePresentation: { delay, presentation in
                scheduledDelay = delay
                scheduledPresentation = presentation
            }
        )

        #expect(
            scheduledDelay
                == DebugFixesQALaunch.presentationDelayMilliseconds
        )
        #expect(DebugFixesQALaunch.presentationDelayMilliseconds > 0)
        #expect(DebugFixesQALaunch.presentationDelayMilliseconds <= 2_000)
        #expect(showCount == 0)

        scheduledPresentation?()
        #expect(showCount == 1)
    }

    private func makeEnvironment(
        mode: DebugFixesQAConfiguration.Mode = .success,
        output: String? = "Controlled output",
        showsPaletteOnLaunch: Bool = false
    ) -> [String: String] {
        var environment = [
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
            DebugFixesQAConfiguration.enabledEnvironmentKey: "1",
            DebugFixesQAConfiguration.modeEnvironmentKey: mode.rawValue,
        ]
        if let output {
            environment[
                DebugFixesQAConfiguration.outputEnvironmentKey
            ] = output
        }
        if showsPaletteOnLaunch {
            environment[
                DebugFixesQAConfiguration.showPaletteEnvironmentKey
            ] = "1"
        }
        return environment
    }

    private func makeService(
        environment: [String: String]
    ) throws -> DebugFixesQAExecutionService {
        DebugFixesQAExecutionService(
            configuration: try #require(
                DebugFixesQAConfiguration.resolve(
                    environment: environment
                )
            )
        )
    }

    private func execute(
        _ service: DebugFixesQAExecutionService
    ) async throws -> String {
        try await service.execute(
            action: TextFixCatalog.defaults.actions[0],
            sourceText: "Source is intentionally ignored by the QA executor.",
            settings: .defaults,
            credential: try OpenAICredential(apiKey: "test-only")
        )
    }
}
