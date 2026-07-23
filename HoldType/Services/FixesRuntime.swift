import Combine
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

@MainActor
final class FixesRuntime: ObservableObject {
    static let shared = makeSharedRuntime()
    static let menuDismissalDelay: Duration = .milliseconds(100)
    static let textFixesConsentRequiredMessage =
        "Allow OpenAI Text Fixes in Settings > Permissions."

    @Published private(set) var hotkeyRegistrationStatus:
        FixesHotkeyRegistrationStatus = .notRegistered
    @Published private(set) var isMenuActionAvailable = false

    private let catalogStore: any MacOSTextFixCatalogStoring
    private let targetService: FocusedTextTargetService
    private let replacementService: any FocusedTextReplacing
    private let executionService: any TextFixExecuting
    private let credentialResolver: any OpenAICredentialResolving
    private let settingsProvider: @MainActor () -> AppSettings
    private let panelPresenter: any FixesPalettePanelPresenting
    private let hotkeyCoordinator: FixesHotkeyCoordinator
    private let eventLogger: any FixesEventLogging

    private var preparationTask: Task<Void, Never>?
    private var menuPresentationTask: Task<Void, Never>?
    private var activeTask: Task<Void, Never>?
    private var presentedCatalog: TextFixCatalog?
    private var presentedSnapshot: FocusedTextTargetSnapshot?
    private var preparedMenuCaptureResult:
        Result<FocusedTextTargetSnapshot, Error>?
    private var lastValidExternalMenuSnapshot: FocusedTextTargetSnapshot?
    private var paletteModel: FixesPaletteModel?

    static func makeSharedRuntime(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        productionRuntimeFactory: @MainActor () -> FixesRuntime = {
            FixesRuntime()
        }
    ) -> FixesRuntime {
        #if DEBUG
        if let runtime = DebugFixesQARuntimeFactory.makeRuntimeIfRequested(
            environment: environment
        ) {
            return runtime
        }
        #endif
        return productionRuntimeFactory()
    }

    convenience init() {
        self.init(
            catalogStore: MacOSTextFixCatalogStore(),
            targetService: FocusedTextTargetService(),
            replacementService: FocusedTextReplacementService(),
            executionService: TextFixExecutionService(),
            credentialResolver: OpenAICredentialResolver(),
            settingsProvider: {
                AppSettingsStore().load()
            },
            panelPresenter: FixesPalettePanelController(),
            hotkeyCoordinator: FixesHotkeyCoordinator()
        )
    }

    init(
        catalogStore: any MacOSTextFixCatalogStoring,
        targetService: FocusedTextTargetService,
        replacementService: any FocusedTextReplacing,
        executionService: any TextFixExecuting,
        credentialResolver: any OpenAICredentialResolving,
        settingsProvider: @escaping @MainActor () -> AppSettings,
        panelPresenter: any FixesPalettePanelPresenting,
        hotkeyCoordinator: FixesHotkeyCoordinator,
        eventLogger: any FixesEventLogging = OSLogFixesEventLogger()
    ) {
        self.catalogStore = catalogStore
        self.targetService = targetService
        self.replacementService = replacementService
        self.executionService = executionService
        self.credentialResolver = credentialResolver
        self.settingsProvider = settingsProvider
        self.panelPresenter = panelPresenter
        self.hotkeyCoordinator = hotkeyCoordinator
        self.eventLogger = eventLogger
    }

    var isPaletteVisible: Bool {
        paletteModel != nil
    }

    func startHotkeyListening() {
        hotkeyCoordinator.start { [weak self] in
            self?.showPalette()
        }
        hotkeyRegistrationStatus = hotkeyCoordinator.registrationStatus
    }

    func stopHotkeyListening() {
        dismissPalette()
        hotkeyCoordinator.stop()
        hotkeyRegistrationStatus = hotkeyCoordinator.registrationStatus
    }

    func showPalette() {
        guard activeTask == nil else {
            eventLogger.record(.availability(outcome: .blockedBusy))
            return
        }

        menuPresentationTask?.cancel()
        menuPresentationTask = nil
        clearPreparedMenuTarget()

        let captureResult = Result {
            try targetService.capture()
        }
        recordCapture(captureResult)
        startPalettePreparation(captureResult: captureResult)
    }

