import Foundation
import Testing
@testable import HoldType

@MainActor
struct AppSetupControllerTests {

    @Test func startupAttentionPresentsSettingsPermissionsSection() {
        let presenter = SpySetupSettingsPresenter()
        let controller = AppSetupController(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .notDetermined,
                accessibilityTrusted: false,
                inputMonitoringAuthorizationStatus: .denied
            ),
            settingsProvider: { .defaults },
            settingsPresenter: presenter
        )

        controller.presentSetupIfNeededForLaunch()

        #expect(presenter.showFocusedItems == [.permissions])
    }

    @Test func completeStartupSetupDoesNotPresentSettings() {
        let presenter = SpySetupSettingsPresenter()
        let controller = AppSetupController(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            settingsProvider: { .defaults },
            settingsPresenter: presenter
        )

        controller.presentSetupIfNeededForLaunch()

        #expect(presenter.showFocusedItems.isEmpty)
    }

    @Test func completePermissionsDoNotEvaluateOpenAIKeyOnLaunch() {
        let presenter = SpySetupSettingsPresenter()
        let controller = AppSetupController(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            settingsProvider: { .defaults },
            settingsPresenter: presenter
        )

        controller.presentSetupIfNeededForLaunch()

        #expect(presenter.showFocusedItems.isEmpty)
    }

    @Test func missingPermissionsStillPresentOnlyPermissionsOnLaunch() {
        let presenter = SpySetupSettingsPresenter()
        let controller = AppSetupController(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .notDetermined,
                accessibilityTrusted: false,
                inputMonitoringAuthorizationStatus: .allowed
            ),
            settingsProvider: { .defaults },
            settingsPresenter: presenter
        )

        controller.presentSetupIfNeededForLaunch()

        #expect(presenter.showFocusedItems == [.permissions])
    }

    @Test func inputMonitoringMissingAloneDoesNotPresentSettings() {
        let presenter = SpySetupSettingsPresenter()
        let controller = AppSetupController(
            setupStatusProvider: makeSetupStatusProvider(
                microphoneAuthorizationStatus: .allowed,
                accessibilityTrusted: true,
                inputMonitoringAuthorizationStatus: .denied
            ),
            settingsProvider: { .defaults },
            settingsPresenter: presenter
        )

        controller.presentSetupIfNeededForLaunch()

        #expect(presenter.showFocusedItems.isEmpty)
    }

    private func makeSetupStatusProvider(
        microphoneAuthorizationStatus: MicrophoneAuthorizationStatus,
        accessibilityTrusted: Bool,
        inputMonitoringAuthorizationStatus: InputMonitoringAuthorizationStatus
    ) -> AppSetupStatusProvider {
        AppSetupStatusProvider(
            microphonePermissionService: MicrophonePermissionService(
                client: FakeStartupMicrophonePermissionClient(
                    status: microphoneAuthorizationStatus
                )
            ),
            accessibilityPermissionService: AccessibilityPermissionService(
                client: FakeStartupAccessibilityPermissionClient(
                    isTrusted: accessibilityTrusted
                )
            ),
            inputMonitoringPermissionService: InputMonitoringPermissionService(
                client: FakeStartupInputMonitoringPermissionClient(
                    status: inputMonitoringAuthorizationStatus
                )
            )
        )
    }
}

@MainActor
private final class SpySetupSettingsPresenter: SetupSettingsPresenting {
    private(set) var showFocusedItems: [SettingsNavigationItem?] = []
    private(set) var menuDismissalFocusedItems: [SettingsNavigationItem?] = []
    private(set) var systemPromptFocusedItems: [SettingsNavigationItem?] = []

    func show(focusing item: SettingsNavigationItem?) {
        showFocusedItems.append(item)
    }

    func showAfterMenuDismissal(focusing item: SettingsNavigationItem?) {
        menuDismissalFocusedItems.append(item)
    }

    func showAfterSystemPermissionPrompt(focusing item: SettingsNavigationItem?) {
        systemPromptFocusedItems.append(item)
    }
}

private struct FakeStartupMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput = true
    let status: MicrophoneAuthorizationStatus

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        status
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        completion(status == .allowed)
    }
}

private struct FakeStartupAccessibilityPermissionClient: AccessibilityPermissionClient {
    let isTrusted: Bool

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        isTrusted
    }

    func openAccessibilitySettings() -> Bool {
        true
    }
}

private struct FakeStartupInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    let status: InputMonitoringAuthorizationStatus

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        status
    }

    func requestAccess() -> Bool {
        status == .allowed
    }

    func openInputMonitoringSettings() -> Bool {
        true
    }
}
