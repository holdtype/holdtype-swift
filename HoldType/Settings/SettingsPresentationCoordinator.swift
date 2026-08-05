//
//  SettingsPresentationCoordinator.swift
//  HoldType
//

import Combine
import SwiftUI

final class SettingsNavigation: ObservableObject {
    @Published var selectedItem: SettingsNavigationItem? = .permissions
    @Published private(set) var focusRefreshToken = 0

    func focus(_ item: SettingsNavigationItem) {
        selectedItem = item
    }

    func requestFocusedSettingsRefresh() {
        focusRefreshToken += 1
    }

    func requestFocusedWindowRefresh() {
        requestFocusedSettingsRefresh()
    }
}

typealias SettingsWindowNavigation = SettingsNavigation

enum SettingsWindowTitle {
    static func title(for item: SettingsNavigationItem?) -> String {
        HoldTypeWindowTitle.titled((item ?? .permissions).title)
    }
}

@MainActor
final class SettingsPresentationCoordinator: SetupSettingsPresenting {
    static let shared = SettingsPresentationCoordinator()

    let navigation: SettingsNavigation
    private var openSettingsAction: (() -> Void)?
    private var hasPendingPresentation = false

    private init() {
        navigation = SettingsNavigation()
    }

    init(navigation: SettingsNavigation) {
        self.navigation = navigation
    }

    func install(openSettingsAction: @escaping () -> Void) {
        self.openSettingsAction = openSettingsAction

        guard hasPendingPresentation else {
            return
        }

        hasPendingPresentation = false
        openSettingsAction()
    }

    func showAfterMenuDismissal(focusing item: SettingsNavigationItem? = nil) {
        show(after: .milliseconds(100), focusing: item)
    }

    func showAfterSystemPermissionPrompt(focusing item: SettingsNavigationItem? = nil) {
        show(after: .milliseconds(300), focusing: item)
    }

    func show(focusing item: SettingsNavigationItem? = nil) {
        if let item {
            navigation.focus(item)
        }

        navigation.requestFocusedSettingsRefresh()

        guard let openSettingsAction else {
            hasPendingPresentation = true
            return
        }

        openSettingsAction()
    }

    private func show(after delay: Duration, focusing item: SettingsNavigationItem?) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            show(focusing: item)
        }
    }
}

typealias SettingsWindowPresenter = SettingsPresentationCoordinator

@MainActor
enum SettingsSceneRequest {
    static let menuDismissalDelay: Duration = .milliseconds(100)

    static func openAfterMenuDismissal(
        focusing item: SettingsNavigationItem? = nil,
        dismissMenu: () -> Void,
        openSettings: @escaping @MainActor () -> Void
    ) {
        if let item {
            SettingsPresentationCoordinator.shared.navigation.focus(item)
        }

        dismissMenu()

        Task { @MainActor in
            try? await Task.sleep(for: menuDismissalDelay)
            SettingsPresentationCoordinator.shared.navigation.requestFocusedSettingsRefresh()
            openSettings()
        }
    }
}
