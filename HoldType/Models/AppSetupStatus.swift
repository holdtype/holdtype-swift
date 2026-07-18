import Foundation

enum APIKeyAvailability: Equatable {
    case unknown
    case saved
    case missing
    case unavailable(String)

    var settingsDescription: String {
        switch self {
        case .unknown:
            return "HoldType will check the saved OpenAI API key when dictation starts."
        case .saved:
            return "HoldType can use the saved Keychain item when transcription starts."
        case .missing:
            return "Transcription needs an OpenAI API key saved in Settings."
        case .unavailable(let message):
            return message
        }
    }
}

enum AppSetupAttentionKind: String, Equatable {
    case microphone
    case accessibility
    case inputMonitoring
}

struct AppSetupAttentionItem: Equatable, Identifiable {
    let kind: AppSetupAttentionKind
    let title: String
    let message: String
    let settingsItem: SettingsNavigationItem
    let blocksRecording: Bool

    var id: AppSetupAttentionKind {
        kind
    }
}

struct AppSetupStatus: Equatable {
    let microphonePermissionStatus: MicrophonePermissionStatus
    let accessibilityPermissionStatus: AccessibilityPermissionStatus
    let inputMonitoringPermissionStatus: InputMonitoringPermissionStatus
    let settings: AppSettings

    var startupAttentionItems: [AppSetupAttentionItem] {
        setupItems()
    }

    var recordingBlockers: [AppSetupAttentionItem] {
        setupItems().filter(\.blocksRecording)
    }

    var requiresStartupAttention: Bool {
        !startupAttentionItems.isEmpty
    }

    var canStartRecording: Bool {
        recordingBlockers.isEmpty
    }

    var preferredStartupSettingsItem: SettingsNavigationItem {
        startupAttentionItems.first?.settingsItem ?? .permissions
    }

    var preferredRecordingSettingsItem: SettingsNavigationItem {
        recordingBlockers.first?.settingsItem ?? preferredStartupSettingsItem
    }

    var recordingBlockedMessage: String {
        let blockers = recordingBlockers
        guard !blockers.isEmpty else {
            return "Ready"
        }

        guard blockers.count == 1, let blocker = blockers.first else {
            let titles = blockers.map(\.title).joined(separator: ", ")
            return "Complete required setup before recording: \(titles)."
        }

        return blocker.message
    }

    private func setupItems() -> [AppSetupAttentionItem] {
        var items: [AppSetupAttentionItem] = []

        if microphonePermissionStatus != .allowed {
            items.append(
                AppSetupAttentionItem(
                    kind: .microphone,
                    title: "Microphone",
                    message: microphonePermissionStatus.settingsDescription,
                    settingsItem: .permissions,
                    blocksRecording: true
                )
            )
        }

        if accessibilityPermissionStatus != .trusted {
            let blocksRecording = settings.automaticallyInsertTranscripts
                || settings.useActiveTextContext
            items.append(
                AppSetupAttentionItem(
                    kind: .accessibility,
                    title: "Accessibility",
                    message: accessibilityPermissionStatus.settingsDescription,
                    settingsItem: .permissions,
                    blocksRecording: blocksRecording
                )
            )
        }

        return items
    }
}

struct AppSetupStatusProvider {
    private let microphonePermissionService: MicrophonePermissionService
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let inputMonitoringPermissionService: InputMonitoringPermissionService

    init(
        microphonePermissionService: MicrophonePermissionService = MicrophonePermissionService(),
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        inputMonitoringPermissionService: InputMonitoringPermissionService = InputMonitoringPermissionService()
    ) {
        self.microphonePermissionService = microphonePermissionService
        self.accessibilityPermissionService = accessibilityPermissionService
        self.inputMonitoringPermissionService = inputMonitoringPermissionService
    }

    func currentStatus(settings: AppSettings) -> AppSetupStatus {
        let microphonePermissionStatus = microphonePermissionService.currentStatus()
        let inputMonitoringPermissionStatus = inputMonitoringPermissionService.currentStatus()
        let accessibilityPermissionStatus = accessibilityPermissionService.currentStatus()

        return AppSetupStatus(
            microphonePermissionStatus: microphonePermissionStatus,
            accessibilityPermissionStatus: accessibilityPermissionStatus,
            inputMonitoringPermissionStatus: inputMonitoringPermissionStatus,
            settings: settings
        )
    }

    func requestMicrophonePermissionIfNeeded(
        completion: @escaping (MicrophonePermissionStatus?) -> Void
    ) {
        guard microphonePermissionService.currentStatus() == .notDetermined else {
            completion(nil)
            return
        }

        microphonePermissionService.requestPermission { status in
            completion(status)
        }
    }
}
