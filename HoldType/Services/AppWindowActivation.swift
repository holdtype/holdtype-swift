//
//  AppWindowActivation.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit

enum AppWindowActivation {
    /// Activates the menu-bar app only for an explicit request to present one
    /// of its ordinary SwiftUI windows. AppKit is used here solely for the
    /// macOS process activation policy; it does not host or render any UI.
    @MainActor
    static func showRegularApp() {
        NSApplication.shared.setActivationPolicy(.regular)
        // The menu action is an explicit user request to foreground this
        // window. Cooperative activation is not sufficient for an accessory
        // app while another application owns focus.
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func restoreAccessoryIfNoVisibleAppWindows(excluding excludedWindow: NSWindow?) {
        let hasVisibleWindow = NSApplication.shared.windows.contains { window in
            guard window !== excludedWindow else {
                return false
            }

            return window.isVisible
                && !window.isMiniaturized
                && window.canBecomeKey
        }

        if !hasVisibleWindow {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
