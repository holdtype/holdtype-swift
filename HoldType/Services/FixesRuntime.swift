import Combine
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

@MainActor
final class FixesRuntime: ObservableObject {
    static let shared = FixesRuntime()
    static let menuDismissalDelay: Duration = .milliseconds(100)

    @Published private(set) var hotkeyRegistrationStatus:
        FixesHotkeyRegistrationStatus = .notRegistered

    private let catalogStore: any MacOSTextFixCatalogStoring
    private let targetService: FocusedTextTargetService
    private let replacementService: any FocusedTextReplacing
    private let executionService: any TextFixExecuting
    private let credentialResolver: any OpenAICredentialResolving
    private let settingsProvider: @MainActor () -> AppSettings
    private let panelPresenter: any FixesPalettePanelPresenting
    private let hotkeyCoordinator: FixesHotkeyCoordinator

    private var preparationTask: Task<Void, Never>?
    private var menuPresentationTask: Task<Void, Never>?
    private var activeTask: Task<Void, Never>?
    private var presentedCatalog: TextFixCatalog?
    private var presentedSnapshot: FocusedTextTargetSnapshot?
    private var paletteModel: FixesPaletteModel?

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
        hotkeyCoordinator: FixesHotkeyCoordinator
    ) {
        self.catalogStore = catalogStore
        self.targetService = targetService
        self.replacementService = replacementService
        self.executionService = executionService
        self.credentialResolver = credentialResolver
        self.settingsProvider = settingsProvider
        self.panelPresenter = panelPresenter
        self.hotkeyCoordinator = hotkeyCoordinator
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
            return
        }

        preparationTask?.cancel()
        panelPresenter.hide()
        clearPresentation()

        let captureResult = Result {
            try targetService.capture()
        }
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

    func showPaletteAfterMenuDismissal() {
        menuPresentationTask?.cancel()
        menuPresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.menuDismissalDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.showPalette()
            self?.menuPresentationTask = nil
        }
    }

    func dismissPalette() {
        menuPresentationTask?.cancel()
        menuPresentationTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        activeTask?.cancel()
        executionService.cancelActiveExecution()
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
            return .unavailable(message: Self.userFacingMessage(for: error))
        }
        if case .failure(let error) = captureResult {
            return .unavailable(message: Self.userFacingMessage(for: error))
        }
        return .ready
    }

    private func activate(actionID: String) {
        guard activeTask == nil,
              let snapshot = presentedSnapshot,
              let action = presentedCatalog?.action(id: actionID)
        else {
            return
        }

        do {
            try targetService.validate(snapshot)
        } catch {
            paletteModel?.updateStatus(
                .staleTarget(message: Self.userFacingMessage(for: error))
            )
            return
        }

        let settings = settingsProvider()
        let credential: OpenAICredential
        do {
            credential = try credentialResolver.resolveOpenAICredential()
        } catch {
            paletteModel?.updateStatus(
                .failure(
                    message: Self.userFacingMessage(for: error),
                    allowsRetry: true
                )
            )
            return
        }

        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let output = try await self.executionService.execute(
                    action: action,
                    sourceText: snapshot.sourceText,
                    settings: settings,
                    credential: credential
                )
                try Task.checkCancellation()
                try await self.replacementService.replace(
                    snapshot: snapshot,
                    with: output
                )
                try Task.checkCancellation()
                self.panelPresenter.hide()
                self.clearPresentation()
            } catch is CancellationError {
                // Dismissal owns cancellation and has already cleared the UI.
            } catch let error as FocusedTextTargetError where error == .stale {
                self.paletteModel?.updateStatus(
                    .staleTarget(
                        message: Self.userFacingMessage(for: error)
                    )
                )
            } catch {
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
