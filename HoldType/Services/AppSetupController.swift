@MainActor
protocol SetupSettingsPresenting: AnyObject {
    func show(focusing item: SettingsNavigationItem?)
    func showAfterMenuDismissal(focusing item: SettingsNavigationItem?)
    func showAfterSystemPermissionPrompt(focusing item: SettingsNavigationItem?)
}

@MainActor
struct AppSetupController {
    private let setupStatusProvider: AppSetupStatusProvider
    private let settingsProvider: @MainActor () -> AppSettings
    private let settingsPresenter: any SetupSettingsPresenting

    init() {
        self.init(
            setupStatusProvider: AppSetupStatusProvider(),
            settingsProvider: { AppSettingsStore().load() },
            settingsPresenter: SettingsWindowPresenter.shared
        )
    }

    init(
        setupStatusProvider: AppSetupStatusProvider,
        settingsProvider: @escaping @MainActor () -> AppSettings,
        settingsPresenter: any SetupSettingsPresenting
    ) {
        self.setupStatusProvider = setupStatusProvider
        self.settingsProvider = settingsProvider
        self.settingsPresenter = settingsPresenter
    }

    func presentSetupIfNeededForLaunch() {
        let status = setupStatusProvider.currentStatus(settings: settingsProvider())
        if status.requiresStartupAttention {
            settingsPresenter.show(focusing: status.preferredStartupSettingsItem)
            return
        }
    }
}
