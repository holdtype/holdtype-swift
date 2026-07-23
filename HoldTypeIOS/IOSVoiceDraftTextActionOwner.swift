import Foundation
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Observation

struct IOSVoiceDraftTextActionClient: Sendable {
    typealias Perform = @MainActor @Sendable (
        IOSVoiceDraftTextAction,
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
            return await processor.processDraftText(
                IOSVoiceDraftTextActionRequest(
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
    case completed(IOSVoiceDraftTextAction, changed: Bool)
    case failed(
        IOSVoiceDraftTextAction,
        IOSVoiceDraftTextActionFailure
    )

    var accessibilityAnnouncement: String {
        switch self {
        case .completed(.translate, changed: true):
            "Draft translated"
        case .completed(.correct, changed: true):
            "Draft improved"
        case .completed(_, changed: false):
            "Draft unchanged"
        case .failed:
            "Draft unchanged"
        }
    }

    var settingsRoute: IOSSettingsRoute? {
        switch self {
        case .failed(.translate, .invalidConfiguration):
            .attention(.translation)
        case .failed(.correct, .invalidConfiguration):
            .general(.writingCorrection)
        case .failed(_, .credentialUnavailable):
            .attention(.openAI)
        case .failed(_, .consentUnavailable):
            .attention(.privacyReview)
        case .completed, .failed:
            nil
        }
    }
}

@MainActor
@Observable
final class IOSVoiceDraftTextActionOwner {
    private(set) var activeAction: IOSVoiceDraftTextAction?
    private(set) var outcome: IOSVoiceDraftTextActionOutcome?

    @ObservationIgnored
    private let draftOwner: IOSVoiceDraftOwner
    @ObservationIgnored
    private let client: IOSVoiceDraftTextActionClient
    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    init(
        draftOwner: IOSVoiceDraftOwner,
        client: IOSVoiceDraftTextActionClient
    ) {
        self.draftOwner = draftOwner
        self.client = client
    }

    deinit {
        activeTask?.cancel()
    }

    var isProcessing: Bool { activeAction != nil }

    @discardableResult
    func submit(_ action: IOSVoiceDraftTextAction) -> Bool {
        guard let reservation = draftOwner.beginTransformation() else {
            return false
        }
        return start(action, reservation: reservation)
    }

    @discardableResult
    func submit(
        _ action: IOSVoiceDraftTextAction,
        capturing snapshot: IOSVoiceDraftTextTargetSnapshot
    ) async -> Bool {
        guard activeAction == nil,
              let reservation = await draftOwner.beginTransformation(
                capturing: snapshot
              ) else {
            return false
        }
        return start(action, reservation: reservation)
    }

    private func start(
        _ action: IOSVoiceDraftTextAction,
        reservation: IOSVoiceDraftTransformationReservation
    ) -> Bool {
        guard activeAction == nil else {
            draftOwner.cancelTransformation(reservation)
            return false
        }
        activeAction = action
        outcome = nil
        let client = client
        activeTask = Task { @MainActor [self] in
            let resolution = await client.perform(action, reservation.text)
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

    private func finish(
        _ action: IOSVoiceDraftTextAction,
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
            case .stale:
                outcome = .failed(action, .draftChanged)
            case .failed, .unavailable:
                outcome = .failed(action, .saveFailed)
            }
        case .failure(let failure):
            draftOwner.cancelTransformation(reservation)
            outcome = .failed(action, failure)
        }
    }
}
