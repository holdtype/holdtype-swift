import Foundation
import HoldTypeDomain

nonisolated struct IOSKeyboardFixProcessorRunDependencies: Sendable {
    let bridge: IOSKeyboardFixBridgeClient
    let catalog: IOSKeyboardFixCatalogClient
    let settings: IOSKeyboardFixSettingsClient
    let consent: IOSKeyboardFixConsentV4Client
    let credential: IOSKeyboardFixCredentialClient
    let executor: IOSKeyboardFixExecutionClient
    let backgroundTask: IOSKeyboardFixBackgroundTaskClient
    let clock: IOSKeyboardFixProcessorClock
    let signals: IOSKeyboardFixSignalClient
}

private nonisolated enum IOSKeyboardFixPipelineResolution: Sendable {
    case succeeded(String)
    case failed(KeyboardFixFailureCode)
    case expired
}

private nonisolated enum IOSKeyboardFixSettingsCheck: Sendable {
    case ready
    case failed(KeyboardFixFailureCode)
    case cancelled
}

nonisolated enum IOSKeyboardFixProcessorRunEngine {
    static func run(
        request: KeyboardFixRequestRecord,
        dependencies: IOSKeyboardFixProcessorRunDependencies
    ) async -> IOSKeyboardFixProcessorOutcome {
        let publisher = IOSKeyboardFixResultPublisher(
            request: request,
            bridge: dependencies.bridge,
            clock: dependencies.clock,
            signals: dependencies.signals
        )
        guard publisher.publishProcessing() else {
            return .bridgeUnavailable
        }

        let pipelineTask = Task {
            await executePipeline(request, dependencies: dependencies)
        }
        let backgroundToken = await dependencies.backgroundTask.begin {
            pipelineTask.cancel()
        }
        if Task.isCancelled {
            pipelineTask.cancel()
        }
        let resolution = await withTaskCancellationHandler {
            await pipelineTask.value
        } onCancel: {
            pipelineTask.cancel()
        }
        await dependencies.backgroundTask.end(backgroundToken)

        return switch resolution {
        case .succeeded(let output):
            publisher.publishSuccess(output)
        case .failed(let failure):
            publisher.publishFailure(failure)
        case .expired:
            publisher.reportExpired()
        }
    }

    private static func executePipeline(
        _ request: KeyboardFixRequestRecord,
        dependencies: IOSKeyboardFixProcessorRunDependencies
    ) async -> IOSKeyboardFixPipelineResolution {
        guard !hasExpired(request, dependencies: dependencies) else {
            return .expired
        }
        guard !Task.isCancelled else { return .failed(.cancelled) }

        let loadedCatalog: TextFixCatalog
        do {
            loadedCatalog = try await dependencies.catalog.load()
        } catch {
            return Task.isCancelled
                ? .failed(.cancelled)
                : .failed(.persistenceFailed)
        }
        guard !hasExpired(request, dependencies: dependencies) else {
            return .expired
        }
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard let action = loadedCatalog.action(id: request.actionIdentifier),
              action.isEnabled else {
            return .failed(.actionUnavailable)
        }

        switch await checkSettings(action, dependencies: dependencies) {
        case .ready:
            break
        case .failed(let failure):
            return .failed(failure)
        case .cancelled:
            return .failed(.cancelled)
        }
        guard !hasExpired(request, dependencies: dependencies) else {
            return .expired
        }

        do {
            guard try await dependencies.consent.isAccepted() else {
                return .failed(.consentRequired)
            }
        } catch {
            return Task.isCancelled
                ? .failed(.cancelled)
                : .failed(.consentRequired)
        }
        guard !hasExpired(request, dependencies: dependencies) else {
            return .expired
        }
        guard !Task.isCancelled else { return .failed(.cancelled) }

        do {
            guard try await dependencies.credential.isAvailable() else {
                return .failed(.credentialUnavailable)
            }
        } catch {
            return Task.isCancelled
                ? .failed(.cancelled)
                : .failed(.credentialUnavailable)
        }
        guard !hasExpired(request, dependencies: dependencies) else {
            return .expired
        }
        guard !Task.isCancelled else { return .failed(.cancelled) }

        return await execute(
            action,
            sourceText: request.sourceText,
            request: request,
            dependencies: dependencies
        )
    }

    private static func checkSettings(
        _ action: TextFixAction,
        dependencies: IOSKeyboardFixProcessorRunDependencies
    ) async -> IOSKeyboardFixSettingsCheck {
        do {
            let readiness = try await dependencies.settings.readiness(action)
            guard !Task.isCancelled else { return .cancelled }
            return switch readiness {
            case .ready:
                .ready
            case .translationUnavailable:
                .failed(.translationUnavailable)
            case .actionUnavailable:
                .failed(.actionUnavailable)
            }
        } catch {
            return Task.isCancelled
                ? .cancelled
                : .failed(.persistenceFailed)
        }
    }

    private static func execute(
        _ action: TextFixAction,
        sourceText: String,
        request: KeyboardFixRequestRecord,
        dependencies: IOSKeyboardFixProcessorRunDependencies
    ) async -> IOSKeyboardFixPipelineResolution {
        do {
            let output = try await dependencies.executor.execute(
                IOSKeyboardFixExecutionInput(
                    action: action,
                    sourceText: sourceText
                )
            )
            guard !Task.isCancelled else { return .failed(.cancelled) }
            guard !hasExpired(request, dependencies: dependencies) else {
                return .expired
            }
            guard KeyboardFixBridgeValidation.containsVisibleContent(output),
                  output.utf8.count
                    <= KeyboardFixBridgeConfiguration.maximumOutputUTF8Bytes
            else {
                return .failed(.invalidOutput)
            }
            return .succeeded(output)
        } catch let failure as IOSKeyboardFixExecutionFailure {
            return Task.isCancelled
                ? .failed(.cancelled)
                : .failed(failure.bridgeCode)
        } catch is CancellationError {
            return .failed(.cancelled)
        } catch {
            return Task.isCancelled
                ? .failed(.cancelled)
                : .failed(.providerFailed)
        }
    }

    private static func hasExpired(
        _ request: KeyboardFixRequestRecord,
        dependencies: IOSKeyboardFixProcessorRunDependencies
    ) -> Bool {
        !request.isValid(at: dependencies.clock.now())
    }
}
