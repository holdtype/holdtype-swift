import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Observation

struct IOSVoiceDraftTextActionClient: Sendable {
    typealias Perform = @MainActor @Sendable (
        TextFixAction,
        String
    ) async -> IOSVoiceDraftTextActionResolution

    let perform: Perform

    init(perform: @escaping Perform) {
        self.perform = perform
    }

    init(
        settingsStateOwner: IOSAppSettingsStateOwner,
        consentOwner: IOSProviderConsentPresentationOwner,
        credentialCoordinator: IOSOpenAICredentialCoordinator?,
        processor: IOSForegroundVoiceProcessor?
    ) {
        perform = { action, text in
            guard let credentialCoordinator, let processor else {
                return .failure(.credentialUnavailable)
            }
            let settings: IOSAppSettings
            do {
                settings = try await settingsStateOwner
                    .confirmedValueForProviderAction()
            } catch {
                return .failure(.invalidConfiguration)
            }
            let consentObservation = await consentOwner
                .observeForVoicePreflight()
            let credential: IOSResolvedOpenAICredential
            do {
                let outcome = try await credentialCoordinator.resolve(
                    for: .voicePreflight
                )
                guard case .available(let value) = outcome.resolution else {
                    return .failure(.credentialUnavailable)
                }
                credential = value
            } catch {
                return .failure(.credentialUnavailable)
            }
            return await processor.processDraftTextFix(
                IOSVoiceDraftTextFixRequest(
                    action: action,
                    text: text,
                    settings: settings,
                    credential: credential,
                    consentObservation: consentObservation
                )
            )
        }
    }
}

enum IOSVoiceDraftTextActionOutcome: Equatable, Sendable {
    case completed(TextFixAction, changed: Bool)
    case failed(
        TextFixAction,
        IOSVoiceDraftTextActionFailure
    )

    var accessibilityAnnouncement: String {
        switch self {
        case .completed(let action, changed: true)
            where action.kind == .translate:
            "Draft translated"
        case .completed(let action, changed: true) where action.kind == .fix:
            "Draft improved"
        case .completed(let action, changed: true):
            "Draft updated with \(action.title)"
        case .completed(_, changed: false):
            "Draft unchanged"
        case .failed:
            "Draft unchanged"
        }
    }

    var settingsRoute: IOSSettingsRoute? {
        switch self {
        case .failed(let action, .invalidConfiguration)
            where action.kind == .translate:
            .attention(.translation)
        case .failed(_, .invalidConfiguration):
            .general(.writingCorrection)
        case .failed(_, .credentialUnavailable):
            .attention(.openAI)
        case .failed(_, .consentUnavailable):
            .attention(.privacyReview)
        case .completed, .failed:
            nil
        }
    }

    var failureDetail: String? {
        guard case .failed(_, let failure) = self else { return nil }
        return switch failure {
        case .busy:
            "Another Voice action is still running."
        case .invalidText:
            "Select text or enter a Draft before running a Fix."
        case .sourceTooLarge:
            "This text is too large for one Fix."
        case .invalidConfiguration:
            "Review this Fix's saved settings, then try again."
        case .credentialUnavailable:
            "Add or review your OpenAI API key in Settings."
        case .consentUnavailable:
            "Review OpenAI processing consent in Settings."
        case .networkUnavailable:
            "The network is unavailable. The Draft was not changed."
        case .timedOut:
            "The Fix timed out. The Draft was not changed."
        case .providerUnavailable:
            "OpenAI could not complete this Fix."
        case .invalidResponse:
            "OpenAI returned no usable text."
        case .draftChanged:
            "The Draft changed before this Fix could be applied."
        case .saveFailed:
            "HoldType could not safely save the updated Draft."
        case .cancelled:
            "The Fix was cancelled."
        }
    }
}

