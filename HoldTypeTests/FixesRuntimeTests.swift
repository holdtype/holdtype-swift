import CoreGraphics
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct FixesRuntimeTests {
    @Test func captureHappensSynchronouslyBeforePalettePreparation() async throws {
        let fixture = try makeFixture()

        fixture.runtime.showPalette()

        #expect(fixture.targetClient.focusedElementCallCount == 1)
        #expect(fixture.panel.model == nil)

        try await waitUntil {
            fixture.panel.model != nil
        }
        #expect(fixture.panel.anchorRect == fixture.targetClient.state?.anchorRect)
    }

    @Test func compatibleTargetIsReadyByDefault() async throws {
        let fixture = try makeFixture()

        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }

        let model = try #require(fixture.panel.model)
        #expect(model.status == .ready)
    }

    @Test func paletteShowsTheConfiguredTranslationTarget() async throws {
        let fixture = try makeFixture()

        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }

        let model = try #require(fixture.panel.model)
        let translate = try #require(
            model.actions.first { $0.id == TextFixAction.translateIdentifier }
        )
        #expect(translate.title == "Translate to EN")
    }

    @Test func noFocusedTargetDoesNothing() async throws {
        let fixture = try makeFixture()
        fixture.targetClient.state = nil

        fixture.runtime.showPalette()

        #expect(fixture.panel.model == nil)
        #expect(fixture.invocationFeedback.messages.isEmpty)
        #expect(fixture.execution.calls.isEmpty)
        #expect(await fixture.catalogStore.loadCount() == 0)
    }

    @Test func unusableFocusedTextFieldShowsFeedbackWithoutOpeningPalette() async throws {
        let fixture = try makeFixture()
        let state = try #require(fixture.targetClient.state)
        fixture.targetClient.state = FocusedTextElementState(
            token: state.token,
            processIdentifier: state.processIdentifier,
            text: state.text,
            selectedRange: state.selectedRange,
            anchorRect: state.anchorRect,
            isSecure: true
        )

        fixture.runtime.showPalette()

        #expect(fixture.panel.model == nil)
        #expect(
            fixture.invocationFeedback.messages
                == ["Fixes is not available in secure text fields."]
        )
        #expect(fixture.execution.calls.isEmpty)
        #expect(await fixture.catalogStore.loadCount() == 0)
    }

    @Test func selectedActionTransformsAndReplacesTheFrozenSource() async throws {
        let fixture = try makeFixture()
        fixture.execution.output = "\nFixed\n"
        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }
        let model = try #require(fixture.panel.model)

        model.selectAction(id: "default.improve-writing")
        model.activateSelection()

        try await waitUntil {
            fixture.replacement.calls.count == 1
        }
        let executionCall = try #require(fixture.execution.calls.first)
        #expect(executionCall.sourceText == "selected")
        #expect(executionCall.actionID == "default.improve-writing")
        let replacementCall = try #require(fixture.replacement.calls.first)
        #expect(replacementCall.output == "\nFixed\n")
        #expect(replacementCall.snapshot.sourceText == "selected")
        #expect(fixture.panel.releaseKeyboardFocusCount == 1)
        #expect(fixture.panel.hideCount >= 1)
        #expect(!fixture.runtime.isPaletteVisible)
        #expect(fixture.recentUseStore.recordedActionIDs == ["default.improve-writing"])
    }

    @Test func changedTextBeforeActivationFailsClosed() async throws {
        let fixture = try makeFixture()
        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }
        let model = try #require(fixture.panel.model)
        fixture.targetClient.replaceText("prefix changed suffix")

        model.activateSelection()

        #expect(fixture.execution.calls.isEmpty)
        #expect(fixture.replacement.calls.isEmpty)
        guard case .staleTarget = model.status else {
            Issue.record("Expected stale-target presentation")
            return
        }
    }

    @Test func providerFailureAllowsRetryOnlyWhileSnapshotIsValid() async throws {
        let fixture = try makeFixture()
        fixture.execution.error = FixesRuntimeTestError.provider
        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }
        let model = try #require(fixture.panel.model)

        model.activateSelection()

        try await waitUntil {
            if case .failure = model.status {
                return true
            }
            return false
        }
        guard case .failure(let message, let allowsRetry) = model.status else {
            Issue.record("Expected failure presentation")
            return
        }
        #expect(message == "Provider failed for this Fix.")
        #expect(allowsRetry)
        #expect(fixture.replacement.calls.isEmpty)
        #expect(fixture.recentUseStore.recordedActionIDs.isEmpty)
    }

    @Test func dismissalCancelsProviderAndLeavesSourceUntouched() async throws {
        let fixture = try makeFixture()
        fixture.execution.delay = .seconds(30)
        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }
        let model = try #require(fixture.panel.model)
        model.activateSelection()
        try await waitUntil {
            fixture.execution.calls.count == 1
        }

        fixture.runtime.dismissPalette()

        #expect(fixture.execution.cancelCount == 1)
        #expect(fixture.replacement.calls.isEmpty)
        #expect(!fixture.runtime.isPaletteVisible)
    }

    @Test func optionJCapturesExecutesAndReplacesThroughTheDirectPath() async throws {
        let fixture = try makeFixture()
        fixture.execution.output = "Shortcut fixed"

        fixture.runtime.startHotkeyListening()
        #expect(fixture.runtime.hotkeyRegistrationStatus == .registered)
        #expect(fixture.targetClient.focusedElementCallCount == 0)
        fixture.hotkey.trigger()

        #expect(fixture.targetClient.focusedElementCallCount == 1)
        try await waitUntil {
            fixture.panel.model != nil
        }
        let model = try #require(fixture.panel.model)
        model.selectAction(id: "default.improve-writing")
        model.activateSelection()

        try await waitUntil {
            fixture.replacement.calls.count == 1
        }
        #expect(fixture.targetClient.focusedElementCallCount == 1)
        #expect(fixture.execution.calls.count == 1)
        #expect(fixture.execution.calls.first?.sourceText == "selected")
        #expect(fixture.replacement.calls.first?.output == "Shortcut fixed")
        #expect(fixture.panel.releaseKeyboardFocusCount == 1)

        fixture.runtime.stopHotkeyListening()
        #expect(!fixture.hotkey.isListening)
        #expect(
            fixture.runtime.hotkeyRegistrationStatus == .notRegistered
        )
        fixture.hotkey.trigger()
        #expect(fixture.targetClient.focusedElementCallCount == 1)
    }

    private func makeFixture() throws -> FixesRuntimeFixture {
        let token = FocusedTextElementToken()
        let state = FocusedTextElementState(
            token: token,
            processIdentifier: 101,
            text: "prefix selected suffix",
            selectedRange: NSRange(location: 7, length: 8),
            anchorRect: CGRect(x: 20, y: 40, width: 60, height: 18),
            isSecure: false
        )
        let targetClient = FixesRuntimeTargetClient(state: state)
        let targetService = FocusedTextTargetService(
            accessibilityPermissionService: AccessibilityPermissionService(
                client: FixesRuntimePermissionClient()
            ),
            client: targetClient,
            holdTypeProcessIdentifier: 999
        )
        let catalogStore = FixesRuntimeCatalogStore(catalog: .defaults)
        let replacement = FixesRuntimeReplacementService()
        let execution = FixesRuntimeExecutionService()
        let panel = FixesRuntimePanelPresenter()
        let invocationFeedback = FixesRuntimeInvocationFeedbackPresenter()
        let hotkeyService = FixesRuntimeHotkeyService()
        let recentUseStore = FixesRuntimeRecentUseStore()
        var settings = AppSettings.defaults
        settings.translationTargetLanguage = .english
        let settingsBox = FixesRuntimeSettingsBox(settings: settings)
        let runtime = FixesRuntime(
            catalogStore: catalogStore,
            targetService: targetService,
            replacementService: replacement,
            executionService: execution,
            credentialResolver: FixesRuntimeCredentialResolver(),
            settingsProvider: {
                settingsBox.settings
            },
            panelPresenter: panel,
            invocationFeedbackPresenter: invocationFeedback,
            hotkeyCoordinator: FixesHotkeyCoordinator(
                hotkeyService: hotkeyService
            ),
            recentUseStore: recentUseStore
        )
        return FixesRuntimeFixture(
            runtime: runtime,
            targetClient: targetClient,
            catalogStore: catalogStore,
            replacement: replacement,
            execution: execution,
            panel: panel,
            invocationFeedback: invocationFeedback,
            hotkey: hotkeyService,
            settings: settingsBox,
            recentUseStore: recentUseStore
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<200 {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for asynchronous Fixes state")
    }
}

@MainActor
private struct FixesRuntimeFixture {
    let runtime: FixesRuntime
    let targetClient: FixesRuntimeTargetClient
    let catalogStore: FixesRuntimeCatalogStore
    let replacement: FixesRuntimeReplacementService
    let execution: FixesRuntimeExecutionService
    let panel: FixesRuntimePanelPresenter
    let invocationFeedback: FixesRuntimeInvocationFeedbackPresenter
    let hotkey: FixesRuntimeHotkeyService
    let settings: FixesRuntimeSettingsBox
    let recentUseStore: FixesRuntimeRecentUseStore
}

@MainActor
private final class FixesRuntimeSettingsBox {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }
}

