//
//  AppWindowActivation.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit

enum AppWindowActivation {
    static func configuredPolicy(showInDock: Bool) -> NSApplication.ActivationPolicy {
        showInDock ? .regular : .accessory
    }

    /// Applies the user's persistent Dock preference. AppKit remains isolated
    /// here solely because SwiftUI does not expose process activation policy.
    @discardableResult
    @MainActor
    static func applyConfiguredPolicy() -> Bool {
        applyConfiguredPolicy(showInDock: AppSettingsStore().load().showInDock)
    }

    @discardableResult
    @MainActor
    static func applyConfiguredPolicy(showInDock: Bool) -> Bool {
        applyConfiguredPolicy(
            showInDock: showInDock,
            setActivationPolicy: { NSApplication.shared.setActivationPolicy($0) }
        )
    }

    @MainActor
    static func applyConfiguredPolicyIfChanged(
        from previousShowInDock: Bool,
        to showInDock: Bool
    ) {
        guard previousShowInDock != showInDock else {
            return
        }
        applyConfiguredPolicy(showInDock: showInDock)
    }

    @discardableResult
    @MainActor
    static func applyConfiguredPolicy(
        showInDock: Bool,
        setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool
    ) -> Bool {
        setActivationPolicy(configuredPolicy(showInDock: showInDock))
    }

    /// Activates the menu-bar app for an explicit request to present one of
    /// its ordinary SwiftUI windows without overriding the Dock preference.
    @MainActor
    static func activateForWindowPresentation() {
        activateForWindowPresentation(
            showInDock: AppSettingsStore().load().showInDock,
            setActivationPolicy: { NSApplication.shared.setActivationPolicy($0) },
            activate: { NSApplication.shared.activate(ignoringOtherApps: true) }
        )
    }

    @MainActor
    static func activateForWindowPresentation(
        showInDock: Bool,
        setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool,
        activate: () -> Void
    ) {
        _ = applyConfiguredPolicy(
            showInDock: showInDock,
            setActivationPolicy: setActivationPolicy
        )
        activate()
    }

    @MainActor
    static func restoreConfiguredPolicyIfNoVisibleAppWindows(excluding excludedWindow: NSWindow?) {
        let hasVisibleWindow = NSApplication.shared.windows.contains { window in
            guard window !== excludedWindow else {
                return false
            }

            return window.isVisible
                && !window.isMiniaturized
                && window.canBecomeKey
        }

        if !hasVisibleWindow {
            applyConfiguredPolicy()
        }
    }
}
