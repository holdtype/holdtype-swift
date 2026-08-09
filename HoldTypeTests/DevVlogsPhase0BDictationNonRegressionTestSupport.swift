#if DEBUG
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Synchronization
import Testing
@testable import HoldType

enum DevVlogsPhase0BE07CaseID: String, CaseIterable { case standard_success, corrected_success, translated_success, explicit_cancel, camera_unavailable, camera_busy, camera_slow_timeout, destination_unavailable, destination_disconnect, mux_failure }
enum DevVlogsPhase0BE07AttemptMode { case baseline, spike }
enum DevVlogsPhase0BE07ActionState: Equatable { case idle, recording, transcribing, success }
enum DevVlogsPhase0BE07DictationTerminal: String, Equatable { case success, cancelled }
enum DevVlogsPhase0BE07AudioOwner: Equatable { case dictationRecorder }
enum DevVlogsPhase0BE07ArtifactIdentity: String, Equatable { case none, dictationAudio }
enum DevVlogsPhase0BE07AcceptedOutputClass: Equatable { case none, standard, corrected, translated }
enum DevVlogsPhase0BE07TerminalCause: Equatable { case none, userFinished, explicitUserDiscard }
enum DevVlogsPhase0BE07Durability: Equatable { case none, historyCheckpoint, explicitlyDiscarded }
enum DevVlogsPhase0BE07ObserverPhase: Equatable { case disabled, idle, preparing, capturing, finalizing, ready, failed, cancelled, cleaned }
enum DevVlogsPhase0BE07ObserverTerminal: String, Equatable { case disabled, ready, cancelled, cameraUnavailable, cameraBusy, cameraPreparationTimedOut, destinationUnavailable, destinationDisconnected, muxFailed }
enum DevVlogsPhase0BE07ObserverCallResult: Equatable { case continued, terminal(DevVlogsPhase0BE07ObserverTerminal), rejectedLateDuplicate(DevVlogsPhase0BE07ObserverTerminal) }
enum DevVlogsPhase0BE07GateResolution { case ready, timedOut }
struct DevVlogsPhase0BE07GateSnapshot: Equatable { let enterCount: Int; let resolutionCount: Int; let waiterCount: Int; let isResolved: Bool; let pendingContinuationCount: Int; let openSuspendingMethodCount: Int; let isClosed: Bool }
struct DevVlogsPhase0BE07AccessSnapshot: Equatable { let acquireCount: Int; let releaseCount: Int; let outstandingCount: Int }
struct DevVlogsPhase0BE07TemporaryAudioAccess { let identity: DevVlogsPhase0BE07ArtifactIdentity; let accessID: Int; let artifact: AudioRecordingArtifact }
struct DevVlogsPhase0BE07ObserverSnapshot: Equatable { let phases: [DevVlogsPhase0BE07ObserverPhase]; let terminal: DevVlogsPhase0BE07ObserverTerminal; let terminalCount: Int; let cleanupCount: Int; let lateDuplicateRejectedCount: Int; let accessAcquireCount: Int; let accessReleaseCount: Int; let outstandingAccessCount: Int; let outstandingTaskCount: Int }
struct DevVlogsPhase0BE07DictationSnapshot: Equatable {
    let actionStates: [DevVlogsPhase0BE07ActionState]; let terminal: DevVlogsPhase0BE07DictationTerminal; let audioOwner: DevVlogsPhase0BE07AudioOwner; let microphoneOwnerCount: Int
    let recorderStartCount: Int; let recorderStopCount: Int; let recorderCancelCount: Int; let preparedArtifactIdentity: DevVlogsPhase0BE07ArtifactIdentity; let finalizedArtifactIdentity: DevVlogsPhase0BE07ArtifactIdentity
    let settingsSnapshotCount: Int; let credentialResolutionCount: Int; let credentialConsumerCheckCount: Int; let credentialMismatchCount: Int
    let journalPrepareCount: Int; let journalReleaseCount: Int; let journalDiscardCount: Int; let journalOutstandingCount: Int
    let recoveryCheckpointCount: Int; let recoveryRemoveCount: Int; let recoveryOutstandingCount: Int
    let providerAuthorizationDecisionCount: Int; let providerAuthorized: Bool; let providerSealCount: Int; let providerDispatchEventCount: Int; let providerRequestCount: Int; let providerAcceptCount: Int; let providerRequestArtifactIdentity: DevVlogsPhase0BE07ArtifactIdentity
    let correctionCount: Int; let remoteCorrectionEnabled: Bool; let translationCount: Int; let usageCount: Int; let acceptedOutputClass: DevVlogsPhase0BE07AcceptedOutputClass; let lastTranscriptAcceptedCount: Int; let historyCount: Int; let outputCount: Int; let cacheCount: Int
    let terminalCause: DevVlogsPhase0BE07TerminalCause; let terminalDurability: DevVlogsPhase0BE07Durability; let durationMonitorStartCount: Int; let durationMonitorStopCount: Int; let terminalActionCompletedWithObservedResourcesClosed: Bool; let providerOutstandingCount: Int; let outstandingTaskCount: Int
}
struct DevVlogsPhase0BE07AttemptSnapshot: Equatable { let dictation: DevVlogsPhase0BE07DictationSnapshot; let observer: DevVlogsPhase0BE07ObserverSnapshot }
struct DevVlogsPhase0BE07PairResult: Equatable { let caseID: DevVlogsPhase0BE07CaseID; let baseline: DevVlogsPhase0BE07AttemptSnapshot; let spike: DevVlogsPhase0BE07AttemptSnapshot; let dictationSnapshotsEqual: Bool }
enum DevVlogsPhase0BE07AccessError: Error { case artifactMismatch, unavailable, alreadyAcquired, invalidRelease, alreadyReleased }
enum DevVlogsPhase0BE07GateError: Error { case duplicateEntry, duplicateResolution }
enum DevVlogsPhase0BE07HarnessError: Error { case unsupportedCase, providerReleaseBeforeDispatch, missingCompletedArtifact, snapshotMismatch, unexpectedTerminal, outstandingResource }
enum DevVlogsPhase0BE07EvidenceValidationError: Error { case missingFile, unexpectedFile, oversizedFile, symlinkNotAllowed, invalidHeading, invalidSchema, duplicateKey, invalidCardinality, invalidOrder, forbiddenContent }

final class DevVlogsPhase0BE07TemporaryAccessToken {
    private let completedArtifact: AudioRecordingArtifact; private let identity: DevVlogsPhase0BE07ArtifactIdentity; private var acquired = false; private var released = false
    init(completedArtifact: AudioRecordingArtifact, identity: DevVlogsPhase0BE07ArtifactIdentity) { self.completedArtifact = completedArtifact; self.identity = identity }
    func acquire(completedArtifact: AudioRecordingArtifact) throws -> DevVlogsPhase0BE07TemporaryAudioAccess { guard completedArtifact == self.completedArtifact else { throw DevVlogsPhase0BE07AccessError.artifactMismatch }; guard !acquired else { throw DevVlogsPhase0BE07AccessError.alreadyAcquired }; guard !released else { throw DevVlogsPhase0BE07AccessError.unavailable }; acquired = true; return .init(identity: identity, accessID: 1, artifact: completedArtifact) }
    func release(_ access: DevVlogsPhase0BE07TemporaryAudioAccess) throws { guard acquired, access.accessID == 1, access.artifact == completedArtifact else { throw DevVlogsPhase0BE07AccessError.invalidRelease }; guard !released else { throw DevVlogsPhase0BE07AccessError.alreadyReleased }; released = true }
    func snapshot() -> DevVlogsPhase0BE07AccessSnapshot { .init(acquireCount: acquired ? 1 : 0, releaseCount: released ? 1 : 0, outstandingCount: acquired && !released ? 1 : 0) }
}

