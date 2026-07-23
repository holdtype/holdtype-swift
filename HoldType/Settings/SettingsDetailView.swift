//
//  SettingsDetailView.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct SettingsDetailView: View {
    let item: SettingsNavigationItem
    let setupWarning: SettingsSetupWarning?

    @Binding var apiKeyInput: String
    let apiKeyStatus: APIKeySettingsStatus
    @Binding var settings: AppSettings
    let hotkeyRegistrationStatus: GlobalHotkeyRegistrationStatus
    let fixesHotkeyRegistrationStatus: FixesHotkeyRegistrationStatus
    let microphonePermissionStatus: MicrophonePermissionStatus
    let accessibilityPermissionStatus: AccessibilityPermissionStatus
    let inputMonitoringPermissionStatus: InputMonitoringPermissionStatus
    let showsInputMonitoringManualFallbackWarning: Bool
    let launchAtLoginStatus: LaunchAtLoginStatus
    let transcriptHistoryCount: Int
    let openAIUsageSummary: OpenAIUsageSummary
    let openAIUsageStorageError: String?
    let recordingCacheSummary: RecordingCacheSummary
    let recordingCacheError: String?
    let diagnosticReportSummary: DiagnosticReportSummary
    let diagnosticRuntimeLogSummary: DiagnosticRuntimeLogSummary
    let diagnosticsError: String?
    let diagnosticRuntimeLogError: String?
    let diagnosticBundleResult: DiagnosticBundleResult?
    let diagnosticBundleError: String?
    @ObservedObject var softwareUpdates: SoftwareUpdateService
    let onAPIKeyInputChange: () -> Void
    let onPasteAPIKeyFromClipboard: () -> Void
    let onRemoveAPIKey: () -> Void
    let onMicrophonePermissionAction: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onInputMonitoringPermissionAction: () -> Void
    let onSetLaunchAtLogin: (Bool) -> Void
    let onOpenLoginItemsSettings: () -> Void
    let onClearTranscriptHistory: () -> Void
    let onResetOpenAIUsage: () -> Void
    let onRevealRecordingCache: () -> Void
    let onRefreshRecordingCache: () -> Void
    let onRevealRecording: (RecordingCacheItem) -> Void
    let onDeleteRecording: (RecordingCacheItem) -> Void
    let onClearRecordingCache: () -> Void
    let onRevealDiagnosticReportsDirectory: () -> Void
    let onCopyDiagnosticReportsDirectoryPath: () -> Void
    let onRefreshDiagnostics: () -> Void
    let onRevealDiagnosticReport: (DiagnosticReportItem) -> Void
    let onCopyDiagnosticReportPath: (DiagnosticReportItem) -> Void
    let onRevealRuntimeLogsDirectory: () -> Void
    let onCopyRuntimeLogs: () -> Void
    let onExportDiagnosticBundle: () -> Void

    var body: some View {
        Form {
            if let setupWarning {
                SettingsSetupWarningBanner(warning: setupWarning)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(EmptyView())
            }

            settingsSection
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(item.title)
    }

    @ViewBuilder
    private var settingsSection: some View {
        switch item {
        case .permissions:
            PermissionsSettingsSection(
                settings: $settings,
                microphonePermissionStatus: microphonePermissionStatus,
                accessibilityPermissionStatus: accessibilityPermissionStatus,
                inputMonitoringPermissionStatus: inputMonitoringPermissionStatus,
                showsInputMonitoringManualFallbackWarning: showsInputMonitoringManualFallbackWarning,
                launchAtLoginStatus: launchAtLoginStatus,
                onSetLaunchAtLogin: onSetLaunchAtLogin,
                onOpenLoginItemsSettings: onOpenLoginItemsSettings,
                onMicrophonePermissionAction: onMicrophonePermissionAction,
                onOpenAccessibilitySettings: onOpenAccessibilitySettings,
                onInputMonitoringPermissionAction: onInputMonitoringPermissionAction
            )
        case .openAI:
            OpenAISettingsSection(
                apiKeyInput: $apiKeyInput,
                apiKeyStatus: apiKeyStatus,
                onAPIKeyInputChange: onAPIKeyInputChange,
                onPasteAPIKeyFromClipboard: onPasteAPIKeyFromClipboard,
                onRemoveAPIKey: onRemoveAPIKey
            )
        case .billing:
            BillingSettingsSection(
                summary: openAIUsageSummary,
                storageErrorMessage: openAIUsageStorageError,
                onResetUsage: onResetOpenAIUsage
            )
        case .transcription:
            TranscriptionSettingsSection(settings: $settings)
        case .textCorrection:
            TextCorrectionSettingsSection(settings: $settings)
        case .translation:
            TranslationSettingsSection(settings: $settings)
        case .dictionary:
            DictionarySettingsSection(settings: $settings)
        case .shortcut:
            KeyboardShortcutSettingsSection(
                settings: $settings,
                status: hotkeyRegistrationStatus,
                fixesStatus: fixesHotkeyRegistrationStatus
            )
        case .behavior:
            BehaviorSettingsSection(
                settings: $settings,
                launchAtLoginStatus: launchAtLoginStatus,
                transcriptHistoryCount: transcriptHistoryCount,
                onSetLaunchAtLogin: onSetLaunchAtLogin,
                onOpenLoginItemsSettings: onOpenLoginItemsSettings,
                onClearTranscriptHistory: onClearTranscriptHistory
            )
        case .cache:
            RecordingCacheSettingsSection(
                settings: $settings,
                summary: recordingCacheSummary,
                errorMessage: recordingCacheError,
                onRevealCache: onRevealRecordingCache,
                onRefresh: onRefreshRecordingCache,
                onRevealRecording: onRevealRecording,
                onDeleteRecording: onDeleteRecording,
                onClearCache: onClearRecordingCache
            )
        case .updates:
            SoftwareUpdateSettingsSection(softwareUpdates: softwareUpdates)
        case .diagnostics:
            DiagnosticsSettingsSection(
                summary: diagnosticReportSummary,
                runtimeLogSummary: diagnosticRuntimeLogSummary,
                errorMessage: diagnosticsError,
                runtimeLogErrorMessage: diagnosticRuntimeLogError,
                bundleResult: diagnosticBundleResult,
                bundleErrorMessage: diagnosticBundleError,
                onRevealReportsDirectory: onRevealDiagnosticReportsDirectory,
                onCopyReportsDirectoryPath: onCopyDiagnosticReportsDirectoryPath,
                onRefresh: onRefreshDiagnostics,
                onRevealReport: onRevealDiagnosticReport,
                onCopyReportPath: onCopyDiagnosticReportPath,
                onRevealRuntimeLogsDirectory: onRevealRuntimeLogsDirectory,
                onCopyRuntimeLogs: onCopyRuntimeLogs,
                onExportBundle: onExportDiagnosticBundle
            )
        }
    }
}