private actor FixesRuntimeCatalogStore: MacOSTextFixCatalogStoring {
    let catalog: TextFixCatalog
    private var loads = 0

    init(catalog: TextFixCatalog) {
        self.catalog = catalog
    }

    func load() async throws -> TextFixCatalog {
        loads += 1
        return catalog
    }

    func loadCount() -> Int {
        loads
    }

    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog {
        catalog
    }
}

private final class FixesRuntimePermissionClient:
    AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        true
    }

    func openAccessibilitySettings() -> Bool {
        false
    }
}

@MainActor
private final class FixesRuntimeReplacementService: FocusedTextReplacing {
    struct Call {
        let snapshot: FocusedTextTargetSnapshot
        let output: String
    }

    private(set) var calls: [Call] = []

    func replace(
        snapshot: FocusedTextTargetSnapshot,
        with output: String
    ) async throws {
        calls.append(Call(snapshot: snapshot, output: output))
    }
}

@MainActor
private final class FixesRuntimeExecutionService: TextFixExecuting {
    struct Call {
        let actionID: String
        let sourceText: String
    }

    var output = "Fixed"
    var error: Error?
    var delay: Duration?
    private(set) var calls: [Call] = []
    private(set) var cancelCount = 0

    func execute(
        action: TextFixAction,
        sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        calls.append(Call(actionID: action.id, sourceText: sourceText))
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
        return output
    }