@available(macOS 15.0, *)
actor DevVlogsPhase0BE07SlowPreparationGate {
    private var enterCount = 0; private var resolutionCount = 0; private var waiterCount = 0; private var isResolved = false
    nonisolated let waitState: Mutex<(entryContinuation: CheckedContinuation<Void, Error>?, resolutionContinuation: CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>?, entryWaitOpen: Bool, resolutionWaitOpen: Bool, cancellationRequested: Bool, isClosed: Bool)> = Mutex((nil, nil, false, false, false, false))
    func waitUntilEntered() async throws {
        if enterCount == 1 { try Task.checkCancellation(); guard !waitState.withLock({ $0.cancellationRequested }) else { throw CancellationError() }; return }
        let opened = waitState.withLock { state -> Bool in guard !state.entryWaitOpen, state.entryContinuation == nil else { return false }; state.entryWaitOpen = true; return true }
        guard opened else { throw DevVlogsPhase0BE07GateError.duplicateEntry }
        do {
            try await withTaskCancellationHandler(operation: {
                let cancelled = Task.isCancelled
                try await withCheckedThrowingContinuation { continuation in
                    let immediate = waitState.withLock { state -> CheckedContinuation<Void, Error>? in
                        if cancelled || state.cancellationRequested { state.cancellationRequested = true; return continuation }
                        state.entryContinuation = continuation; return nil
                    }
                    immediate?.resume(throwing: CancellationError())
                }
            }, onCancel: {
                let continuation = waitState.withLock { state -> CheckedContinuation<Void, Error>? in guard state.entryWaitOpen, !state.isClosed else { return nil }; state.cancellationRequested = true; let value = state.entryContinuation; state.entryContinuation = nil; return value }
                continuation?.resume(throwing: CancellationError())
            })
        } catch {
            let resolution = waitState.withLock { state -> CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>? in state.entryWaitOpen = false; state.entryContinuation = nil; let value = state.resolutionContinuation; state.resolutionContinuation = nil; state.resolutionWaitOpen = false; state.isClosed = true; return value }
            resolution?.resume(throwing: CancellationError()); waiterCount = 0; throw error
        }
        let closure = waitState.withLock { state -> (CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>?, Bool) in
            let shouldCancel = Task.isCancelled || state.cancellationRequested; state.entryWaitOpen = false; state.entryContinuation = nil
            if shouldCancel { let value = state.resolutionContinuation; state.resolutionContinuation = nil; state.resolutionWaitOpen = false; state.isClosed = true; return (value, true) }
            return (nil, false)
        }
        closure.0?.resume(throwing: CancellationError()); if closure.1 { waiterCount = 0; throw CancellationError() }
    }
    func enterAndWaitForResolution() async throws {
        guard enterCount == 0 else { throw DevVlogsPhase0BE07GateError.duplicateEntry }
        let opened = waitState.withLock { state -> Bool in guard !state.resolutionWaitOpen, state.resolutionContinuation == nil else { return false }; state.resolutionWaitOpen = true; return true }
        guard opened else { throw DevVlogsPhase0BE07GateError.duplicateEntry }
        do {
            try await withTaskCancellationHandler(operation: {
                let cancelled = Task.isCancelled
                try await withCheckedThrowingContinuation { continuation in
                    enterCount = 1; waiterCount = 1
                    let locals = waitState.withLock { state -> (CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>?, CheckedContinuation<Void, Error>?) in
                        let entry = state.entryContinuation; state.entryContinuation = nil
                        if cancelled || state.cancellationRequested { state.cancellationRequested = true; return (continuation, entry) }
                        state.resolutionContinuation = continuation; return (nil, entry)
                    }
                    locals.1?.resume(); locals.0?.resume(throwing: CancellationError())
                }
            }, onCancel: {
                let continuation = waitState.withLock { state -> CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>? in guard state.resolutionWaitOpen, !state.isClosed else { return nil }; state.cancellationRequested = true; let value = state.resolutionContinuation; state.resolutionContinuation = nil; return value }
                continuation?.resume(throwing: CancellationError())
            })
        } catch {
            waitState.withLock { state in state.resolutionWaitOpen = false; state.resolutionContinuation = nil; state.entryContinuation = nil; state.entryWaitOpen = false; state.isClosed = true }; waiterCount = 0; throw error
        }
        let closure = waitState.withLock { state -> (CheckedContinuation<Void, Error>?, Bool) in
            let shouldCancel = Task.isCancelled || state.cancellationRequested; state.resolutionWaitOpen = false; state.resolutionContinuation = nil
            if shouldCancel { let entry = state.entryContinuation; state.entryContinuation = nil; state.entryWaitOpen = false; state.isClosed = true; return (entry, true) }
            if !state.entryWaitOpen { state.isClosed = true }; return (nil, false)
        }
        closure.0?.resume(throwing: CancellationError()); if closure.1 { waiterCount = 0; throw CancellationError() }
    }
    func resolve(_ resolution: DevVlogsPhase0BE07GateResolution) throws { guard resolutionCount == 0 else { throw DevVlogsPhase0BE07GateError.duplicateResolution }; resolutionCount = 1; waiterCount = 0; isResolved = true; let continuation = waitState.withLock { state -> CheckedContinuation<DevVlogsPhase0BE07GateResolution, Error>? in let value = state.resolutionContinuation; state.resolutionContinuation = nil; return value }; continuation?.resume(returning: resolution) }
    func snapshot() throws -> DevVlogsPhase0BE07GateSnapshot { let projection = waitState.withLock { state -> (Int, Int, Bool) in let entryPending = state.entryContinuation == nil ? 0 : 1; let resolutionPending = state.resolutionContinuation == nil ? 0 : 1; let entryOpen = state.entryWaitOpen ? 1 : 0; let resolutionOpen = state.resolutionWaitOpen ? 1 : 0; return (entryPending + resolutionPending, entryOpen + resolutionOpen, state.isClosed) }; if isResolved, projection != (0, 0, true) { throw DevVlogsPhase0BE07HarnessError.outstandingResource }; return .init(enterCount: enterCount, resolutionCount: resolutionCount, waiterCount: waiterCount, isResolved: isResolved, pendingContinuationCount: projection.0, openSuspendingMethodCount: projection.1, isClosed: projection.2) }
}

