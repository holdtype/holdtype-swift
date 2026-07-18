//
//  AccessibilityPermissionService.swift
//  HoldType
//
//  Created by Codex on 7/18/26.
//

import AppKit
import ApplicationServices

enum AccessibilityPermissionStatus: Equatable {
    case trusted
    case notTrusted

    var canInsertTextIntoActiveApp: Bool {
        self == .trusted
    }

    var settingsDescription: String {
        switch self {
        case .trusted:
            return "Automatic insertion and Paste Last Result can insert text into the active app."
        case .notTrusted:
            return "Automatic insertion and Paste Last Result need Accessibility permission. Transcription can still save recovery text."
        }
    }

    var settingsActionTitle: String? {
        canInsertTextIntoActiveApp ? nil : "Request Accessibility Access"
    }

    var settingsInstruction: String? {
        switch self {
        case .trusted:
            return nil
        case .notTrusted:
            return "Enable HoldType in System Settings. If it is not listed, click + and choose the running HoldType app. If HoldType is listed but this still says Not Allowed after you turn it on, remove the old HoldType row with - and request access again so macOS adds the current app."
        }
    }

    var settingsStatusText: String {
        switch self {
        case .trusted:
            return "Accessibility: Allowed"
        case .notTrusted:
            return "Accessibility: Not Allowed"
        }
    }

    var settingsSystemImage: String {
        canInsertTextIntoActiveApp ? "checkmark.circle" : "exclamationmark.triangle"
    }

}

protocol AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
    func openAccessibilitySettings() -> Bool
}

struct AXAccessibilityPermissionClient: AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        guard promptIfNeeded else {
            return AXIsProcessTrusted()
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}

struct AccessibilityPermissionService {
    private let client: AccessibilityPermissionClient

    init(client: AccessibilityPermissionClient = AXAccessibilityPermissionClient()) {
        self.client = client
    }

    func currentStatus() -> AccessibilityPermissionStatus {
        client.isProcessTrusted(promptIfNeeded: false) ? .trusted : .notTrusted
    }

    func requestPermission() -> AccessibilityPermissionStatus {
        client.isProcessTrusted(promptIfNeeded: true) ? .trusted : currentStatus()
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        client.openAccessibilitySettings()
    }
}