    func cancelActiveExecution() {
        cancelCount += 1
    }
}

@MainActor
private final class FixesRuntimePanelPresenter:
    FixesPalettePanelPresenting {
    private(set) var model: FixesPaletteModel?
    private(set) var anchorRect: CGRect?
    private(set) var releaseKeyboardFocusCount = 0
    private(set) var hideCount = 0

    func show(
        model: FixesPaletteModel,
        accessibilityAnchorRect: CGRect?
    ) {
        self.model = model
        anchorRect = accessibilityAnchorRect
    }

    func releaseKeyboardFocus() {
        releaseKeyboardFocusCount += 1
    }

    func hide() {
        hideCount += 1
        model = nil
    }
}

@MainActor
private final class FixesRuntimeInvocationFeedbackPresenter:
    FixesInvocationFeedbackPresenting {
    private(set) var messages: [String] = []

    func show(message: String) {
        messages.append(message)
    }

    func hide() {}
}

private struct FixesRuntimeCredentialResolver:
    OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: "test-key")
    }
}

private final class FixesRuntimeHotkeyService: FixesHotkeyListening {
    private(set) var isListening = false
    private var handler: (() -> Void)?

    func start(handler: @escaping () -> Void) throws {
        self.handler = handler
        isListening = true
    }

    func stop() {
        handler = nil
        isListening = false
    }

    func trigger() {
        handler?()
    }
}

@MainActor
private final class FixesRuntimeRecentUseStore: FixesRecentUseStoring {
    private(set) var recordedActionIDs: [String] = []

    func recentActionIDs() -> [String] {
        []
    }

    func recordSuccessfulUse(of actionID: String) {
        recordedActionIDs.append(actionID)
    }
}

private enum FixesRuntimeTestError: Error, LocalizedError {
    case provider

    var errorDescription: String? {
        "Provider failed for this Fix."
    }
}