    func prepareMenuTarget() {
        menuPresentationTask?.cancel()
        menuPresentationTask = nil

        guard activeTask == nil else {
            clearPreparedMenuTarget()
            eventLogger.record(.availability(outcome: .blockedBusy))
            return
        }

        resetPalettePreparation()
        let captureResult = captureMenuTarget()
        recordCapture(captureResult)
        preparedMenuCaptureResult = captureResult
        isMenuActionAvailable = (try? captureResult.get()) != nil
    }

    func menuDidOpen() {
        menuPresentationTask?.cancel()
        menuPresentationTask = nil

        if preparedMenuCaptureResult == nil {
            isMenuActionAvailable = false
        }
    }

    func clearPreparedMenuTarget() {
        preparedMenuCaptureResult = nil
        isMenuActionAvailable = false
    }

    func showPaletteAfterMenuDismissal() {
        guard activeTask == nil else {
            eventLogger.record(.availability(outcome: .blockedBusy))
            return
        }

        menuPresentationTask?.cancel()
        guard let captureResult = preparedMenuCaptureResult,
              (try? captureResult.get()) != nil
        else {
            clearPreparedMenuTarget()
            return
        }
        clearPreparedMenuTarget()
        resetPalettePreparation()
        menuPresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.menuDismissalDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.startPalettePreparation(captureResult: captureResult)
            self?.menuPresentationTask = nil
        }
    }

    private func startPalettePreparation(
        captureResult: Result<FocusedTextTargetSnapshot, Error>
    ) {
        resetPalettePreparation()
        preparationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let catalogResult: Result<TextFixCatalog, Error>
            do {
                catalogResult = .success(
                    try await self.catalogStore.load()
                )
            } catch {
                catalogResult = .failure(error)
            }
            guard !Task.isCancelled else {
                return
            }
            self.present(
                captureResult: captureResult,
                catalogResult: catalogResult
            )
            self.preparationTask = nil
        }
    }

    private func captureMenuTarget() -> Result<FocusedTextTargetSnapshot, Error> {
        do {
            let snapshot = try targetService.capture()
            lastValidExternalMenuSnapshot = snapshot
            return .success(snapshot)
        } catch let error as FocusedTextTargetError
            where error == .holdTypeOwnsFocus {
            guard let lastValidExternalMenuSnapshot else {
                return .failure(error)
            }

            do {
                try targetService.validate(lastValidExternalMenuSnapshot)
                return .success(lastValidExternalMenuSnapshot)
            } catch {
                self.lastValidExternalMenuSnapshot = nil
                return .failure(error)
            }
        } catch {
            lastValidExternalMenuSnapshot = nil
            return .failure(error)
        }
    }

    private func resetPalettePreparation() {
        preparationTask?.cancel()
        preparationTask = nil
        panelPresenter.hide()
        clearPresentation()
    }

    func dismissPalette() {
        menuPresentationTask?.cancel()
        menuPresentationTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        activeTask?.cancel()
        executionService.cancelActiveExecution()
        clearPreparedMenuTarget()
        panelPresenter.hide()
        clearPresentation()
    }

    private func present(
        captureResult: Result<FocusedTextTargetSnapshot, Error>,
        catalogResult: Result<TextFixCatalog, Error>
    ) {
        let catalog = (try? catalogResult.get()) ?? .defaults
        let snapshot = try? captureResult.get()
        let status = initialStatus(
            captureResult: captureResult,
            catalogResult: catalogResult
        )

        presentedCatalog = catalog
        presentedSnapshot = snapshot
        let model = FixesPaletteModel(
            catalog: catalog,
            status: status,
            onActivate: { [weak self] actionID in
                self?.activate(actionID: actionID)
            },
            onDismiss: { [weak self] in
                self?.dismissPalette()
            }
        )
        paletteModel = model
        panelPresenter.show(
            model: model,
            accessibilityAnchorRect: snapshot?.anchorRect
        )
    }

    private func initialStatus(
        captureResult: Result<FocusedTextTargetSnapshot, Error>,
        catalogResult: Result<TextFixCatalog, Error>
    ) -> FixesPaletteStatus {
        if case .failure(let error) = catalogResult {
            eventLogger.record(
                .availability(outcome: .blockedCatalogUnavailable)
            )
            return .unavailable(message: Self.userFacingMessage(for: error))
        }
        if case .failure(let error) = captureResult {
            eventLogger.record(
                .availability(outcome: .blockedTargetUnavailable)
            )
            return .unavailable(message: Self.userFacingMessage(for: error))
        }
        guard settingsProvider().hasCurrentTextFixesConsent else {
            eventLogger.record(
                .availability(outcome: .blockedConsentRequired)
            )
            return .unavailable(
                message: Self.textFixesConsentRequiredMessage
            )
        }
        eventLogger.record(.availability(outcome: .ready))
        return .ready
    }

    private func activate(actionID: String) {
        guard let action = presentedCatalog?.action(id: actionID) else {
            eventLogger.record(
                .availability(outcome: .blockedActionUnavailable)
            )
            return
        }
        let identity = FixesActionIdentity(action: action)
        guard activeTask == nil else {
            eventLogger.record(
                .action(identity: identity, outcome: .blockedBusy)
            )
            return
        }
        guard let snapshot = presentedSnapshot else {
            eventLogger.record(
                .action(
                    identity: identity,
                    outcome: .blockedTargetUnavailable
                )
            )
            return
        }

        do {
            try targetService.validate(snapshot)
        } catch {
            eventLogger.record(
                .action(identity: identity, outcome: .stale)
            )
            paletteModel?.updateStatus(
                .staleTarget(message: Self.userFacingMessage(for: error))
            )
            return
        }

        let settings = settingsProvider()
        guard settings.hasCurrentTextFixesConsent else {
            eventLogger.record(
                .action(
                    identity: identity,
                    outcome: .blockedConsentRequired
                )
            )
            paletteModel?.updateStatus(
                .unavailable(
                    message: Self.textFixesConsentRequiredMessage
                )
            )
            return
        }
        let credential: OpenAICredential
        do {
            credential = try credentialResolver.resolveOpenAICredential()
        } catch {
            eventLogger.record(
                .action(
                    identity: identity,
                    outcome: .blockedCredentialUnavailable
                )
            )
            paletteModel?.updateStatus(
                .failure(
                    message: Self.userFacingMessage(for: error),
                    allowsRetry: true
                )
            )
            return
        }

        eventLogger.record(.action(identity: identity, outcome: .started))
        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            var stage = FixesActionStage.provider
            do {
                let output = try await self.executionService.execute(
                    action: action,
                    sourceText: snapshot.sourceText,
                    settings: settings,
                    credential: credential
                )
                try Task.checkCancellation()
                stage = .replacement
                try await self.replacementService.replace(
                    snapshot: snapshot,
                    with: output
                )
                try Task.checkCancellation()
                self.eventLogger.record(
                    .action(identity: identity, outcome: .succeeded)
                )
                self.lastValidExternalMenuSnapshot = nil
                self.panelPresenter.hide()
                self.clearPresentation()
            } catch is CancellationError {
                self.eventLogger.record(
                    .action(identity: identity, outcome: .cancelled)
                )
                // Dismissal owns cancellation and has already cleared the UI.
            } catch let error as FocusedTextTargetError where error == .stale {
                self.eventLogger.record(
                    .action(identity: identity, outcome: .stale)
                )
                self.paletteModel?.updateStatus(
                    .staleTarget(
                        message: Self.userFacingMessage(for: error)
                    )
                )
            } catch {
                self.eventLogger.record(
                    .action(
                        identity: identity,
                        outcome: FixesActionOutcome.terminal(
                            for: error,
                            stage: stage
                        )
                    )
                )
                self.paletteModel?.updateStatus(
                    .failure(
                        message: Self.userFacingMessage(for: error),
                        allowsRetry: self.snapshotStillValid(snapshot)
                    )
                )
            }
            self.activeTask = nil
        }
    }

    private func recordCapture(
        _ result: Result<FocusedTextTargetSnapshot, Error>
    ) {
        switch result {
        case .success:
            eventLogger.record(.capture(outcome: .succeeded))
        case .failure(let error):
            eventLogger.record(
                .capture(
                    outcome: FixesCaptureOutcome.closedCategory(for: error)
                )
            )
        }
    }

    private func snapshotStillValid(
        _ snapshot: FocusedTextTargetSnapshot
    ) -> Bool {
        do {
            try targetService.validate(snapshot)
            return true
        } catch {
            return false
        }
    }

    private func clearPresentation() {
        presentedCatalog = nil
        presentedSnapshot = nil
        paletteModel = nil
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(
               in: .whitespacesAndNewlines
           ).isEmpty {
            return description
        }
        return "Fixes could not complete this action."
    }
}
