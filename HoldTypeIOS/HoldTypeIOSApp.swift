//
//  HoldTypeIOSApp.swift
//  HoldType-iOS
//
//  Created by Codex on 6/21/26.
//

@_spi(HoldTypeIOSCore) import HoldTypePersistence
import SwiftUI

@main
struct HoldTypeIOSApp: App {
    let composition: IOSContainingAppComposition

    init() {
        #if DEBUG
        if IOSUIQualificationRoute.current != nil {
            composition = IOSContainingAppComposition(
                scheduleProviderStartupMaintenance: {},
                recoverContainingAppLifecycle: { _ in .complete }
            )
            return
        }
        #endif
        IOSRuntimeDiagnosticsStore.app.record(.appLaunched)
        IOSMetricKitDiagnosticCollector.shared.start()
        composition = IOSContainingAppComposition()
    }

    init(scheduleProviderStartupMaintenance: @MainActor () -> Void) {
        self.init(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            recoverContainingAppLifecycle: { _ in .complete }
        )
    }

    init(
        scheduleProviderStartupMaintenance: @MainActor () -> Void,
        recoverContainingAppLifecycle:
            @escaping IOSContainingAppLifecycleScheduler.Recovery
    ) {
        composition = IOSContainingAppComposition(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            recoverContainingAppLifecycle:
                recoverContainingAppLifecycle
        )
    }

    init(composition: IOSContainingAppComposition) {
        self.composition = composition
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let qualificationRoute = IOSUIQualificationRoute.current {
                IOSUIQualificationRootView(route: qualificationRoute)
            } else {
                IOSContainingAppSceneHost(composition: composition)
            }
            #else
            IOSContainingAppSceneHost(composition: composition)
            #endif
        }
    }
}

struct HoldTypeIOSRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    let settingsStateOwner: IOSAppSettingsStateOwner?
    let libraryStateOwner: IOSLibraryStateOwner?
    let openAISettingsStateOwner:
        IOSOpenAICredentialSettingsStateOwner?
    let usageEstimateStateOwner: IOSUsageEstimateStateOwner?
    let acceptedTextHistoryStateOwner:
        IOSAcceptedTextHistoryStateOwner?
    let foregroundVoiceRuntimeAvailable: Bool
    let historyPlaybackActions: IOSHistoryPlaybackActions?
    let pendingRecordingHistoryStateOwner:
        IOSPendingRecordingHistoryStateOwner?
    let recordingCacheLifecycleActions:
        IOSRecordingCacheLifecycleActions?
    let layout: IOSContainingAppShellLayout
    let keyboardHandoffPresentationOwner:
        IOSKeyboardHandoffPresentationOwner?

    init(
        settingsStateOwner: IOSAppSettingsStateOwner?,
        libraryStateOwner: IOSLibraryStateOwner?,
        openAISettingsStateOwner:
            IOSOpenAICredentialSettingsStateOwner?,
        usageEstimateStateOwner: IOSUsageEstimateStateOwner?,
        acceptedTextHistoryStateOwner:
            IOSAcceptedTextHistoryStateOwner?,
        foregroundVoiceRuntimeAvailable: Bool = false,
        historyPlaybackActions: IOSHistoryPlaybackActions? = nil,
        pendingRecordingHistoryStateOwner:
            IOSPendingRecordingHistoryStateOwner? = nil,
        recordingCacheLifecycleActions:
            IOSRecordingCacheLifecycleActions? = nil,
        layout: IOSContainingAppShellLayout = .current,
        keyboardHandoffPresentationOwner:
            IOSKeyboardHandoffPresentationOwner? = nil
    ) {
        self.settingsStateOwner = settingsStateOwner
        self.libraryStateOwner = libraryStateOwner
        self.openAISettingsStateOwner = openAISettingsStateOwner
        self.usageEstimateStateOwner = usageEstimateStateOwner
        self.acceptedTextHistoryStateOwner =
            acceptedTextHistoryStateOwner
        self.foregroundVoiceRuntimeAvailable =
            foregroundVoiceRuntimeAvailable
        self.historyPlaybackActions = historyPlaybackActions
        self.pendingRecordingHistoryStateOwner =
            pendingRecordingHistoryStateOwner
        self.recordingCacheLifecycleActions =
            recordingCacheLifecycleActions
        self.layout = layout
        self.keyboardHandoffPresentationOwner =
            keyboardHandoffPresentationOwner
    }

    var presentation: IOSContainingAppRootPresentation {
        .resolve(
            hasSettingsStateOwner:
                settingsStateOwner != nil,
            hasLibraryStateOwner:
                libraryStateOwner != nil,
            hasOpenAISettingsStateOwner:
                openAISettingsStateOwner != nil,
            hasUsageEstimateStateOwner:
                usageEstimateStateOwner != nil,
            hasAcceptedTextHistoryStateOwner:
                acceptedTextHistoryStateOwner != nil
        )
    }

    var body: some View {
        Group {
            if let settingsStateOwner,
               let libraryStateOwner,
               let openAISettingsStateOwner,
               let usageEstimateStateOwner,
               let acceptedTextHistoryStateOwner {
                IOSContainingAppShell(
                    foregroundVoiceRuntimeAvailable:
                        foregroundVoiceRuntimeAvailable,
                    historyPlaybackActions: historyPlaybackActions,
                    pendingRecordingHistoryStateOwner:
                        pendingRecordingHistoryStateOwner,
                    recordingCacheLifecycleActions:
                        recordingCacheLifecycleActions,
                    layout: layout,
                    keyboardHandoffPresentationOwner:
                        keyboardHandoffPresentationOwner
                )
                    .environment(settingsStateOwner)
                    .environment(libraryStateOwner)
                    .environment(openAISettingsStateOwner)
                    .environment(usageEstimateStateOwner)
                    .environment(acceptedTextHistoryStateOwner)
            } else {
                IOSContainingAppStorageUnavailableView()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            let diagnosticPhase: IOSDiagnosticScenePhase = switch phase {
            case .active:
                .active
            case .inactive:
                .inactive
            case .background:
                .background
            @unknown default:
                .inactive
            }
            IOSRuntimeDiagnosticsStore.app.record(
                .scenePhase(diagnosticPhase)
            )
        }
    }
}

#Preview("Storage unavailable") {
    IOSContainingAppStorageUnavailableView()
}
