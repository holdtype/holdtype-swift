//
//  SettingsView.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import AppKit
import HoldTypeDomain
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var navigation: SettingsWindowNavigation
    @StateObject private var permissionsModel: SettingsPermissionsViewModel
    @State private var appSettings: AppSettings
    @StateObject private var apiKeySettingsModel: OpenAIAPIKeySettingsViewModel
    @State private var hotkeyRegistrationStatus: GlobalHotkeyRegistrationStatus
    @State private var launchAtLoginStatus: LaunchAtLoginStatus
    @State private var recordingCacheSummary: RecordingCacheSummary
    @State private var recordingCacheErrorMessage: String?
    @State private var diagnosticReportSummary: DiagnosticReportSummary
    @State private var diagnosticRuntimeLogSummary: DiagnosticRuntimeLogSummary
    @State private var diagnosticsErrorMessage: String?
    @State private var diagnosticRuntimeLogErrorMessage: String?
    @State private var diagnosticBundleResult: DiagnosticBundleResult?
    @State private var diagnosticBundleErrorMessage: String?
    @ObservedObject private var transcriptHistoryStore: TranscriptRecoveryHistoryStore
    @ObservedObject private var openAIUsageStore: OpenAIUsageStore
    @ObservedObject private var softwareUpdates: SoftwareUpdateService

    private let appSettingsStore: AppSettingsStore
    private let hotkeyStatusProvider: @MainActor () -> GlobalHotkeyRegistrationStatus
    private let launchAtLoginService: any LaunchAtLoginServicing
    private let settingsVisibilityRestorer: @MainActor (SettingsNavigationItem) -> Void
    private let recordingCache: any RecordingCacheManaging
    private let diagnostics: any DiagnosticsManaging

    @MainActor
    init(
        navigation: SettingsWindowNavigation = SettingsWindowNavigation(),
        microphonePermissionService: MicrophonePermissionService = MicrophonePermissionService(),
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        inputMonitoringPermissionService: InputMonitoringPermissionService = InputMonitoringPermissionService(),
        apiKeyStorage: any APIKeyStorage = APIKeyCredentialProvider.shared,
        appSettingsStore: AppSettingsStore = AppSettingsStore(),
        hotkeyStatusProvider: @escaping @MainActor () -> GlobalHotkeyRegistrationStatus = { .notRegistered },
        launchAtLoginService: any LaunchAtLoginServicing = LaunchAtLoginService(),
        settingsVisibilityRestorer: @escaping @MainActor (SettingsNavigationItem) -> Void = { item in
            SettingsWindowPresenter.shared.showAfterSystemPermissionPrompt(focusing: item)
        },
        permissionPollingIntervalNanoseconds: UInt64 = 1_000_000_000,
        transcriptHistoryStore: TranscriptRecoveryHistoryStore? = nil,
        openAIUsageStore: OpenAIUsageStore? = nil,
        softwareUpdates: SoftwareUpdateService = .shared,
        recordingCache: any RecordingCacheManaging = RecordingCacheService.shared,
        diagnostics: any DiagnosticsManaging = DiagnosticsService.shared
    ) {
        self.navigation = navigation
        self.appSettingsStore = appSettingsStore
        self.hotkeyStatusProvider = hotkeyStatusProvider
        self.launchAtLoginService = launchAtLoginService
        self.settingsVisibilityRestorer = settingsVisibilityRestorer
        self.recordingCache = recordingCache
        self.diagnostics = diagnostics
        self.transcriptHistoryStore = transcriptHistoryStore ?? TranscriptRecoveryHistoryStore.shared
        self.openAIUsageStore = openAIUsageStore ?? OpenAIUsageStore.shared
        self.softwareUpdates = softwareUpdates
        let initialRecordingCacheState = SettingsViewStateLoader.loadRecordingCacheState(
            recordingCache: recordingCache
        )
        let initialDiagnosticsState = SettingsViewStateLoader.loadDiagnosticsState(
            diagnostics: diagnostics
        )
        let initialRuntimeLogState = SettingsViewStateLoader.loadRuntimeLogState(
            diagnostics: diagnostics
        )
        _appSettings = State(initialValue: appSettingsStore.load())
        _permissionsModel = StateObject(
            wrappedValue: SettingsPermissionsViewModel(
                microphonePermissionService: microphonePermissionService,
                accessibilityPermissionService: accessibilityPermissionService,
                inputMonitoringPermissionService: inputMonitoringPermissionService,
                visiblePollingIntervalNanoseconds: permissionPollingIntervalNanoseconds
            )
        )
        _apiKeySettingsModel = StateObject(
            wrappedValue: OpenAIAPIKeySettingsViewModel(apiKeyStorage: apiKeyStorage)
        )
        _hotkeyRegistrationStatus = State(initialValue: hotkeyStatusProvider())
        _launchAtLoginStatus = State(initialValue: launchAtLoginService.currentStatus())
        _recordingCacheSummary = State(initialValue: initialRecordingCacheState.summary)
        _recordingCacheErrorMessage = State(initialValue: initialRecordingCacheState.errorMessage)
        _diagnosticReportSummary = State(initialValue: initialDiagnosticsState.summary)
        _diagnosticRuntimeLogSummary = State(initialValue: initialRuntimeLogState.summary)
        _diagnosticsErrorMessage = State(initialValue: initialDiagnosticsState.errorMessage)
        _diagnosticRuntimeLogErrorMessage = State(initialValue: initialRuntimeLogState.errorMessage)
        _diagnosticBundleResult = State(initialValue: nil)
        _diagnosticBundleErrorMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationSplitView {
            SettingsSidebarView(selection: $navigation.selectedItem)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            SettingsDetailView(
                item: navigation.selectedItem ?? .permissions,
                setupWarning: setupWarning(for: navigation.selectedItem ?? .permissions),
                apiKeyInput: apiKeyInputBinding,
                apiKeyStatus: apiKeySettingsModel.status,
                settings: appSettingsBinding,
                hotkeyRegistrationStatus: hotkeyRegistrationStatus,
                microphonePermissionStatus: permissionsModel.microphonePermissionStatus,
                accessibilityPermissionStatus: permissionsModel.accessibilityPermissionStatus,
                inputMonitoringPermissionStatus: permissionsModel.inputMonitoringPermissionStatus,
                showsInputMonitoringManualFallbackWarning: permissionsModel.showsInputMonitoringManualFallbackWarning,
                launchAtLoginStatus: launchAtLoginStatus,
                transcriptHistoryCount: transcriptHistoryStore.entries.count,
                openAIUsageSummary: OpenAIUsageSummary.make(events: openAIUsageStore.entries),
                openAIUsageStorageError: openAIUsageStore.storageErrorMessage,
                recordingCacheSummary: recordingCacheSummary,
                recordingCacheError: recordingCacheErrorMessage,
                diagnosticReportSummary: diagnosticReportSummary,
                diagnosticRuntimeLogSummary: diagnosticRuntimeLogSummary,
                diagnosticsError: diagnosticsErrorMessage,
                diagnosticRuntimeLogError: diagnosticRuntimeLogErrorMessage,
                diagnosticBundleResult: diagnosticBundleResult,
                diagnosticBundleError: diagnosticBundleErrorMessage,
                softwareUpdates: softwareUpdates,
                onAPIKeyInputChange: apiKeySettingsModel.autosaveAPIKeyIfNeeded,
                onPasteAPIKeyFromClipboard: apiKeySettingsModel.pasteAPIKeyFromClipboard,
                onRemoveAPIKey: apiKeySettingsModel.removeAPIKey,
                onMicrophonePermissionAction: handleMicrophonePermissionAction,
                onOpenAccessibilitySettings: handleAccessibilityPermissionAction,
                onInputMonitoringPermissionAction: handleInputMonitoringPermissionAction,
                onSetLaunchAtLogin: setLaunchAtLogin,
                onOpenLoginItemsSettings: openLoginItemsSettings,
                onClearTranscriptHistory: clearTranscriptHistory,
                onResetOpenAIUsage: resetOpenAIUsage,
                onRevealRecordingCache: revealRecordingCache,
                onRefreshRecordingCache: refreshRecordingCache,
                onRevealRecording: revealRecording,
                onDeleteRecording: deleteRecording,
                onClearRecordingCache: clearRecordingCache,
                onRevealDiagnosticReportsDirectory: revealDiagnosticReportsDirectory,
                onCopyDiagnosticReportsDirectoryPath: copyDiagnosticReportsDirectoryPath,
                onRefreshDiagnostics: refreshDiagnostics,
                onRevealDiagnosticReport: revealDiagnosticReport,
                onCopyDiagnosticReportPath: copyDiagnosticReportPath,
                onRevealRuntimeLogsDirectory: revealRuntimeLogsDirectory,
                onCopyRuntimeLogs: copyRuntimeLogs,
                onExportDiagnosticBundle: exportDiagnosticBundle
            )
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            navigation.selectedItem = navigation.selectedItem ?? .permissions
            refreshFocusedSettingsWindowState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshFocusedSettingsWindowState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingCacheDidChange)) { _ in
            refreshRecordingCache()
        }
        .onChange(of: navigation.focusRefreshToken) { _, _ in
            refreshFocusedSettingsWindowState()
        }
        .onChange(of: navigation.selectedItem) { _, selectedItem in
            let item = selectedItem ?? .permissions

            if item == .permissions {
                permissionsModel.refreshOnAppearOrFocus()
            }

            updatePermissionsPolling(for: item)
        }
        .onDisappear {
            permissionsModel.stopVisiblePermissionsPolling()
        }
    }

    private var setupStatus: AppSetupStatus {
        AppSetupStatus(
            microphonePermissionStatus: permissionsModel.microphonePermissionStatus,
            accessibilityPermissionStatus: permissionsModel.accessibilityPermissionStatus,
            settings: appSettings
        )
    }

    private func setupWarning(for item: SettingsNavigationItem) -> SettingsSetupWarning? {
        switch item {
        case .permissions:
            return SettingsSetupWarning.permissions(from: setupStatus)
        case .openAI:
            return SettingsSetupWarning.openAI(
                apiKeyAvailability: apiKeySettingsModel.apiKeyAvailability
            )
        case .billing,
             .transcription,
             .textCorrection,
             .translation,
             .dictionary,
             .shortcut,
             .behavior,
             .cache,
             .updates,
             .diagnostics:
            return nil
        }
    }

    private var apiKeyInputBinding: Binding<String> {
        Binding(
            get: {
                apiKeySettingsModel.state.input
            },
            set: { newValue in
                apiKeySettingsModel.state.input = newValue
            }
        )
    }

    private var appSettingsBinding: Binding<AppSettings> {
        Binding(
            get: {
                appSettings
            },
            set: { newValue in
                let oldSettings = appSettings
                let shouldClearTranscriptHistory = oldSettings.saveTranscriptHistory
                    && !newValue.saveTranscriptHistory
                appSettings = newValue
                appSettingsStore.save(newValue)

                if shouldClearTranscriptHistory {
                    transcriptHistoryStore.clear()
                }

                applyRecordingCacheRetentionIfNeeded(oldSettings: oldSettings, newSettings: newValue)
                refreshSetupStatusAfterSettingsChange()
            }
        )
    }

    private func reloadAppSettings() {
        appSettings = appSettingsStore.load()
    }

    private func refreshSettingsWindowState() {
        reloadAppSettings()
        refreshSetupStatusForVisibleSettings()
        refreshHotkeyRegistrationStatus()
        refreshLaunchAtLoginStatus()
        refreshOpenAIUsage()
        refreshRecordingCache()
        refreshDiagnostics()
    }

    private func refreshFocusedSettingsWindowState() {
        refreshSettingsWindowState()
        updatePermissionsPolling(for: navigation.selectedItem ?? .permissions)
    }

    private func refreshSetupStatusForVisibleSettings() {
        permissionsModel.refreshOnAppearOrFocus()
        apiKeySettingsModel.refreshAvailability()
    }

    private func refreshSetupStatusAfterSettingsChange() {
        permissionsModel.refreshAfterSettingsChange()
        apiKeySettingsModel.refreshAvailability()
    }

    private func keepSettingsVisibleIfSetupStillNeedsAttention(focusing item: SettingsNavigationItem) {
        refreshSetupStatusForVisibleSettings()

        guard setupStatus.requiresStartupAttention else {
            return
        }

        settingsVisibilityRestorer(item)
    }

    private func handleMicrophonePermissionAction() {
        permissionsModel.handleMicrophonePermissionAction {
            keepSettingsVisibleIfSetupStillNeedsAttention(focusing: .permissions)
        }
    }

    private func handleAccessibilityPermissionAction() {
        permissionsModel.handleAccessibilityPermissionAction()
        keepSettingsVisibleIfSetupStillNeedsAttention(focusing: .permissions)
    }

    private func handleInputMonitoringPermissionAction() {
        permissionsModel.handleInputMonitoringPermissionAction()
        keepSettingsVisibleIfSetupStillNeedsAttention(focusing: .permissions)
    }

    private func updatePermissionsPolling(for item: SettingsNavigationItem) {
        if item == .permissions {
            permissionsModel.startVisiblePermissionsPolling()
        } else {
            permissionsModel.stopVisiblePermissionsPolling()
        }
    }

    private func refreshHotkeyRegistrationStatus() {
        hotkeyRegistrationStatus = hotkeyStatusProvider()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.currentStatus()
    }

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLoginStatus = launchAtLoginService.setEnabled(isEnabled)
    }

    private func openLoginItemsSettings() {
        _ = launchAtLoginService.openLoginItemsSettings()
    }

    private func clearTranscriptHistory() {
        transcriptHistoryStore.clear()
    }

    private func refreshOpenAIUsage() {
        openAIUsageStore.reload()
    }

    private func resetOpenAIUsage() {
        openAIUsageStore.clearUsageEstimate()
    }

    private func refreshRecordingCache() {
        let cacheState = SettingsViewStateLoader.loadRecordingCacheState(
            recordingCache: recordingCache
        )
        recordingCacheSummary = cacheState.summary
        recordingCacheErrorMessage = cacheState.errorMessage
    }

    private func revealRecordingCache() {
        recordingCache.revealInFinder(recordingCache.directoryURL)
    }

    private func revealRecording(_ item: RecordingCacheItem) {
        recordingCache.revealInFinder(item.fileURL)
    }

    private func deleteRecording(_ item: RecordingCacheItem) {
        do {
            try recordingCache.deleteRecording(at: item.fileURL)
            refreshRecordingCache()
        } catch {
            recordingCacheErrorMessage = SettingsViewStateLoader.userFacingMessage(for: error)
        }
    }

    private func clearRecordingCache() {
        do {
            try recordingCache.clearCache()
            refreshRecordingCache()
        } catch {
            recordingCacheErrorMessage = SettingsViewStateLoader.userFacingMessage(for: error)
        }
    }

    private func refreshDiagnostics() {
        let diagnosticsState = SettingsViewStateLoader.loadDiagnosticsState(
            diagnostics: diagnostics
        )
        let runtimeLogState = SettingsViewStateLoader.loadRuntimeLogState(
            diagnostics: diagnostics
        )
        diagnosticReportSummary = diagnosticsState.summary
        diagnosticRuntimeLogSummary = runtimeLogState.summary
        diagnosticsErrorMessage = diagnosticsState.errorMessage
        diagnosticRuntimeLogErrorMessage = runtimeLogState.errorMessage
    }

    private func revealDiagnosticReportsDirectory() {
        diagnostics.revealInFinder(diagnosticReportSummary.directoryURL)
    }

    private func copyDiagnosticReportsDirectoryPath() {
        diagnostics.copyPath(diagnosticReportSummary.directoryURL)
    }

    private func revealDiagnosticReport(_ item: DiagnosticReportItem) {
        diagnostics.revealInFinder(item.fileURL)
    }

    private func copyDiagnosticReportPath(_ item: DiagnosticReportItem) {
        diagnostics.copyPath(item.fileURL)
    }

    private func revealRuntimeLogsDirectory() {
        diagnostics.revealInFinder(diagnosticRuntimeLogSummary.directoryURL)
    }

    private func copyRuntimeLogs() {
        let text = diagnosticRuntimeLogSummary.recentLines.joined(separator: "\n")
        guard !text.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportDiagnosticBundle() {
        do {
            let result = try diagnostics.exportDiagnosticBundle()
            diagnosticBundleResult = result
            diagnosticBundleErrorMessage = nil
            refreshDiagnostics()
            diagnostics.revealInFinder(result.bundleURL)
        } catch {
            diagnosticBundleResult = nil
            diagnosticBundleErrorMessage = SettingsViewStateLoader.userFacingMessage(for: error)
        }
    }

    private func applyRecordingCacheRetentionIfNeeded(
        oldSettings: AppSettings,
        newSettings: AppSettings
    ) {
        guard oldSettings.recordingCachePolicy != newSettings.recordingCachePolicy else {
            return
        }

        do {
            try recordingCache.applyRetentionPolicy(newSettings.recordingCachePolicy)
            refreshRecordingCache()
        } catch {
            recordingCacheErrorMessage = SettingsViewStateLoader.userFacingMessage(for: error)
        }
    }

}

#Preview {
    SettingsView(apiKeyStorage: PreviewAPIKeyStorage())
}

private final class PreviewAPIKeyStorage: APIKeyStorage {
    private var apiKey: String?

    func saveAPIKey(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
        apiKey
    }

    func deleteAPIKey() throws {
        apiKey = nil
    }
}
