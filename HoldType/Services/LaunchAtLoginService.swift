//
//  LaunchAtLoginService.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable(String)

    var isEnabled: Bool {
        self == .enabled
    }

    var toggleValue: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unavailable:
            return false
        }
    }

    var behaviorStatusText: String {
        switch self {
        case .enabled:
            return "Start at Login: On"
        case .disabled:
            return "Start at Login: Off"
        case .requiresApproval:
            return "Start at Login: Needs Approval"
        case .unavailable:
            return "Start at Login: Unavailable"
        }
    }

    var behaviorDescription: String {
        switch self {
        case .enabled:
            return "HoldType is approved to start when you log in."
        case .disabled:
            return "Keeps Right Command dictation available after restart."
        case .requiresApproval:
            return "HoldType asked macOS to start it at login, but macOS still needs approval in Login Items."
        case .unavailable(let message):
            return message
        }
    }

    var behaviorSystemImage: String {
        switch self {
        case .enabled:
            return "checkmark.circle"
        case .disabled:
            return "power"
        case .requiresApproval:
            return "exclamationmark.triangle"
        case .unavailable:
            return "xmark.octagon"
        }
    }

    var loginItemsActionTitle: String? {
        switch self {
        case .requiresApproval:
            return "Approve in Login Items"
        case .enabled, .disabled, .unavailable:
            return nil
        }
    }

}

enum LaunchAtLoginAuthorizationStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

protocol LaunchAtLoginClient {
    func currentStatus() -> LaunchAtLoginAuthorizationStatus
    func register() throws
    func unregister() throws
    func openLoginItemsSettings() -> Bool
}

struct SystemLaunchAtLoginClient: LaunchAtLoginClient {
    func currentStatus() -> LaunchAtLoginAuthorizationStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openLoginItemsSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}

protocol LaunchAtLoginServicing {
    func currentStatus() -> LaunchAtLoginStatus
    func setEnabled(_ isEnabled: Bool) -> LaunchAtLoginStatus
    func openLoginItemsSettings() -> Bool
}

struct LaunchAtLoginService: LaunchAtLoginServicing {
    private let client: any LaunchAtLoginClient

    init(client: any LaunchAtLoginClient = SystemLaunchAtLoginClient()) {
        self.client = client
    }

    func currentStatus() -> LaunchAtLoginStatus {
        status(from: client.currentStatus())
    }

    func setEnabled(_ isEnabled: Bool) -> LaunchAtLoginStatus {
        do {
            if isEnabled {
                try client.register()
            } else {
                try client.unregister()
            }

            return currentStatus()
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    func openLoginItemsSettings() -> Bool {
        client.openLoginItemsSettings()
    }

    private func status(from authorizationStatus: LaunchAtLoginAuthorizationStatus) -> LaunchAtLoginStatus {
        switch authorizationStatus {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable("macOS could not find the HoldType Login Item registration.")
        }
    }
}
