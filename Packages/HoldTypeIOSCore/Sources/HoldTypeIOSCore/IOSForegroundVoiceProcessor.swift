import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence

protocol IOSForegroundVoicePersisting: Sendable {
    func load() async throws -> IOSV1PendingRecordingObservation?

    func beginTranscription(
        expected: IOSV1PendingRecordingExpectation,
        transcriptionID: UUID
    ) async throws -> IOSV1ForegroundVoiceTranscriptionDispatch

    func retryTranscription(
        expected: IOSV1PendingRecordingExpectation,
        transcriptionID: UUID,
        transcriptionConfiguration: TranscriptionConfiguration
    ) async throws -> IOSV1ForegroundVoiceTranscriptionDispatch

    func markPostProcessing(
        expected: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1PendingRecording

    func markOutputDelivery(
        expected: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1PendingRecording

    func markFailed(
        expected: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1PendingRecording

    func accept(
        _ preparation: IOSV1ForegroundVoiceAcceptedOutputPreparation,
        expectedPending: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1ForegroundVoiceAcceptanceResult

    func reconcileAcceptance(
        matching preparation: IOSV1ForegroundVoiceAcceptedOutputPreparation
    ) async throws -> IOSV1ForegroundVoiceAcceptanceResult?
}

extension IOSV1ForegroundVoicePersistenceOwner: IOSForegroundVoicePersisting {}

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextAction: Equatable, Sendable {
    case translate
    case correct
}

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextActionFailure: Equatable, Sendable {
    case busy
    case invalidText
    case invalidConfiguration
    case credentialUnavailable
    case consentUnavailable
    case networkUnavailable
    case timedOut
    case providerUnavailable
    case invalidResponse
    case draftChanged
    case saveFailed
    case cancelled
}

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextActionResolution: Equatable, Sendable {
    case success(String)
    case failure(IOSVoiceDraftTextActionFailure)
}

@_spi(HoldTypeIOSCore)
public struct IOSVoiceDraftTextActionRequest: Sendable {
    public let action: IOSVoiceDraftTextAction
    public let text: String
    public let settings: IOSAppSettings
    public let credential: IOSResolvedOpenAICredential
    public let consentObservation: IOSV1ProviderConsentObservation

    public init(
        action: IOSVoiceDraftTextAction,
        text: String,
        settings: IOSAppSettings,
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSV1ProviderConsentObservation
    ) {
        self.action = action
        self.text = text
        self.settings = settings
        self.credential = credential
        self.consentObservation = consentObservation
    }
}

extension IOSVoiceDraftTextActionRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSVoiceDraftTextActionRequest(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// One process-owned provider pipeline. Durable Pending is the only recovery
/// source: every failed active operation is reduced to `.failed`, and provider
/// work can start again only through a new explicit `.retry` request.
@_spi(HoldTypeIOSCore)
public actor IOSForegroundVoiceProcessor {
    typealias UsageRecorder = @Sendable (
        SuccessfulTranscriptionUsage
    ) async -> Void
    typealias ProviderRejectionRecorder = @Sendable (
        IOSOpenAICredentialGeneration
    ) async -> Void

    private let persistenceOwner: any IOSForegroundVoicePersisting
    private let consentCoordinator: IOSV1ProviderConsentCoordinator
    private let stageExecutor: IOSProviderConsentStageExecutor
    private let provider: IOSForegroundVoiceOpenAIProviderOperations
    private let recordUsage: UsageRecorder
    private let recordProviderRejection: ProviderRejectionRecorder
    private let makeUUID: @Sendable () -> UUID
    private let postProcessor: TranscriptTextPostProcessor

    private var activeOperationID: UUID?

    public init(
        persistenceOwner: IOSV1ForegroundVoicePersistenceOwner,
        consentCoordinator: IOSV1ProviderConsentCoordinator,
        usageRecordingClient: IOSTranscriptionUsageRecordingClient,
        credentialCoordinator: IOSOpenAICredentialCoordinator
    ) {
        self.persistenceOwner = persistenceOwner
        self.consentCoordinator = consentCoordinator
        stageExecutor = IOSProviderConsentStageExecutor(
            consentCoordinator: consentCoordinator
        )
        provider = IOSForegroundVoiceOpenAIProviderOperations()
        recordUsage = { usage in
            await usageRecordingClient.record(usage)
        }
        recordProviderRejection = { generation in
            await credentialCoordinator.recordProviderRejection(
                for: generation
            )
        }
        makeUUID = { UUID() }
        postProcessor = TranscriptTextPostProcessor()
    }

    /// Test-only convenience. Production composition injects one shared
    /// recording client so failures are ordered against Reset.
    init(
        persistenceOwner: IOSV1ForegroundVoicePersistenceOwner,
        consentCoordinator: IOSV1ProviderConsentCoordinator,
        usageRepository: IOSTranscriptionUsageRepository,
        credentialCoordinator: IOSOpenAICredentialCoordinator
    ) {
        self.init(
            persistenceOwner: persistenceOwner,
            consentCoordinator: consentCoordinator,
            usageRecordingClient: IOSTranscriptionUsageRecordingClient(
                repository: usageRepository,
                reportFailure: { _ in }
            ),
            credentialCoordinator: credentialCoordinator
        )
    }

    init(
        persistenceOwner: any IOSForegroundVoicePersisting,
        consentCoordinator: IOSV1ProviderConsentCoordinator,
        provider: IOSForegroundVoiceOpenAIProviderOperations,
        recordUsage: @escaping UsageRecorder = { _ in },
        recordProviderRejection:
            @escaping ProviderRejectionRecorder = { _ in },
        makeUUID: @escaping @Sendable () -> UUID = { UUID() },
        postProcessor: TranscriptTextPostProcessor =
            TranscriptTextPostProcessor()
    ) {
        self.persistenceOwner = persistenceOwner
        self.consentCoordinator = consentCoordinator
        stageExecutor = IOSProviderConsentStageExecutor(
            consentCoordinator: consentCoordinator
        )
        self.provider = provider
        self.recordUsage = recordUsage
        self.recordProviderRejection = recordProviderRejection
        self.makeUUID = makeUUID
        self.postProcessor = postProcessor
    }

    public func process(
        _ request: IOSForegroundVoiceProcessingRequest,
        progress: @escaping IOSForegroundVoiceProcessingProgressHandler = {
            _ in
        }
    ) async -> IOSForegroundVoiceProcessingResolution {
        guard activeOperationID == nil else { return .busy }
        guard let context = makeContext(from: request) else {
            return .notStarted(.invalidConfiguration)
        }
        guard consentCoordinator.makeAuthorization(
            from: context.consentObservation
        ) != nil else {
            return .notStarted(.providerConsentUnavailable)
        }

        let operationID = UUID()
        activeOperationID = operationID
        defer {
            if activeOperationID == operationID {
                activeOperationID = nil
            }
        }
        return await run(
            context,
            operationID: operationID,
            progress: progress
        )
    }

    /// Runs a provider-only action against an existing app-private Draft. This
    /// shares the Voice processor's operation gate but never creates Pending,
    /// transcription usage, Latest, or History state.
    @_spi(HoldTypeIOSCore)
    public func processDraftText(
        _ request: IOSVoiceDraftTextActionRequest
    ) async -> IOSVoiceDraftTextActionResolution {
        guard activeOperationID == nil else { return .failure(.busy) }
        guard let source = try? AcceptedTranscript(rawText: request.text) else {
            return .failure(.invalidText)
        }
        guard let authorization = consentCoordinator.makeAuthorization(
            from: request.consentObservation
        ) else {
            return .failure(.consentUnavailable)
        }
        if request.action == .translate,
           !request.settings.translationConfiguration.isConfigurationReady {
            return .failure(.invalidConfiguration)
        }

        let operationID = UUID()
        activeOperationID = operationID
        defer {
            if activeOperationID == operationID {
                activeOperationID = nil
            }
        }

        let outcome = await runDraftTextAction(
            request,
            source: source,
            authorization: authorization
        )
        guard activeOperationID == operationID, !Task.isCancelled else {
            return .failure(.cancelled)
        }
        return outcome
    }

    private func runDraftTextAction(
        _ request: IOSVoiceDraftTextActionRequest,
        source: AcceptedTranscript,
        authorization: IOSV1ProviderConsentAuthorization
    ) async -> IOSVoiceDraftTextActionResolution {
        let provider = provider
        let credential = request.credential.credential
        let outcome: IOSProviderConsentStageOutcome<
            AcceptedTranscript,
            IOSForegroundVoiceProviderFailure
        >

        switch request.action {
        case .correct:
            var configuration = request.settings.textCorrectionConfiguration
            configuration.isEnabled = true
            let correctionConfiguration = configuration
            outcome = await stageExecutor.execute(
                authorization,
                for: .correction,
                operation: {
                    try AcceptedTranscript(
                        rawText: try await provider.correct(
                            source,
                            correctionConfiguration,
                            credential
                        )
                    )
                },
                normalizeFailure: {
                    IOSForegroundVoiceProviderFailureMapper.correction($0)
                }
            )
        case .translate:
            let translationRequest = TextTranslationRequest(
                acceptedTranscript: source,
                translationConfiguration:
                    request.settings.translationConfiguration,
                transcriptionConfiguration:
                    request.settings.transcriptionConfiguration
            )
            outcome = await stageExecutor.execute(
                authorization,
                for: .translation,
                operation: {
                    try AcceptedTranscript(
                        rawText: try await provider.translate(
                            translationRequest,
                            credential
                        )
                    )
                },
                normalizeFailure: {
                    IOSForegroundVoiceProviderFailureMapper.translation($0)
                }
            )
        }

        switch outcome {
        case .success(let result):
            return acceptedDraftTextActionResult(
                result,
                source: source,
                action: request.action,
                settings: request.settings
            )
        case .failure(let failure):
            if failure == .credentialRejected {
                await recordProviderRejection(request.credential.generation)
            }
            return .failure(Self.draftTextActionFailure(from: failure))
        case .cancelled:
            return .failure(.cancelled)
        case .authorizationUnavailable:
            return .failure(.consentUnavailable)
        }
    }

    private func acceptedDraftTextActionResult(
        _ result: AcceptedTranscript,
        source: AcceptedTranscript,
        action: IOSVoiceDraftTextAction,
        settings: IOSAppSettings
    ) -> IOSVoiceDraftTextActionResolution {
        if action == .correct,
           !Self.isSafeCorrection(
               original: source.text,
               corrected: result.text
           ) {
            return .success(source.text)
        }
        guard action == .translate, settings.localTextCleanupEnabled else {
            return .success(result.text)
        }
        let normalized = TranscriptTextPostProcessor
            .normalizedInformalTypography(
                from: result.text,
                fallback: result.text
            )
        guard let accepted = try? AcceptedTranscript(rawText: normalized) else {
            return .failure(.invalidResponse)
        }
        return .success(accepted.text)
    }

    private static func draftTextActionFailure(
        from failure: IOSForegroundVoiceProviderFailure
    ) -> IOSVoiceDraftTextActionFailure {
        switch failure {
        case .credentialMissing, .credentialUnavailable, .credentialRejected:
            .credentialUnavailable
        case .networkUnavailable:
            .networkUnavailable
        case .timedOut:
            .timedOut
        case .invalidRequest, .invalidTranslationRoute:
            .invalidConfiguration
        case .invalidResponse, .emptyResult, .dictionaryEcho, .contextEcho:
            .invalidResponse
        case .cancelled:
            .cancelled
        case .networkFailure, .rateLimited, .providerUnavailable,
             .badRequest, .providerRejected, .unknown:
            .providerUnavailable
        case .invalidRecording, .multipartMetadataTooLarge:
            .invalidResponse
        }
    }

    private func run(
        _ context: IOSForegroundVoicePipelineContext,
        operationID: UUID,
        progress: @escaping IOSForegroundVoiceProcessingProgressHandler
    ) async -> IOSForegroundVoiceProcessingResolution {
        guard activeOperationID == operationID, !Task.isCancelled else {
            return .notStarted(.cancelled)
        }

        let dispatchSource: IOSV1PendingRecording
        switch context.mode {
        case .initial:
            dispatchSource = context.pendingRecording
        case .retry where context.pendingRecording.phase == .readyForTranscription:
            do {
                let failed = try await persistenceOwner.markFailed(
                    expected: IOSV1PendingRecordingExpectation(
                        recording: context.pendingRecording
                    )
                )
                dispatchSource = try await canonicalRecording(
                    continuing: failed,
                    phase: .failed
                )
            } catch {
                guard let observed = try? await persistenceOwner.load()?.recording,
                      Self.continuesAttempt(
                          observed,
                          from: context.pendingRecording
                      ),
                      observed.phase == .failed else {
                    return .notStarted(.localPersistence)
                }
                dispatchSource = observed
            }
        case .retry:
            dispatchSource = context.pendingRecording
        }

        let dispatch: IOSV1ForegroundVoiceTranscriptionDispatch
        do {
            switch context.mode {
            case .initial:
                dispatch = try await persistenceOwner.beginTranscription(
                    expected: IOSV1PendingRecordingExpectation(
                        recording: dispatchSource
                    ),
                    transcriptionID: context.transcriptionID
                )
            case .retry:
                dispatch = try await persistenceOwner.retryTranscription(
                    expected: IOSV1PendingRecordingExpectation(
                        recording: dispatchSource
                    ),
                    transcriptionID: context.transcriptionID,
                    transcriptionConfiguration:
                        context.transcriptionConfiguration
                )
            }
        } catch {
            return await reconcileBeginFailure(
                context,
                dispatchSource: dispatchSource
            )
        }

        let transcribing: IOSV1PendingRecording
        do {
            transcribing = try await canonicalRecording(
                continuing: dispatch.recording,
                phase: .transcribing
            )
        } catch {
            return await persistFailure(
                from: dispatch.recording,
                failure: .localPersistence,
                stage: .transcription
            )
        }
        guard activeOperationID == operationID, !Task.isCancelled else {
            return await persistFailure(
                from: transcribing,
                failure: .cancelled,
                stage: .transcription
            )
        }
        await progress(.transcription)
        guard activeOperationID == operationID, !Task.isCancelled else {
            return await persistFailure(
                from: transcribing,
                failure: .cancelled,
                stage: .transcription
            )
        }
        guard let authorization = consentCoordinator.makeAuthorization(
            from: context.consentObservation
        ) else {
            return await persistFailure(
                from: transcribing,
                failure: .providerConsentUnavailable,
                stage: .transcription
            )
        }

        let executor = IOSForegroundVoiceTranscriptionExecutor(
            authorization: authorization,
            stageExecutor: stageExecutor,
            provider: provider,
            credential: context.credential.credential,
            promptComposition: context.promptComposition
        )
        let transcript: AcceptedTranscript
        do {
            transcript = try AcceptedTranscript(
                rawText: try await dispatch.execute(using: executor)
            )
        } catch let error as IOSForegroundVoiceTranscriptionStageError {
            let failure: IOSForegroundVoiceProcessingFailure
            switch error {
            case .failure(let providerFailure):
                await recordCredentialRejectionIfNeeded(
                    providerFailure,
                    context: context
                )
                failure = providerFailure.publicFailure
            case .cancelled:
                failure = .cancelled
            case .authorizationUnavailable:
                failure = .providerConsentUnavailable
            }
            return await persistFailure(
                from: transcribing,
                failure: Task.isCancelled ? .cancelled : failure,
                stage: .transcription
            )
        } catch {
            return await persistFailure(
                from: transcribing,
                failure: Task.isCancelled ? .cancelled : .invalidRecording,
                stage: .transcription
            )
        }

        await recordSuccessfulTranscriptionUsage(
            context: context,
            recording: transcribing
        )
        guard !Task.isCancelled else {
            return await persistFailure(
                from: transcribing,
                failure: .cancelled,
                stage: .transcription
            )
        }

        let postProcessing: IOSV1PendingRecording
        do {
            postProcessing = try await advanceToPostProcessing(transcribing)
        } catch {
            return await persistFailure(
                from: transcribing,
                failure: .localPersistence,
                stage: .transcription
            )
        }
        await progress(.postProcessing)
        guard !Task.isCancelled else {
            return await persistFailure(
                from: postProcessing,
                failure: .cancelled,
                stage: .postProcessing
            )
        }

        let finalText: AcceptedTranscript
        switch await makeFinalText(
            transcript,
            context: context,
            recording: postProcessing
        ) {
        case .success(let value):
            finalText = value
        case .failure(let failure):
            return await persistFailure(
                from: postProcessing,
                failure: failure,
                stage: .postProcessing
            )
        }

        let outputDelivery: IOSV1PendingRecording
        do {
            outputDelivery = try await advanceToOutputDelivery(postProcessing)
        } catch {
            return await persistFailure(
                from: postProcessing,
                failure: .localPersistence,
                stage: .postProcessing
            )
        }
        await progress(.outputDelivery)
        guard !Task.isCancelled else {
            return await persistFailure(
                from: outputDelivery,
                failure: .cancelled,
                stage: .outputDelivery
            )
        }

        let preparation: IOSV1ForegroundVoiceAcceptedOutputPreparation
        do {
            preparation = try IOSV1ForegroundVoiceAcceptedOutputPreparation(
                deliveryID: context.deliveryID,
                sessionID: context.sessionID,
                attemptID: outputDelivery.attemptID,
                transcriptID: context.transcriptionID,
                rawAcceptedText: finalText.text,
                outputIntent: context.outputIntent
            )
        } catch {
            return await persistFailure(
                from: outputDelivery,
                failure: .invalidConfiguration,
                stage: .outputDelivery
            )
        }

        do {
            return .acceptance(
                try await persistenceOwner.accept(
                    preparation,
                    expectedPending: IOSV1PendingRecordingExpectation(
                        recording: outputDelivery
                    )
                )
            )
        } catch {
            do {
                if let result = try await persistenceOwner
                    .reconcileAcceptance(matching: preparation) {
                    return .acceptance(result)
                }
            } catch {
                if await acceptanceCleanupIsPending(
                    attemptID: outputDelivery.attemptID
                ) {
                    return .notStarted(.localPersistence)
                }
            }
            return await persistFailure(
                from: outputDelivery,
                failure: .localPersistence,
                stage: .outputDelivery
            )
        }
    }

    private func makeFinalText(
        _ transcript: AcceptedTranscript,
        context: IOSForegroundVoicePipelineContext,
        recording: IOSV1PendingRecording
    ) async -> IOSForegroundVoiceTextResolution {
        guard !Task.isCancelled else { return .failure(.cancelled) }

        let corrected = await correctedTranscript(transcript, context: context)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let processedText = postProcessor.process(
            corrected.text,
            configuration: context.postProcessingConfiguration,
            fallback: corrected.text
        )
        guard let processed = try? AcceptedTranscript(rawText: processedText)
        else {
            return .failure(.invalidConfiguration)
        }

        switch recording.outputIntent {
        case .standard:
            return .success(processed)
        case .translate:
            return await translatedTranscript(processed, context: context)
        }
    }

    private func correctedTranscript(
        _ transcript: AcceptedTranscript,
        context: IOSForegroundVoicePipelineContext
    ) async -> AcceptedTranscript {
        guard context.correctionConfiguration.isEnabled,
              let authorization = consentCoordinator.makeAuthorization(
                  from: context.consentObservation
              ) else {
            return transcript
        }
        let provider = provider
        let credential = context.credential.credential
        let configuration = context.correctionConfiguration
        let outcome: IOSProviderConsentStageOutcome<
            AcceptedTranscript,
            IOSForegroundVoiceProviderFailure
        > = await stageExecutor.execute(
            authorization,
            for: .correction,
            operation: {
                try AcceptedTranscript(
                    rawText: try await provider.correct(
                        transcript,
                        configuration,
                        credential
                    )
                )
            },
            normalizeFailure: {
                IOSForegroundVoiceProviderFailureMapper.correction($0)
            }
        )
        switch outcome {
        case .success(let candidate)
            where Self.isSafeCorrection(
                original: transcript.text,
                corrected: candidate.text
            ):
            return candidate
        case .failure(let failure):
            await recordCredentialRejectionIfNeeded(failure, context: context)
            return transcript
        case .success, .cancelled, .authorizationUnavailable:
            return transcript
        }
    }

    private func translatedTranscript(
        _ transcript: AcceptedTranscript,
        context: IOSForegroundVoicePipelineContext
    ) async -> IOSForegroundVoiceTextResolution {
        guard let translation = context.translationConfiguration else {
            return .failure(.invalidConfiguration)
        }
        guard let authorization = consentCoordinator.makeAuthorization(
            from: context.consentObservation
        ) else {
            return .failure(.providerConsentUnavailable)
        }
        let provider = provider
        let credential = context.credential.credential
        let transcriptionConfiguration = context.transcriptionConfiguration
        let outcome: IOSProviderConsentStageOutcome<
            AcceptedTranscript,
            IOSForegroundVoiceProviderFailure
        > = await stageExecutor.execute(
            authorization,
            for: .translation,
            operation: {
                try AcceptedTranscript(
                    rawText: try await provider.translate(
                        TextTranslationRequest(
                            acceptedTranscript: transcript,
                            translationConfiguration: translation,
                            transcriptionConfiguration:
                                transcriptionConfiguration
                        ),
                        credential
                    )
                )
            },
            normalizeFailure: {
                IOSForegroundVoiceProviderFailureMapper.translation($0)
            }
        )
        guard !Task.isCancelled else { return .failure(.cancelled) }
        switch outcome {
        case .success(let translated):
            guard context.postProcessingConfiguration
                .localTextCleanupEnabled else {
                return .success(translated)
            }
            let normalized = TranscriptTextPostProcessor
                .normalizedInformalTypography(
                    from: translated.text,
                    fallback: translated.text
                )
            guard let accepted = try? AcceptedTranscript(rawText: normalized)
            else { return .failure(.invalidResponse) }
            return .success(accepted)
        case .failure(let failure):
            await recordCredentialRejectionIfNeeded(failure, context: context)
            return .failure(failure.publicFailure)
        case .cancelled:
            return .failure(.cancelled)
        case .authorizationUnavailable:
            return .failure(.providerConsentUnavailable)
        }
    }

    private func reconcileBeginFailure(
        _ context: IOSForegroundVoicePipelineContext,
        dispatchSource: IOSV1PendingRecording
    ) async -> IOSForegroundVoiceProcessingResolution {
        let observation: IOSV1PendingRecordingObservation?
        do {
            observation = try await persistenceOwner.load()
        } catch {
            return .notStarted(.localPersistence)
        }
        guard let current = observation?.recording,
              Self.continuesAttempt(
                  current,
                  from: dispatchSource
              ) else {
            return .notStarted(.localPersistence)
        }
        return await persistFailure(
            from: current,
            failure: Task.isCancelled ? .cancelled : .localPersistence,
            stage: .transcription
        )
    }

    private func advanceToPostProcessing(
        _ source: IOSV1PendingRecording
    ) async throws -> IOSV1PendingRecording {
        do {
            let advanced = try await persistenceOwner.markPostProcessing(
                expected: IOSV1PendingRecordingExpectation(recording: source)
            )
            return try await canonicalRecording(
                continuing: advanced,
                phase: .postProcessing
            )
        } catch {
            guard let current = try await persistenceOwner.load()?.recording,
                  Self.continuesAttempt(current, from: source),
                  current.phase == .postProcessing,
                  current.transcriptionID == source.transcriptionID else {
                throw error
            }
            return current
        }
    }

    private func advanceToOutputDelivery(
        _ source: IOSV1PendingRecording
    ) async throws -> IOSV1PendingRecording {
        do {
            let advanced = try await persistenceOwner.markOutputDelivery(
                expected: IOSV1PendingRecordingExpectation(recording: source)
            )
            return try await canonicalRecording(
                continuing: advanced,
                phase: .outputDelivery
            )
        } catch {
            guard let current = try await persistenceOwner.load()?.recording,
                  Self.continuesAttempt(current, from: source),
                  current.phase == .outputDelivery,
                  current.transcriptionID == source.transcriptionID else {
                throw error
            }
            return current
        }
    }

    private func persistFailure(
        from source: IOSV1PendingRecording,
        failure: IOSForegroundVoiceProcessingFailure,
        stage: VoiceAttemptStage
    ) async -> IOSForegroundVoiceProcessingResolution {
        let current: IOSV1PendingRecording
        do {
            guard let observed = try await persistenceOwner.load()?.recording,
                  Self.continuesAttempt(observed, from: source) else {
                return .notStarted(.localPersistence)
            }
            current = observed
        } catch {
            return .notStarted(.localPersistence)
        }
        if current.phase == .failed {
            return .retryAvailable(current, failure: failure, stage: stage)
        }
        guard current.phase != .acceptedCleanup else {
            return .notStarted(.localPersistence)
        }

        let owner = persistenceOwner
        let expectation = IOSV1PendingRecordingExpectation(recording: current)
        let result = await Task {
            try await owner.markFailed(expected: expectation)
        }.result
        if case .success(let failed) = result,
           let canonical = try? await canonicalRecording(
               continuing: failed,
               phase: .failed
           ) {
            return .retryAvailable(canonical, failure: failure, stage: stage)
        }
        if let observed = try? await persistenceOwner.load()?.recording,
           Self.continuesAttempt(observed, from: source),
           observed.phase == .failed {
            return .retryAvailable(observed, failure: failure, stage: stage)
        }
        return .notStarted(.localPersistence)
    }

    private func canonicalRecording(
        continuing source: IOSV1PendingRecording,
        phase: IOSV1PendingRecordingPhase
    ) async throws -> IOSV1PendingRecording {
        guard let current = try await persistenceOwner.load()?.recording,
              Self.continuesAttempt(current, from: source),
              current.phase == phase,
              current.transcriptionID == source.transcriptionID else {
            throw IOSForegroundVoiceCanonicalizationError.unavailable
        }
        return current
    }

    private func acceptanceCleanupIsPending(attemptID: UUID) async -> Bool {
        let observation: IOSV1PendingRecordingObservation?
        do {
            observation = try await persistenceOwner.load()
        } catch {
            return false
        }
        guard let recording = observation?.recording else { return false }
        return recording.attemptID == attemptID
            && recording.phase == .acceptedCleanup
    }

    private func makeContext(
        from request: IOSForegroundVoiceProcessingRequest
    ) -> IOSForegroundVoicePipelineContext? {
        let pending = request.pendingRecording
        switch request.mode {
        case .initial:
            guard pending.phase == .readyForTranscription,
                  pending.transcriptionID == nil else { return nil }
        case .retry:
            guard (pending.phase == .readyForTranscription
                    || pending.phase == .failed),
                  pending.transcriptionID == nil else { return nil }
        }
        let transcription = request.settings.transcriptionConfiguration
        guard !transcription.customLanguageCodeValidation.isInvalid else {
            return nil
        }
        if request.mode == .initial {
            guard pending.transcriptionModel == transcription.resolvedModel,
                  pending.transcriptionLanguageCode
                    == transcription.resolvedLanguageCode else {
                return nil
            }
        }

        let translation: TranslationConfiguration?
        switch pending.outputIntent {
        case .standard:
            translation = nil
        case .translate:
            guard request.settings.translationConfiguration.isConfigurationReady else {
                return nil
            }
            translation = request.settings.translationConfiguration
        }
        var correction = request.settings.textCorrectionConfiguration
        if request.forcesTextCorrection {
            correction.isEnabled = true
        }
        return IOSForegroundVoicePipelineContext(
            sessionID: request.sessionID,
            pendingRecording: pending,
            mode: request.mode,
            transcriptionConfiguration: transcription,
            correctionConfiguration: correction,
            translationConfiguration: translation,
            postProcessingConfiguration:
                TranscriptPostProcessingConfiguration(
                    localTextCleanupEnabled:
                        request.settings.localTextCleanupEnabled,
                    emojiCommands:
                        request.library.emojiCommandsConfiguration,
                    textReplacementRules: request.library.replacementRules
                ),
            promptComposition: TranscriptionPromptComposition(
                resolvedFreeformPrompt:
                    transcription.resolvedFreeformPrompt,
                context: nil,
                emojiCommandsConfiguration:
                    request.library.emojiCommandsConfiguration,
                customDictionary: request.library.customDictionary
            ),
            credential: request.credential,
            consentObservation: request.consentObservation,
            transcriptionID: makeUUID(),
            deliveryID: makeUUID()
        )
    }

    private func recordCredentialRejectionIfNeeded(
        _ failure: IOSForegroundVoiceProviderFailure,
        context: IOSForegroundVoicePipelineContext
    ) async {
        guard failure == .credentialRejected else { return }
        await recordProviderRejection(context.credential.generation)
    }

    private func recordSuccessfulTranscriptionUsage(
        context: IOSForegroundVoicePipelineContext,
        recording: IOSV1PendingRecording
    ) async {
        guard let usage = try? SuccessfulTranscriptionUsage(
            transcriptionID: context.transcriptionID,
            model: recording.transcriptionModel,
            audioDuration:
                TimeInterval(recording.durationMilliseconds) / 1_000
        ) else { return }
        let recorder = recordUsage
        await Task { await recorder(usage) }.value
    }

    private static func continuesAttempt(
        _ candidate: IOSV1PendingRecording,
        from source: IOSV1PendingRecording
    ) -> Bool {
        candidate.attemptID == source.attemptID
            && candidate.audioRelativeIdentifier
                == source.audioRelativeIdentifier
            && candidate.createdAt == source.createdAt
            && candidate.updatedAt.timeIntervalSince(source.updatedAt)
                >= -0.001
            && candidate.outputIntent == source.outputIntent
            && candidate.transcriptionModel == source.transcriptionModel
            && candidate.transcriptionLanguageCode
                == source.transcriptionLanguageCode
            && candidate.durationMilliseconds == source.durationMilliseconds
            && candidate.byteCount == source.byteCount
    }

    private static func isSafeCorrection(
        original: String,
        corrected: String
    ) -> Bool {
        guard let normalized = AcceptedTranscript.nonEmptyNormalizedText(
            from: corrected
        ) else {
            return false
        }
        guard original.count >= 20 else { return true }
        return normalized.count >= max(1, original.count / 3)
            && normalized.count <= original.count * 3
    }
}

private struct IOSForegroundVoicePipelineContext: Sendable {
    let sessionID: UUID
    let pendingRecording: IOSV1PendingRecording
    let mode: IOSForegroundVoiceProcessingMode
    let transcriptionConfiguration: TranscriptionConfiguration
    let correctionConfiguration: TextCorrectionConfiguration
    let translationConfiguration: TranslationConfiguration?
    let postProcessingConfiguration: TranscriptPostProcessingConfiguration
    let promptComposition: TranscriptionPromptComposition
    let credential: IOSResolvedOpenAICredential
    let consentObservation: IOSV1ProviderConsentObservation
    let transcriptionID: UUID
    let deliveryID: UUID

    var outputIntent: DictationOutputIntent {
        pendingRecording.outputIntent
    }
}

private enum IOSForegroundVoiceTextResolution: Sendable {
    case success(AcceptedTranscript)
    case failure(IOSForegroundVoiceProcessingFailure)
}

private enum IOSForegroundVoiceCanonicalizationError: Error {
    case unavailable
}

extension IOSForegroundVoiceProcessor:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public nonisolated var description: String {
        "IOSForegroundVoiceProcessor(redacted)"
    }

    public nonisolated var debugDescription: String { description }
    public nonisolated var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}
