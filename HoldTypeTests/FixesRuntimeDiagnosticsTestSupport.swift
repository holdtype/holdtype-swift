import CoreGraphics
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@testable import HoldType

@MainActor
struct FixesRuntimeDiagnosticsFixture {
    let runtime: FixesRuntime
    let targetClient: FixesRuntimeTargetClient
    let execution: FixesDiagnosticsExecutionService
    let replacement: FixesDiagnosticsReplacementService
    let panel: FixesDiagnosticsPanelPresenter
    let actionID: String
    let actionTag: String
}

@MainActor
func makeFixesRuntimeDiagnosticsFixture(
    actionID: String = "custom.diagnostics",
    sourceText: String = "source",
    prompt: String = "prompt",
    result: String = "result",
    apiKey: String = "test-key",
    isSecure: Bool = false,
    hasCurrentConsent: Bool = true,
    eventLogger: any FixesEventLogging
) throws -> FixesRuntimeDiagnosticsFixture {
    let action = try TextFixAction(
        id: actionID,
        kind: .customPrompt,
        title: "Diagnostics",
        icon: .custom,
        prompt: prompt
    )
    let catalog = try TextFixCatalog.defaults.addingCustomAction(action)
    let token = FocusedTextElementToken()
    let targetClient = FixesRuntimeTargetClient(
        state: FocusedTextElementState(
            token: token,
            processIdentifier: 101,
            text: sourceText,
            selectedRange: NSRange(
                location: 0,
                length: (sourceText as NSString).length
            ),
            anchorRect: CGRect(x: 20, y: 40, width: 60, height: 18),
            isSecure: isSecure
        )
    )
    let targetService = FocusedTextTargetService(
        accessibilityPermissionService: AccessibilityPermissionService(
            client: FixesDiagnosticsPermissionClient()
        ),
        client: targetClient,
        holdTypeProcessIdentifier: 999
    )
    let execution = FixesDiagnosticsExecutionService(output: result)
    let replacement = FixesDiagnosticsReplacementService()
    let panel = FixesDiagnosticsPanelPresenter()
    var settings = AppSettings.defaults
    settings.setTextFixesConsentAccepted(hasCurrentConsent)
    let settingsBox = FixesDiagnosticsSettingsBox(settings: settings)
    let runtime = FixesRuntime(
        catalogStore: FixesDiagnosticsCatalogStore(catalog: catalog),
        targetService: targetService,
        replacementService: replacement,
        executionService: execution,
        credentialResolver: FixesDiagnosticsCredentialResolver(apiKey: apiKey),
        settingsProvider: {
            settingsBox.settings
        },
        panelPresenter: panel,
        hotkeyCoordinator: FixesHotkeyCoordinator(
            hotkeyService: FixesDiagnosticsHotkeyService()
        ),
        eventLogger: eventLogger
    )
    return FixesRuntimeDiagnosticsFixture(
        runtime: runtime,
        targetClient: targetClient,
        execution: execution,
        replacement: replacement,
        panel: panel,
        actionID: action.id,
        actionTag: FixesActionIdentity(action: action).formatted
    )
}

@MainActor
final class FixesDiagnosticsEventRecorder: FixesEventLogging {
    private(set) var events: [FixesLogEvent] = []

    func record(_ event: FixesLogEvent) {
        events.append(event)
    }
}

final class FixesDiagnosticsRuntimeLogRecorder:
    RuntimeDiagnosticLogRecording {
    private(set) var events: [RuntimeDiagnosticEvent] = []

    func record(_ event: RuntimeDiagnosticEvent) {
        events.append(event)
    }
}

@MainActor
final class FixesDiagnosticsExecutionService: TextFixExecuting {
    struct Call {
        let action: TextFixAction
        let sourceText: String
    }

    var output: String
    var error: Error?
    var delay: Duration?
    private(set) var calls: [Call] = []

    init(output: String) {
        self.output = output
    }

    func execute(
        action: TextFixAction,
        sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        calls.append(Call(action: action, sourceText: sourceText))
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
        return output
    }

    func cancelActiveExecution() {}
}

@MainActor
final class FixesDiagnosticsReplacementService: FocusedTextReplacing {
    struct Call {
        let snapshot: FocusedTextTargetSnapshot
        let output: String
    }

    var error: Error?
    private(set) var calls: [Call] = []

    func replace(
        snapshot: FocusedTextTargetSnapshot,
        with output: String
    ) async throws {
        if let error {
            throw error
        }
        calls.append(Call(snapshot: snapshot, output: output))
    }
}

@MainActor
final class FixesDiagnosticsPanelPresenter:
    FixesPalettePanelPresenting {
    private(set) var model: FixesPaletteModel?

    func show(
        model: FixesPaletteModel,
        accessibilityAnchorRect: CGRect?
    ) {
        self.model = model
    }

    func releaseKeyboardFocus() {}

    func hide() {
        model = nil
    }
}

private actor FixesDiagnosticsCatalogStore:
    MacOSTextFixCatalogStoring {
    let catalog: TextFixCatalog

    init(catalog: TextFixCatalog) {
        self.catalog = catalog
    }

    func load() async throws -> TextFixCatalog {
        catalog
    }

    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog {
        catalog
    }
}

private final class FixesDiagnosticsPermissionClient:
    AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        true
    }

    func openAccessibilitySettings() -> Bool {
        false
    }
}

@MainActor
private final class FixesDiagnosticsSettingsBox {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }
}

private struct FixesDiagnosticsCredentialResolver:
    OpenAICredentialResolving {
    let apiKey: String

    func resolveOpenAICredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: apiKey)
    }
}

private final class FixesDiagnosticsHotkeyService:
    FixesHotkeyListening {
    var isListening: Bool {
        false
    }

    func start(handler: @escaping () -> Void) throws {}
    func stop() {}
}
