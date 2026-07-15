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

enum IOSVoiceDraftTextActionNotice: Equatable, Sendable {
    case completed(IOSVoiceDraftTextAction, changed: Bool)
    case failed(
        IOSVoiceDraftTextAction,
        IOSVoiceDraftTextActionFailure
    )

    var message: String {
        switch self {
        case .completed(.translate, changed: true):
            "Draft translated"
        case .completed(.correct, changed: true):
            "Draft improved"
        case .completed(_, changed: false):
            "Draft did not need changes"
        case .failed(let action, .invalidConfiguration):
            action == .translate
                ? "Complete Translation settings and try again."
                : "Review Writing & Correction settings and try again."
        case .failed(_, .credentialUnavailable):
            "Review the saved OpenAI key and try again."
        case .failed(_, .consentUnavailable):
            "Review OpenAI processing consent and try again."
        case .failed(_, .networkUnavailable):
            "The network is unavailable. The Draft was not changed."
        case .failed(_, .timedOut):
            "Processing timed out. The Draft was not changed."
        case .failed(_, .busy):
            "Another OpenAI action is active. Try again when it finishes."
        case .failed(_, .invalidText):
            "Add text to the Draft before using this action."
        case .failed(_, .invalidResponse):
            "OpenAI returned unusable text. The Draft was not changed."
        case .failed(_, .providerUnavailable):
            "OpenAI could not process the Draft. Try again."
        case .failed(_, .draftChanged):
            "The Draft changed while processing. Review it and try again."
        case .failed(_, .saveFailed):
            "The processed text could not be saved. The Draft was not changed."
        case .failed(_, .cancelled):
            "Processing was cancelled. The Draft was not changed."
        }
    }

    var systemImage: String {
        switch self {
        case .completed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
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
    private(set) var notice: IOSVoiceDraftTextActionNotice?

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
        guard activeAction == nil,
              let reservation = draftOwner.beginTransformation() else {
            return false
        }
        activeAction = action
        notice = nil
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

    func dismissNotice() {
        notice = nil
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
                notice = .completed(action, changed: changed)
            case .stale:
                notice = .failed(action, .draftChanged)
            case .failed, .unavailable:
                notice = .failed(action, .saveFailed)
            }
        case .failure(let failure):
            draftOwner.cancelTransformation(reservation)
            notice = .failed(action, failure)
        }
    }
}
