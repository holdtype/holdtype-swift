//
//  HoldTypeIOSApp.swift
//  HoldType-iOS
//
//  Created by Codex on 6/21/26.
//

import HoldTypePersistence
import SwiftUI

@main
struct HoldTypeIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let composition: IOSContainingAppComposition

    init() {
        composition = IOSContainingAppComposition()
    }

    init(scheduleProviderStartupMaintenance: @MainActor () -> Void) {
        self.init(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            scheduleRetryScratchStartupMaintenance: {},
            recoverContainingAppLifecycle: { _ in .complete }
        )
    }

    init(
        scheduleProviderStartupMaintenance: @MainActor () -> Void,
        scheduleRetryScratchStartupMaintenance: @MainActor () -> Void = {},
        recoverContainingAppLifecycle:
            @escaping IOSContainingAppLifecycleScheduler.Recovery
    ) {
        composition = IOSContainingAppComposition(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            scheduleRetryScratchStartupMaintenance:
                scheduleRetryScratchStartupMaintenance,
            recoverContainingAppLifecycle:
                recoverContainingAppLifecycle
        )
    }

    init(composition: IOSContainingAppComposition) {
        self.composition = composition
    }

    var body: some Scene {
        WindowGroup {
            HoldTypeIOSRootView(composition: composition)
        }
        .onChange(of: scenePhase, initial: true) { oldPhase, newPhase in
            composition.lifecycleScheduler.observeScenePhase(
                newPhase,
                isInitialObservation: oldPhase == newPhase
            )
        }
    }
}

struct HoldTypeIOSRootView: View {
    let composition: IOSContainingAppComposition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HoldTypeSetupStatusView(surface: .iOSContainingApp)
                    KeyboardBridgeProbeView()
                }
                .padding(24)
            }
            .navigationTitle("HoldType")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    HoldTypeIOSRootView(
        composition: IOSContainingAppComposition(
            scheduleProviderStartupMaintenance: {},
            scheduleRetryScratchStartupMaintenance: {},
            recoverContainingAppLifecycle: { _ in
                .pendingLocalRecovery
            }
        )
    )
}