@available(macOS 15.0, *)
@MainActor final class DevVlogsPhase0BE07Observer {
    private let caseID: DevVlogsPhase0BE07CaseID; private let slowPreparationGate: DevVlogsPhase0BE07SlowPreparationGate?; private var phases: [DevVlogsPhase0BE07ObserverPhase] = [.idle]; private var terminal: DevVlogsPhase0BE07ObserverTerminal?; private var cleanupCount = 0; private var duplicateCount = 0; private var tokenSnapshot = DevVlogsPhase0BE07AccessSnapshot(acquireCount: 0, releaseCount: 0, outstandingCount: 0)
    init(caseID: DevVlogsPhase0BE07CaseID, slowPreparationGate: DevVlogsPhase0BE07SlowPreparationGate?) { self.caseID = caseID; self.slowPreparationGate = slowPreparationGate }
    func prepare() async throws -> DevVlogsPhase0BE07ObserverCallResult { if let terminal { duplicateCount += 1; return .rejectedLateDuplicate(terminal) }; phases.append(.preparing); switch caseID { case .camera_unavailable: return complete(.cameraUnavailable); case .camera_busy: return complete(.cameraBusy); case .destination_unavailable: return complete(.destinationUnavailable); case .camera_slow_timeout: guard let slowPreparationGate else { throw DevVlogsPhase0BE07HarnessError.unsupportedCase }; _ = try await slowPreparationGate.enterAndWaitForResolution(); return complete(.cameraPreparationTimedOut); default: phases.append(.capturing); return .continued } }
    func finish(completedArtifact: AudioRecordingArtifact, temporaryAccessToken: DevVlogsPhase0BE07TemporaryAccessToken) throws -> DevVlogsPhase0BE07ObserverCallResult { if let terminal { duplicateCount += 1; return .rejectedLateDuplicate(terminal) }; phases.append(.finalizing); let access = try temporaryAccessToken.acquire(completedArtifact: completedArtifact); var releaseError: Error?; do { defer { do { try temporaryAccessToken.release(access) } catch { releaseError = error }; tokenSnapshot = temporaryAccessToken.snapshot() } }; if let releaseError { throw releaseError }; guard tokenSnapshot.outstandingCount == 0 else { throw DevVlogsPhase0BE07HarnessError.outstandingResource }; return complete(caseID == .mux_failure ? .muxFailed : .ready) }
    func cancel() -> DevVlogsPhase0BE07ObserverCallResult { if let terminal { duplicateCount += 1; return .rejectedLateDuplicate(terminal) }; return complete(.cancelled) }
    func destinationDidDisconnect() -> DevVlogsPhase0BE07ObserverCallResult { if let terminal { duplicateCount += 1; return .rejectedLateDuplicate(terminal) }; return complete(.destinationDisconnected) }
    func snapshot() -> DevVlogsPhase0BE07ObserverSnapshot { .init(phases: phases, terminal: terminal ?? .disabled, terminalCount: terminal == nil ? 0 : 1, cleanupCount: cleanupCount, lateDuplicateRejectedCount: duplicateCount, accessAcquireCount: tokenSnapshot.acquireCount, accessReleaseCount: tokenSnapshot.releaseCount, outstandingAccessCount: tokenSnapshot.outstandingCount, outstandingTaskCount: 0) }
    private func complete(_ value: DevVlogsPhase0BE07ObserverTerminal) -> DevVlogsPhase0BE07ObserverCallResult { terminal = value; switch value { case .ready: phases.append(.ready); case .cancelled: phases.append(.cancelled); default: phases.append(.failed) }; phases.append(.cleaned); cleanupCount = 1; return .terminal(value) }
}

@MainActor final class DevVlogsPhase0BE07RecorderSpy: AudioRecorderService {
    private(set) var currentStatus: AudioRecorderStatus = .idle; let acceptsPreparedRecordingFileURL = true; private(set) var startCount = 0; private(set) var stopCount = 0; private(set) var cancelCount = 0; private(set) var prepared = false; private var completed: AudioRecordingArtifact?
    func startRecording(maximumDuration: TimeInterval) async throws { try await startRecording(maximumDuration: maximumDuration, outputFileURL: nil) }
    func startRecording(maximumDuration: TimeInterval, outputFileURL: URL?) async throws { startCount += 1; prepared = outputFileURL != nil; currentStatus = .recording }
    func stopRecording() async throws -> AudioRecordingArtifact { stopCount += 1; let artifact = AudioRecordingArtifact(fileURL: URL(fileURLWithPath: "e07-fake-audio.m4a"), duration: 1, byteCount: 1); completed = artifact; currentStatus = .finished(artifact: artifact); return artifact }
    func cancelRecording() { cancelCount += 1; currentStatus = .cancelled }
    func waitUntilCompletedArtifact() async throws -> AudioRecordingArtifact { guard let completed else { throw DevVlogsPhase0BE07HarnessError.missingCompletedArtifact }; return completed }
    func snapshot() -> (Int, Int, Int, Bool, Bool) { (startCount, stopCount, cancelCount, prepared, completed != nil) }
}

@MainActor final class DevVlogsPhase0BE07CaptureJournalSpy: RecordingCaptureJournaling {
    private(set) var prepareCount = 0; private(set) var releaseCount = 0; private(set) var discardCount = 0; private var outstanding = 0
    func prepareCapture(settings: AppSettings, maximumDuration: TimeInterval) throws -> RecordingCaptureLease { prepareCount += 1; outstanding += 1; return .init(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), audioFileURL: URL(fileURLWithPath: "e07-fake-audio.m4a"), transcriptionModel: settings.resolvedTranscriptionModel, languageCode: settings.resolvedLanguageCode, maximumDuration: maximumDuration) }
    func releaseCapture(_ lease: RecordingCaptureLease, artifact: AudioRecordingArtifact, recoveryAttemptID: FailedTranscriptionAttempt.ID) throws -> AudioRecordingArtifact { releaseCount += 1; outstanding -= 1; return artifact }
    func retireCaptureAfterRecovery(_ lease: RecordingCaptureLease, recoveryAttemptID: FailedTranscriptionAttempt.ID) throws { outstanding -= 1 }
    func discardCapture(_ lease: RecordingCaptureLease) throws { discardCount += 1; outstanding -= 1 }
    func inspectCapture(_ lease: RecordingCaptureLease, fallbackDuration: TimeInterval) -> RecordingCaptureInspection { .missing }
    func repairInterruptedCaptures(into recoveryStore: any TranscriptionFailureRecoveryRecording, onRepair: (UUID, RecordingDurabilityOutcome) -> Void) -> Int { 0 }
    func snapshot() -> (Int, Int, Int, Int) { (prepareCount, releaseCount, discardCount, outstanding) }
}

