//
//  AppWindowActivation.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit

enum AppWindowActivation {
    @MainActor
    static func showRegularApp() {
        NSApplication.shared.setActivationPolicy(.regular)
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
