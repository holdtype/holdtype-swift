//
//  SettingsWindowPresenter.swift
//  HoldType
//
//  Created by Codex on 7/5/26.
//

import AppKit
import Combine
import SwiftUI

final class SettingsWindowNavigation: ObservableObject {
    @Published var selectedItem: SettingsNavigationItem? = .permissions
    @Published private(set) var focusRefreshToken = 0

    func focus(_ item: SettingsNavigationItem) {
        selectedItem = item
    }

    func requestFocusedWindowRefresh() {
        focusRefreshToken += 1
    }
}

enum SettingsWindowTitle {
    static func title(for item: SettingsNavigationItem?) -> String {
        HoldTypeWindowTitle.titled((item ?? .permissions).title)
    }
}

enum SettingsWindowFocusBehavior {
    static func shouldClearInitialTextEntryFocus(for item: SettingsNavigationItem?) -> Bool {
        item == .translation
    }
}

@MainActor
final class SettingsWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?
    private let navigation: SettingsWindowNavigation
    private var selectedItemCancellable: AnyCancellable?

    private override init() {
        navigation = SettingsWindowNavigation()
        super.init()
        bindWindowTitleToSelection()
    }

    init(navigation: SettingsWindowNavigation) {
        self.navigation = navigation
        super.init()
        bindWindowTitleToSelection()
    }

    func showAfterMenuDismissal(focusing item: SettingsNavigationItem? = nil) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            show(focusing: item)
        }
    }

    func showAfterSystemPermissionPrompt(focusing item: SettingsNavigationItem? = nil) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            show(focusing: item)
        }
    }

    func show(focusing item: SettingsNavigationItem? = nil) {
        if let item {
            navigation.focus(item)
        }

        AppWindowActivation.showRegularApp()
        let settingsWindow = window ?? makeWindow()
        window = settingsWindow
        updateWindowTitle(for: navigation.selectedItem)
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.orderFrontRegardless()
        navigation.requestFocusedWindowRefresh()
        clearInitialTextEntryFocusIfNeeded(in: settingsWindow, focusing: item)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        navigation.requestFocusedWindowRefresh()
    }

    func windowWillClose(_ notification: Notification) {
        AppWindowActivation.restoreAccessoryIfNoVisibleAppWindows(
            excluding: notification.object as? NSWindow
        )
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                navigation: navigation,
                hotkeyStatusProvider: {
                    DictationRuntime.shared.refreshHotkeyRegistrationStatus()
                    return DictationRuntime.shared.hotkeyRegistrationStatus
                },
                fixesHotkeyStatusProvider: {
                    FixesRuntime.shared.hotkeyRegistrationStatus
                }
            )
        )
        let settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow.title = SettingsWindowTitle.title(for: navigation.selectedItem)
        settingsWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        settingsWindow.minSize = NSSize(width: 720, height: 480)
        settingsWindow.setContentSize(NSSize(width: 760, height: 520))
        settingsWindow.center()
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.delegate = self
        return settingsWindow
    }

    private func bindWindowTitleToSelection() {
        selectedItemCancellable = navigation.$selectedItem.sink { [weak self] item in
            Task { @MainActor in
                self?.updateWindowTitle(for: item)
            }
        }
    }

    private func updateWindowTitle(for item: SettingsNavigationItem?) {
        window?.title = SettingsWindowTitle.title(for: item)
    }

    private func clearInitialTextEntryFocusIfNeeded(
        in settingsWindow: NSWindow,
        focusing item: SettingsNavigationItem?
    ) {
        guard SettingsWindowFocusBehavior.shouldClearInitialTextEntryFocus(for: item) else {
            return
        }

        Task { @MainActor [weak settingsWindow] in
            await Task.yield()

            guard let settingsWindow else {
                return
            }

            _ = settingsWindow.endEditing(for: nil)
            _ = settingsWindow.makeFirstResponder(nil)
        }
    }
}

extension SettingsWindowPresenter: SetupSettingsPresenting {}