@MainActor final class DevVlogsPhase0BE07RecoverySpy: TranscriptionFailureRecoveryRecording {
    private let base = FakeTranscriptionFailureRecovery(); private(set) var checkpointCount = 0; private(set) var removeCount = 0; private(set) var sealCount = 0; private(set) var acceptCount = 0
    var failedAttempts: [FailedTranscriptionAttempt] { base.failedAttempts }
    func recordProcessingCheckpoint(audioFileURL: URL, settings: AppSettings, audioDuration: TimeInterval?, completionKind: TranscriptionRecoveryCompletionKind) throws -> FailedTranscriptionAttempt { checkpointCount += 1; return try base.recordProcessingCheckpoint(audioFileURL: audioFileURL, settings: settings, audioDuration: audioDuration, completionKind: completionKind) }
    func recordFailedAttempt(audioFileURL: URL, settings: AppSettings, audioDuration: TimeInterval?, reason: FailedTranscriptionReason) throws -> FailedTranscriptionAttempt? { try base.recordFailedAttempt(audioFileURL: audioFileURL, settings: settings, audioDuration: audioDuration, reason: reason) }
    func retainEmergencyFallback(audioFileURL: URL, settings: AppSettings, audioDuration: TimeInterval?, reason: FailedTranscriptionReason, completionKind: TranscriptionRecoveryCompletionKind) -> FailedTranscriptionAttempt? { base.retainEmergencyFallback(audioFileURL: audioFileURL, settings: settings, audioDuration: audioDuration, reason: reason, completionKind: completionKind) }
    func markSaved(id: FailedTranscriptionAttempt.ID, acceptedTranscriptText: String) throws { try base.markSaved(id: id, acceptedTranscriptText: acceptedTranscriptText) }
    func sealProviderDispatch(id: FailedTranscriptionAttempt.ID) throws { sealCount += 1 }
    func beginConfirmedDuplicateRetry(id: FailedTranscriptionAttempt.ID) throws { try base.beginConfirmedDuplicateRetry(id: id) }
    func markProviderOutcomeUncertain(id: FailedTranscriptionAttempt.ID) { base.markProviderOutcomeUncertain(id: id) }
    func recordProviderAccepted(id: FailedTranscriptionAttempt.ID, acceptedTranscriptText: String) { acceptCount += 1 }
    func markAcceptedHistoryCommitFailed(id: FailedTranscriptionAttempt.ID) { base.markAcceptedHistoryCommitFailed(id: id) }
    func updateFailedAttempt(id: FailedTranscriptionAttempt.ID, reason: FailedTranscriptionReason) throws { try base.updateFailedAttempt(id: id, reason: reason) }
    func removeFailedAttempt(id: FailedTranscriptionAttempt.ID) throws -> Bool { removeCount += 1; return try base.removeFailedAttempt(id: id) }
    func snapshot() -> (Int, Int, Int, Int, Int) { (checkpointCount, removeCount, failedAttempts.count, sealCount, acceptCount) }
}

@MainActor final class DevVlogsPhase0BE07InjectedServicesSpy: OpenAITranscriptionServing, TextCorrectionServing, TranscriptTranslationServing, TranscriptOutputDelivering, DictationCuePlaying, TranscriptHistoryAudioPlaybackStopping, RecordingDurationMonitoring, PrivateAudioOutputRouteProviding, TranscriptRecoveryHistoryRecording, TranscriptionUsageRecording, RecordingCacheLifecycleHandling, RecordingStopTailSleeping, DictationEventLogging, OpenAICredentialResolving, ActiveTextContextReading {
    let caseID: DevVlogsPhase0BE07CaseID; private let key = "e07-test-key"; private var providerResponse: CheckedContinuation<String, Never>?; private var dispatchWaiter: CheckedContinuation<Void, Never>?
    var settingsCount = 0; private(set) var credentialResolutionCount = 0; private(set) var credentialConsumerCount = 0; private(set) var credentialMismatchCount = 0; private(set) var providerDispatchCount = 0; private(set) var providerRequestCount = 0; private(set) var correctionCount = 0; private(set) var translationCount = 0; private(set) var usageCount = 0; private(set) var historyCount = 0; private(set) var outputCount = 0; private(set) var cacheCount = 0; private(set) var durationStartCount = 0; private(set) var durationStopCount = 0; private(set) var terminalCause: DevVlogsPhase0BE07TerminalCause = .none; private(set) var terminalDurability: DevVlogsPhase0BE07Durability = .none; private(set) var providerAuthorized = false; private(set) var providerDecisionCount = 0
    init(caseID: DevVlogsPhase0BE07CaseID) { self.caseID = caseID }
    func resolveOpenAICredential() throws -> OpenAICredential { credentialResolutionCount += 1; return try OpenAICredential(apiKey: key) }
    func transcribe(_ request: AudioTranscriptionRequest, credential: OpenAICredential) async throws -> String { credentialConsumerCount += 1; if credential.apiKey != key { credentialMismatchCount += 1 }; providerDispatchCount += 1; providerRequestCount += 1; dispatchWaiter?.resume(); dispatchWaiter = nil; return await withCheckedContinuation { providerResponse = $0 } }
    func cancelActiveTranscription() {}
    func waitUntilProviderDispatch() async { if providerDispatchCount == 1 { return }; await withCheckedContinuation { dispatchWaiter = $0 } }
    func releaseProviderResponse() throws { guard let providerResponse else { throw DevVlogsPhase0BE07HarnessError.providerReleaseBeforeDispatch }; self.providerResponse = nil; providerResponse.resume(returning: "accepted fake text") }
    func correct(_ request: TextCorrectionRequest, credential: OpenAICredential) async throws -> String { credentialConsumerCount += 1; if credential.apiKey != key { credentialMismatchCount += 1 }; correctionCount += 1; return caseID == .corrected_success ? "corrected fake text" : request.acceptedTranscript.text }
    func cancelActiveCorrection() {}
    func translate(_ request: TextTranslationRequest, credential: OpenAICredential) async throws -> String { credentialConsumerCount += 1; if credential.apiKey != key { credentialMismatchCount += 1 }; translationCount += 1; return "translated fake text" }
    func cancelActiveTranslation() {}
    func deliver(_ request: OutputDeliveryRequest) async throws -> TextInsertionResult { outputCount += 1; return .skipped(reason: .appClipboardDisabled) }
    func play(_ cue: DictationCue) {}; func stopPlayback() {}
    func start(maximumDurationWholeSeconds: Int, onElapsedWholeSecond: @escaping @MainActor (Int) -> Void) { durationStartCount += 1 }
    func stop() { durationStopCount += 1 }
    func isPrivateAudioOutputRoute() -> Bool { false }
    func recordAcceptedTranscript(_ request: AcceptedTranscriptHistoryRequest) throws { historyCount += 1 }
    func recordSuccessfulTranscriptionUsage(_ usage: SuccessfulTranscriptionUsage) { usageCount += 1 }
    func handleCompletedRecording(_ artifact: AudioRecordingArtifact, policy: RecordingCachePolicy) throws { cacheCount += 1 }
    func sleep(seconds: TimeInterval) async throws {}
    func currentContext(settings: AppSettings) -> TranscriptionPromptContext? { nil }
    func record(_ event: DictationLogEvent) { if case .recordingTerminal(let cause, _, let durability, let authorized) = event { providerDecisionCount += 1; providerAuthorized = authorized; terminalCause = cause == .userFinished ? .userFinished : cause == .explicitUserDiscard ? .explicitUserDiscard : .none; terminalDurability = durability == .historyCheckpoint ? .historyCheckpoint : durability == .explicitlyDiscarded ? .explicitlyDiscarded : .none } }
    func snapshot() -> (Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Bool, Int, DevVlogsPhase0BE07TerminalCause, DevVlogsPhase0BE07Durability, Int) { (settingsCount, credentialResolutionCount, credentialConsumerCount, credentialMismatchCount, providerDispatchCount, providerRequestCount, correctionCount, translationCount, usageCount, historyCount, outputCount, cacheCount, durationStartCount, durationStopCount, providerAuthorized, providerDecisionCount, terminalCause, terminalDurability, providerResponse == nil ? 0 : 1) }
}