#Preview("Permissions") {
    SettingsDetailView(
        item: .permissions,
        setupWarning: SettingsSetupWarning(
            title: "Required setup is incomplete",
            message: "Complete these settings before HoldType can start dictation reliably.",
            detailLines: ["Microphone", "Accessibility"]
        ),
        apiKeyInput: .constant(""),
        apiKeyStatus: .missing,
        settings: .constant(.defaults),
        hotkeyRegistrationStatus: .registered(.defaultDictation),
        fixesHotkeyRegistrationStatus: .registered,
        microphonePermissionStatus: .notDetermined,
        accessibilityPermissionStatus: .notTrusted,
        inputMonitoringPermissionStatus: .notDetermined,
        showsInputMonitoringManualFallbackWarning: true,
        launchAtLoginStatus: .disabled,
        transcriptHistoryCount: 0,
        openAIUsageSummary: .empty(),
        openAIUsageStorageError: nil,
        recordingCacheSummary: RecordingCacheSummary(
            directoryURL: URL(fileURLWithPath: "/tmp/HoldType/Recordings"),
            items: []
        ),
        recordingCacheError: nil,
        diagnosticReportSummary: DiagnosticReportSummary(
            directoryURL: URL(fileURLWithPath: "/Users/example/Library/Logs/DiagnosticReports"),
            directoryStatus: .available,
            items: []
        ),
        diagnosticRuntimeLogSummary: DiagnosticRuntimeLogSummary(
            directoryURL: URL(fileURLWithPath: "/Users/example/Library/Caches/HoldType/Diagnostics/RuntimeLogs"),
            recentLines: []
        ),
        diagnosticsError: nil,
        diagnosticRuntimeLogError: nil,
        diagnosticBundleResult: nil,
        diagnosticBundleError: nil,
        softwareUpdates: .shared,
        onAPIKeyInputChange: {},
        onPasteAPIKeyFromClipboard: {},
        onRemoveAPIKey: {},
        onMicrophonePermissionAction: {},
        onOpenAccessibilitySettings: {},
        onInputMonitoringPermissionAction: {},
        onSetLaunchAtLogin: { _ in },
        onOpenLoginItemsSettings: {},
        onClearTranscriptHistory: {},
        onResetOpenAIUsage: {},
        onRevealRecordingCache: {},
        onRefreshRecordingCache: {},
        onRevealRecording: { _ in },
        onDeleteRecording: { _ in },
        onClearRecordingCache: {},
        onRevealDiagnosticReportsDirectory: {},
        onCopyDiagnosticReportsDirectoryPath: {},
        onRefreshDiagnostics: {},
        onRevealDiagnosticReport: { _ in },
        onCopyDiagnosticReportPath: { _ in },
        onRevealRuntimeLogsDirectory: {},
        onCopyRuntimeLogs: {},
        onExportDiagnosticBundle: {}
    )
    .frame(width: 520, height: 420)
}