@MainActor
@Observable
final class IOSVoiceDraftTextActionOwner {
    private(set) var activeAction: TextFixAction?
    private(set) var outcome: IOSVoiceDraftTextActionOutcome?
    @ObservationIgnored
    private let draftOwner: IOSVoiceDraftOwner
    @ObservationIgnored
    private let client: IOSVoiceDraftTextActionClient
    @ObservationIgnored
    private let diagnostics: IOSRuntimeTextFixDiagnosticClient
    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    init(
        draftOwner: IOSVoiceDraftOwner,
        client: IOSVoiceDraftTextActionClient,
        diagnostics: IOSRuntimeTextFixDiagnosticClient = .silent
    ) {
        self.draftOwner = draftOwner
        self.client = client
        self.diagnostics = diagnostics
    }

    deinit {
        activeTask?.cancel()
    }

    var isProcessing: Bool { activeAction != nil }

    @discardableResult
    func submit(_ action: TextFixAction) -> Bool {
        guard activeAction == nil else {
            diagnose(.eligibility, action: action, outcome: .busy)
            return false
        }
        guard let reservation = draftOwner.beginTransformation() else {
            diagnose(.eligibility, action: action, outcome: .blocked)
            return false
        }
        return start(action, reservation: reservation)
    }

    @discardableResult
    func submit(
        _ action: TextFixAction,
        capturing snapshot: IOSVoiceDraftTextTargetSnapshot
    ) async -> Bool {
        guard activeAction == nil else {
            diagnose(.eligibility, action: action, outcome: .busy)
            return false
        }
        guard let reservation = await draftOwner.beginTransformation(
            capturing: snapshot
        ) else {
            diagnose(.eligibility, action: action, outcome: .blocked)
            return false
        }
        return start(action, reservation: reservation)
    }

    private func start(
        _ action: TextFixAction,
        reservation: IOSVoiceDraftTransformationReservation
    ) -> Bool {
        guard activeAction == nil else {
            draftOwner.cancelTransformation(reservation)
            diagnose(.eligibility, action: action, outcome: .busy)
            return false
        }
        activeAction = action
        outcome = nil
        diagnose(.processing, action: action, outcome: .started)
        let client = client
        activeTask = Task { @MainActor [self] in
            let resolution = await client.perform(action, reservation.text)
            guard !Task.isCancelled else {
                await self.finish(
                    action,
                    resolution: .failure(.cancelled),
                    reservation: reservation
                )
                return
            }
            await self.finish(
                action,
                resolution: resolution,
                reservation: reservation
            )
        }
        return true
    }

    func dismissOutcome() {
        outcome = nil
    }

    func cancelActiveAction() {
        activeTask?.cancel()
    }

    private func finish(
        _ action: TextFixAction,
        resolution: IOSVoiceDraftTextActionResolution,
        reservation: IOSVoiceDraftTransformationReservation
    ) async {
        defer {
            activeAction = nil
            activeTask = nil
        }
        switch resolution {
        case .success(let text):
            let commit = await draftOwner.commitTransformation(
                text,
                reservation: reservation
            )
            switch commit {
            case .confirmed(let changed):
                outcome = .completed(action, changed: changed)
                diagnose(.output, action: action, outcome: .succeeded)
            case .stale:
                outcome = .failed(action, .draftChanged)
                diagnose(.target, action: action, outcome: .stale)
            case .failed, .unavailable:
                outcome = .failed(action, .saveFailed)
                diagnose(.output, action: action, outcome: .failed)
            }
        case .failure(let failure):
            draftOwner.cancelTransformation(reservation)
            outcome = .failed(action, failure)
            diagnose(
                .result,
                action: action,
                outcome: failure.diagnosticOutcome
            )
        }
    }

    private func diagnose(
        _ stage: IOSDiagnosticTextFixStage,
        action: TextFixAction,
        outcome: IOSDiagnosticTextFixOutcome
    ) {
        diagnostics.record(
            stage,
            actionIdentifier: action.id,
            outcome: outcome
        )
    }
}