@available(macOS 15.0, *)
@MainActor final class DevVlogsPhase0BE07PairHarness {
    func runPair(caseID: DevVlogsPhase0BE07CaseID) async throws -> DevVlogsPhase0BE07PairResult { let baseline = try await runAttempt(caseID: caseID, mode: .baseline); let spike = try await runAttempt(caseID: caseID, mode: .spike); return .init(caseID: caseID, baseline: baseline, spike: spike, dictationSnapshotsEqual: baseline.dictation == spike.dictation) }
    func assertPair(caseID: DevVlogsPhase0BE07CaseID) async throws {
        let result = try await runPair(caseID: caseID); guard result.dictationSnapshotsEqual, result.baseline.dictation == expectedDictationSnapshot(caseID: caseID), result.spike.dictation == expectedDictationSnapshot(caseID: caseID), result.baseline.observer == expectedObserverSnapshot(caseID: caseID, mode: .baseline), result.spike.observer == expectedObserverSnapshot(caseID: caseID, mode: .spike) else { throw DevVlogsPhase0BE07HarnessError.snapshotMismatch }
        if caseID == .camera_slow_timeout {
            let waitGate = DevVlogsPhase0BE07SlowPreparationGate(); let cancelledWait = Task { withUnsafeCurrentTask { $0?.cancel() }; try await waitGate.waitUntilEntered() }
            do { try await cancelledWait.value; throw DevVlogsPhase0BE07HarnessError.unexpectedTerminal } catch is CancellationError {}
            let waitSnapshot = try await waitGate.snapshot(); guard waitSnapshot.pendingContinuationCount == 0, waitSnapshot.openSuspendingMethodCount == 0, waitSnapshot.isClosed else { throw DevVlogsPhase0BE07HarnessError.outstandingResource }
            let enterGate = DevVlogsPhase0BE07SlowPreparationGate(); let cancelledEnter = Task { withUnsafeCurrentTask { $0?.cancel() }; try await enterGate.enterAndWaitForResolution() }
            do { try await cancelledEnter.value; throw DevVlogsPhase0BE07HarnessError.unexpectedTerminal } catch is CancellationError {}
            let enterSnapshot = try await enterGate.snapshot(); guard enterSnapshot.pendingContinuationCount == 0, enterSnapshot.openSuspendingMethodCount == 0, enterSnapshot.isClosed else { throw DevVlogsPhase0BE07HarnessError.outstandingResource }
        }
    }
    private func runAttempt(caseID: DevVlogsPhase0BE07CaseID, mode: DevVlogsPhase0BE07AttemptMode) async throws -> DevVlogsPhase0BE07AttemptSnapshot {
        let recorder = DevVlogsPhase0BE07RecorderSpy(); let journal = DevVlogsPhase0BE07CaptureJournalSpy(); let recovery = DevVlogsPhase0BE07RecoverySpy(); let services = DevVlogsPhase0BE07InjectedServicesSpy(caseID: caseID); var states: [DevVlogsPhase0BE07ActionState] = [.idle]; var outstandingTasks = 0
        let controller = DictationSessionController(recorder: recorder, transcriptionService: services, textCorrectionService: services, translationService: services, settingsProvider: { services.settingsCount += 1; return self.makeSettings(caseID: caseID) }, transcriptOutput: services, cuePlayer: services, historyAudioPlaybackStopper: services, recordingDurationMonitor: services, privateAudioOutputRouteProvider: services, transcriptHistory: services, transcriptionFailureRecovery: recovery, activeTextContextReader: services, transcriptionUsageRecorder: services, recordingCache: services, recordingCaptureJournal: journal, recordingStopTailSleeper: services, eventLogger: services, credentialResolverForUngatedActions: services)
        controller.statusDidChange = { status in switch status { case .idle: states.append(.idle); case .recording: states.append(.recording); case .transcribing: states.append(.transcribing); case .success: states.append(.success); case .failure: break } }
        let gate = caseID == .camera_slow_timeout && mode == .spike ? DevVlogsPhase0BE07SlowPreparationGate() : nil
        let observer = mode == .spike ? DevVlogsPhase0BE07Observer(caseID: caseID, slowPreparationGate: gate) : nil
        var observerPreparation: Task<DevVlogsPhase0BE07ObserverCallResult, Error>?
        if let gate, let observer { outstandingTasks += 1; observerPreparation = Task { @MainActor in try await observer.prepare() }; try await gate.waitUntilEntered(); let pre = try await gate.snapshot(); guard pre.enterCount == 1 else { throw DevVlogsPhase0BE07HarnessError.unsupportedCase }; guard pre.resolutionCount == 0, !pre.isResolved else { throw DevVlogsPhase0BE07GateError.duplicateResolution }; guard pre.waiterCount == 1 else { throw DevVlogsPhase0BE07HarnessError.unexpectedTerminal }; guard pre.pendingContinuationCount == 1 else { throw DevVlogsPhase0BE07HarnessError.missingCompletedArtifact }; guard pre.openSuspendingMethodCount == 1, !pre.isClosed else { throw DevVlogsPhase0BE07HarnessError.outstandingResource } }
        let intent: DictationOutputIntent = caseID == .translated_success ? .translate : .standard
        await controller.performRecordingAction(intent: intent); guard controller.status == .recording else { throw DevVlogsPhase0BE07HarnessError.unexpectedTerminal }
        if let gate { let pre = try await gate.snapshot(); guard pre.resolutionCount == 0 else { throw DevVlogsPhase0BE07HarnessError.snapshotMismatch }; try await gate.resolve(.timedOut); _ = try await observerPreparation?.value; outstandingTasks -= 1; let terminal = try await gate.snapshot(); guard terminal == .init(enterCount: 1, resolutionCount: 1, waiterCount: 0, isResolved: true, pendingContinuationCount: 0, openSuspendingMethodCount: 0, isClosed: true) else { throw DevVlogsPhase0BE07HarnessError.outstandingResource } }
        else if let observer { _ = try await observer.prepare() }
        if caseID == .explicit_cancel { if let observer { _ = observer.cancel(); _ = observer.cancel() }; controller.cancelRecording() }
        else {
            if caseID == .destination_disconnect, let observer { _ = observer.destinationDidDisconnect(); _ = observer.destinationDidDisconnect() }
            if let observer, [.camera_unavailable, .camera_busy, .camera_slow_timeout, .destination_unavailable].contains(caseID) { _ = try await observer.prepare() }
            outstandingTasks += 1; let finish = Task { @MainActor in await controller.performRecordingAction(intent: intent) }; await services.waitUntilProviderDispatch(); let artifact = try await recorder.waitUntilCompletedArtifact()
            if let observer, ![.camera_unavailable, .camera_busy, .camera_slow_timeout, .destination_unavailable, .destination_disconnect].contains(caseID) { let token = DevVlogsPhase0BE07TemporaryAccessToken(completedArtifact: artifact, identity: .dictationAudio); _ = try observer.finish(completedArtifact: artifact, temporaryAccessToken: token); _ = try observer.finish(completedArtifact: artifact, temporaryAccessToken: token) }
            try services.releaseProviderResponse(); await finish.value; outstandingTasks -= 1
        }
        let dictation = makeSnapshot(caseID: caseID, states: states, controller: controller, recorder: recorder, journal: journal, recovery: recovery, services: services, outstandingTasks: outstandingTasks)
        return .init(dictation: dictation, observer: observer?.snapshot() ?? expectedObserverSnapshot(caseID: caseID, mode: .baseline))
    }
    private func expectedDictationSnapshot(caseID: DevVlogsPhase0BE07CaseID) -> DevVlogsPhase0BE07DictationSnapshot {
        let cancel = caseID == .explicit_cancel; let translated = caseID == .translated_success; let output: DevVlogsPhase0BE07AcceptedOutputClass = cancel ? .none : translated ? .translated : caseID == .corrected_success ? .corrected : .standard
        return .init(actionStates: cancel ? [.idle, .recording, .idle] : [.idle, .recording, .transcribing, .success], terminal: cancel ? .cancelled : .success, audioOwner: .dictationRecorder, microphoneOwnerCount: 1, recorderStartCount: 1, recorderStopCount: cancel ? 0 : 1, recorderCancelCount: cancel ? 1 : 0, preparedArtifactIdentity: .dictationAudio, finalizedArtifactIdentity: cancel ? .none : .dictationAudio, settingsSnapshotCount: 1, credentialResolutionCount: 1, credentialConsumerCheckCount: cancel ? 0 : translated ? 3 : 2, credentialMismatchCount: 0, journalPrepareCount: 1, journalReleaseCount: cancel ? 0 : 1, journalDiscardCount: cancel ? 1 : 0, journalOutstandingCount: 0, recoveryCheckpointCount: cancel ? 0 : 1, recoveryRemoveCount: cancel ? 0 : 1, recoveryOutstandingCount: 0, providerAuthorizationDecisionCount: 1, providerAuthorized: !cancel, providerSealCount: cancel ? 0 : 1, providerDispatchEventCount: cancel ? 0 : 1, providerRequestCount: cancel ? 0 : 1, providerAcceptCount: cancel ? 0 : 1, providerRequestArtifactIdentity: cancel ? .none : .dictationAudio, correctionCount: cancel ? 0 : 1, remoteCorrectionEnabled: caseID == .corrected_success, translationCount: translated ? 1 : 0, usageCount: cancel ? 0 : 1, acceptedOutputClass: output, lastTranscriptAcceptedCount: cancel ? 0 : 1, historyCount: cancel ? 0 : 1, outputCount: cancel ? 0 : 1, cacheCount: cancel ? 0 : 1, terminalCause: cancel ? .explicitUserDiscard : .userFinished, terminalDurability: cancel ? .explicitlyDiscarded : .historyCheckpoint, durationMonitorStartCount: 1, durationMonitorStopCount: 1, terminalActionCompletedWithObservedResourcesClosed: true, providerOutstandingCount: 0, outstandingTaskCount: 0)
    }
    private func expectedObserverSnapshot(caseID: DevVlogsPhase0BE07CaseID, mode: DevVlogsPhase0BE07AttemptMode) -> DevVlogsPhase0BE07ObserverSnapshot {
        guard mode == .spike else { return .init(phases: [.disabled], terminal: .disabled, terminalCount: 0, cleanupCount: 0, lateDuplicateRejectedCount: 0, accessAcquireCount: 0, accessReleaseCount: 0, outstandingAccessCount: 0, outstandingTaskCount: 0) }
        let terminal: DevVlogsPhase0BE07ObserverTerminal; let phases: [DevVlogsPhase0BE07ObserverPhase]; let access: Int
        switch caseID { case .standard_success, .corrected_success, .translated_success: terminal = .ready; phases = [.idle, .preparing, .capturing, .finalizing, .ready, .cleaned]; access = 1; case .explicit_cancel: terminal = .cancelled; phases = [.idle, .preparing, .capturing, .cancelled, .cleaned]; access = 0; case .camera_unavailable: terminal = .cameraUnavailable; phases = [.idle, .preparing, .failed, .cleaned]; access = 0; case .camera_busy: terminal = .cameraBusy; phases = [.idle, .preparing, .failed, .cleaned]; access = 0; case .camera_slow_timeout: terminal = .cameraPreparationTimedOut; phases = [.idle, .preparing, .failed, .cleaned]; access = 0; case .destination_unavailable: terminal = .destinationUnavailable; phases = [.idle, .preparing, .failed, .cleaned]; access = 0; case .destination_disconnect: terminal = .destinationDisconnected; phases = [.idle, .preparing, .capturing, .failed, .cleaned]; access = 0; case .mux_failure: terminal = .muxFailed; phases = [.idle, .preparing, .capturing, .finalizing, .failed, .cleaned]; access = 1 }
        return .init(phases: phases, terminal: terminal, terminalCount: 1, cleanupCount: 1, lateDuplicateRejectedCount: 1, accessAcquireCount: access, accessReleaseCount: access, outstandingAccessCount: 0, outstandingTaskCount: 0)
    }
    private func makeSettings(caseID: DevVlogsPhase0BE07CaseID) -> AppSettings { var value = AppSettings.defaults; value.soundEnabled = false; value.recordingStopTailDuration = .off; value.saveTranscriptHistory = true; value.textCorrectionEnabled = caseID == .corrected_success; if caseID == .translated_success { value.language = .russian; value.translationTargetLanguage = .english }; return value }
    private func makeSnapshot(caseID: DevVlogsPhase0BE07CaseID, states: [DevVlogsPhase0BE07ActionState], controller: DictationSessionController, recorder: DevVlogsPhase0BE07RecorderSpy, journal: DevVlogsPhase0BE07CaptureJournalSpy, recovery: DevVlogsPhase0BE07RecoverySpy, services: DevVlogsPhase0BE07InjectedServicesSpy, outstandingTasks: Int) -> DevVlogsPhase0BE07DictationSnapshot {
        let r = recorder.snapshot(); let j = journal.snapshot(); let f = recovery.snapshot(); let s = services.snapshot(); let cancel = caseID == .explicit_cancel; let output: DevVlogsPhase0BE07AcceptedOutputClass = cancel ? .none : caseID == .translated_success ? .translated : caseID == .corrected_success ? .corrected : .standard; let closed = s.12 == s.13 && j.3 == 0 && f.2 == 0 && s.18 == 0 && outstandingTasks == 0 && (cancel ? controller.status == .idle : controller.status.voiceWorkPhase == .inactive)
        return .init(actionStates: states, terminal: cancel ? .cancelled : .success, audioOwner: .dictationRecorder, microphoneOwnerCount: r.0 > 0 ? 1 : 0, recorderStartCount: r.0, recorderStopCount: r.1, recorderCancelCount: r.2, preparedArtifactIdentity: r.3 ? .dictationAudio : .none, finalizedArtifactIdentity: r.4 ? .dictationAudio : .none, settingsSnapshotCount: s.0, credentialResolutionCount: s.1, credentialConsumerCheckCount: s.2, credentialMismatchCount: s.3, journalPrepareCount: j.0, journalReleaseCount: j.1, journalDiscardCount: j.2, journalOutstandingCount: j.3, recoveryCheckpointCount: f.0, recoveryRemoveCount: f.1, recoveryOutstandingCount: f.2, providerAuthorizationDecisionCount: s.15, providerAuthorized: s.14, providerSealCount: f.3, providerDispatchEventCount: s.4, providerRequestCount: s.5, providerAcceptCount: f.4, providerRequestArtifactIdentity: s.5 == 1 ? .dictationAudio : .none, correctionCount: s.6, remoteCorrectionEnabled: caseID == .corrected_success, translationCount: s.7, usageCount: s.8, acceptedOutputClass: output, lastTranscriptAcceptedCount: controller.lastTranscriptText == nil ? 0 : 1, historyCount: s.9, outputCount: s.10, cacheCount: s.11, terminalCause: s.16, terminalDurability: s.17, durationMonitorStartCount: s.12, durationMonitorStopCount: s.13, terminalActionCompletedWithObservedResourcesClosed: closed, providerOutstandingCount: s.18, outstandingTaskCount: outstandingTasks)
    }
}

struct DevVlogsPhase0BE07EvidenceValidator {
    private let children = ["summary.md", "source-feasibility.md", "environment.json", "matrix.csv", "measurements.csv", "artifacts.csv", "residuals.md", "events/e07-pairs.jsonl"]
    func validate(fromTestFilePath path: String) throws {
        let root = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent(); let run = root.appendingPathComponent("docs/qa/runs/dev-vlogs-phase-0b-dictation-w01")
        try validateFileInventory(run); try validateMarkdown(run); try validateEnvironment(run); try validateCSVFiles(run); try validateEvents(run); try validateSizes(run); try validateRedaction(run)
    }
    private func validateFileInventory(_ run: URL) throws {
        let found = try FileManager.default.subpathsOfDirectory(atPath: run.path).filter { value in var directory: ObjCBool = false; return FileManager.default.fileExists(atPath: run.appendingPathComponent(value).path, isDirectory: &directory) && !directory.boolValue }.sorted()
        guard found == children.sorted() else { throw found.count < children.count ? DevVlogsPhase0BE07EvidenceValidationError.missingFile : .unexpectedFile }
        for child in children { let values = try run.appendingPathComponent(child).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]); guard values.isRegularFile == true, values.isSymbolicLink != true else { throw DevVlogsPhase0BE07EvidenceValidationError.symlinkNotAllowed } }
    }
    private func validateMarkdown(_ run: URL) throws {
        let specifications: [(String, [String], [String])] = [
            ("summary.md", ["# DV-P0B-E07-W01 Summary", "## Authority", "## Scope", "## Paired Matrix Result", "## Checks", "## Redaction", "## Residuals"], ["Execution was fake-backed only.", "Exactly ten baseline/spike pairs were exercised.", "Canonical dictation retained exactly one recorder and one microphone owner.", "No second microphone was introduced.", "No product, Debug, script, project, or existing-test file changed.", "W02 and W07-R3 are provenance only and do not prove E07.", "A shipping audio lease was not exercised or proven."]),
            ("source-feasibility.md", ["# DV-P0B-E07-W01 Source Feasibility", "## Canonical Owners", "## Reused Injection Boundaries", "## Rejected Orchestrator", "## Target Membership", "## Protected Blobs", "## Residual"], ["DictationSessionController remained the canonical state owner.", "AudioRecorderService remained the sole microphone owner.", "The existing Debug Phase 0B harness was not used as E07 orchestration.", "HoldTypeTests membership was supplied by the filesystem-synchronized target root.", "No Xcode project edit was required.", "No product hook was required.", "The temporary-access token was test-only and was not a shipping lease."]),
            ("residuals.md", ["# DV-P0B-E07-W01 Residuals", "## Proven", "## Not Proven", "## Next Dependency"], ["Proven: deterministic fake-backed E07 paired non-regression only.", "Not proven: shipping audio lease, real media, hardware, camera, microphone, destination storage, timing thresholds, or live provider behavior.", "E02, E03, E04, E05, and E06 remain unchanged.", "Next dependency: DV-P0B-E07-W01-REVIEW."])
        ]
        for (name, headings, claims) in specifications { let text = try String(contentsOf: run.appendingPathComponent(name), encoding: .utf8); guard text.split(separator: "\n").filter({ $0.hasPrefix("#") }).map(String.init) == headings, claims.allSatisfy(text.contains) else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidHeading }; if name == "summary.md" { let results = ["pass", "fail"].filter { text.components(separatedBy: "Functional result: \($0).").count == 2 }; guard results.count == 1 else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }; if results[0] == "fail" { let unequalCases = DevVlogsPhase0BE07CaseID.allCases.map { "Unequal case: \($0.rawValue)." }; guard unequalCases.contains(where: { text.components(separatedBy: $0).count == 2 }) else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema } } } }
    }
    private func validateEnvironment(_ run: URL) throws {
        let data = try Data(contentsOf: run.appendingPathComponent("environment.json")); let value = try JSONSerialization.jsonObject(with: data); guard let object = value as? [String: Any] else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }
        let keys = ["schema_version", "packet_id", "contract_revision", "implementation_parent_commit", "swift_source_manifest_sha256", "macos_product_version", "xcode_version", "swift_version", "execution_mode", "functional_result", "live_keychain_access", "live_provider_request", "app_launched", "microphone_opened", "camera_opened", "external_storage_accessed", "media_created"]
        guard Set(object.keys) == Set(keys), object["schema_version"] as? String == "dv-p0b-e07-environment-v1", object["packet_id"] as? String == "DV-P0B-E07-W01", object["contract_revision"] as? String == "DV-DRAFT-4@2f3266a", object["implementation_parent_commit"] as? String == "24f4a601087322c6a3ac80e637e808a684deb9b4", object["execution_mode"] as? String == "fake_backed", let functionalResult = object["functional_result"] as? String, ["pass", "fail"].contains(functionalResult) else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }
        guard let parent = object["implementation_parent_commit"] as? String, parent.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil, let manifest = object["swift_source_manifest_sha256"] as? String, manifest.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil, ["macos_product_version", "xcode_version", "swift_version"].allSatisfy({ (object[$0] as? String)?.isEmpty == false }) else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }
        for key in keys.suffix(7) { guard object[key] as? Bool == false else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema } }
        let text = String(decoding: data, as: UTF8.self); for key in keys where text.components(separatedBy: "\"\(key)\"").count != 2 { throw DevVlogsPhase0BE07EvidenceValidationError.duplicateKey }; let summary = try String(contentsOf: run.appendingPathComponent("summary.md"), encoding: .utf8); guard summary.components(separatedBy: "Functional result: \(functionalResult).").count == 2 else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }
    }
    private func validateCSVFiles(_ run: URL) throws {
        let schemas: [(String, String, Int)] = [
            ("matrix.csv", "schema_version,case_id,baseline_terminal,spike_terminal,snapshot_equal,observer_terminal,baseline_audio_owner_count,spike_audio_owner_count,baseline_provider_dispatch_count,spike_provider_dispatch_count,baseline_output_count,spike_output_count,observer_acquire_count,observer_release_count,observer_terminal_count,outstanding_access_count,outstanding_task_count,functional_result,disposition", 11),
            ("measurements.csv", "schema_version,case_id,metric,value,unit,disposition", 10),
            ("artifacts.csv", "schema_version,case_id,artifact_class,retained,byte_count,checksum,cleanup_status,disposition", 11)
        ]
        for (name, header, count) in schemas { let rows = try String(contentsOf: run.appendingPathComponent(name), encoding: .utf8).split(separator: "\n").map(String.init); guard rows.first == header, rows.count == count, rows.dropFirst().allSatisfy({ $0.split(separator: ",", omittingEmptySubsequences: false).count == header.split(separator: ",").count }) else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidCardinality } }
        let matrixRows = try String(contentsOf: run.appendingPathComponent("matrix.csv"), encoding: .utf8).split(separator: "\n").dropFirst().map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        for (index, row) in matrixRows.enumerated() { let caseID = DevVlogsPhase0BE07CaseID.allCases[index]; let cancel = caseID == .explicit_cancel; let observer = ["ready", "ready", "ready", "cancelled", "camera_unavailable", "camera_busy", "camera_preparation_timed_out", "destination_unavailable", "destination_disconnected", "mux_failed"][index]; let access = [0, 1, 2, 9].contains(index) ? 1 : 0; guard row[0] == "dv-p0b-e07-matrix-v1", row[1] == caseID.rawValue, row[2] == (cancel ? "cancelled" : "success"), row[3] == row[2], row[4] == "true", row[5] == observer, row[6] == "1", row[7] == "1", row[8] == (cancel ? "0" : "1"), row[9] == row[8], row[10] == row[8], row[11] == row[8], row[12] == String(access), row[13] == String(access), row[14] == "1", row[15] == "0", row[16] == "0", row[17] == "pass", row[18] == "functional_gate" else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema } }
        let measurementRows = try String(contentsOf: run.appendingPathComponent("measurements.csv"), encoding: .utf8).split(separator: "\n").dropFirst().map(String.init); let expectedMeasurements = ["dv-p0b-e07-measurements-v1,camera_slow_timeout,recording_before_gate_resolution,true,boolean,functional_gate"] + ["dictation_start_latency", "camera_start_latency", "audio_video_offset", "end_drift", "cpu", "memory", "byte_rate", "finalization_overhead"].map { "dv-p0b-e07-measurements-v1,all,\($0),not_measured,not_applicable,not_applicable_fake_backed" }; guard measurementRows == expectedMeasurements else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema }
        let artifactRows = try String(contentsOf: run.appendingPathComponent("artifacts.csv"), encoding: .utf8).split(separator: "\n").dropFirst().map(String.init); for (index, row) in artifactRows.enumerated() { guard row == "dv-p0b-e07-artifacts-v1,\(DevVlogsPhase0BE07CaseID.allCases[index].rawValue),fake_audio_identity,false,0,not_applicable,no_file_created,fake_backed_no_media" else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidSchema } }
    }
    private func validateEvents(_ run: URL) throws {
        let lines = try String(contentsOf: run.appendingPathComponent("events/e07-pairs.jsonl"), encoding: .utf8).split(separator: "\n"); guard lines.count == 80 else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidCardinality }
        let keys = Set(["schema_version", "sequence", "case_id", "mode", "action", "result", "artifact_token", "snapshot_equal"])
        for (index, line) in lines.enumerated() { let text = String(line); for key in keys where text.components(separatedBy: "\"\(key)\"").count != 2 { throw DevVlogsPhase0BE07EvidenceValidationError.duplicateKey }; guard let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], Set(object.keys) == keys, object["schema_version"] as? String == "dv-p0b-e07-events-v1", object["sequence"] as? Int == index + 1, object["case_id"] as? String == DevVlogsPhase0BE07CaseID.allCases[index / 8].rawValue else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidOrder }; let position = index % 8; let caseID = DevVlogsPhase0BE07CaseID.allCases[index / 8]; let cancel = caseID == .explicit_cancel; let observer = ["ready", "ready", "ready", "cancelled", "camera_unavailable", "camera_busy", "camera_preparation_timed_out", "destination_unavailable", "destination_disconnected", "mux_failed"][index / 8]; let modes = ["baseline", "baseline", "baseline", "spike", "spike", "spike", "spike", "pair"]; let actions = ["attempt_started", "dictation_recording", "dictation_terminal", "attempt_started", "dictation_recording", "observer_terminal", "dictation_terminal", "pair_compared"]; let terminal = cancel ? "cancelled" : "success"; let results = ["started", "recording", terminal, "started", "recording", observer, terminal, "equal"]; let observerUsesAccess = observer == "ready" || observer == "mux_failed"; let tokens = ["none", "dictation_audio", cancel ? "none" : "dictation_audio", "none", "dictation_audio", observerUsesAccess ? "dictation_audio" : "none", cancel ? "none" : "dictation_audio", "none"]; guard object["mode"] as? String == modes[position], object["action"] as? String == actions[position], object["result"] as? String == results[position], object["artifact_token"] as? String == tokens[position], position == 7 ? object["snapshot_equal"] as? Bool == true : object["snapshot_equal"] is NSNull else { throw DevVlogsPhase0BE07EvidenceValidationError.invalidOrder } }
    }
    private func validateSizes(_ run: URL) throws { let limits = [12288, 12288, 4096, 20480, 8192, 8192, 8192, 65536]; for (index, child) in children.enumerated() { guard try Data(contentsOf: run.appendingPathComponent(child)).count <= limits[index] else { throw DevVlogsPhase0BE07EvidenceValidationError.oversizedFile } } }
    private func validateRedaction(_ run: URL) throws {
        let text = try children.map { try String(contentsOf: run.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n"); let lower = text.lowercased(); let literals = ["/users/", "/volumes/", "/private/", "/tmp/", "file://", "bearer", "authorization:", "api_key", "authorization_header", "transcript_text", "raw_text", "prompt_text", "provider_payload", "provider_response", "audio_file_url", "video_file_url", "device_unique_id", "camera_label", "machine_name", "user_name"]
        guard !literals.contains(where: lower.contains), text.range(of: #"[A-Za-z]:\\"#, options: .regularExpression) == nil, text.range(of: #"sk-[A-Za-z0-9_-]{8,}"#, options: .regularExpression) == nil else { throw DevVlogsPhase0BE07EvidenceValidationError.forbiddenContent }
    }
}
#endif
