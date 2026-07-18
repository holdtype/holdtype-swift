//
//  MicrophonePermissionService.swift
//  HoldType
//
//  Created by Codex on 7/18/26.
//

import AppKit
import AVFoundation

enum MicrophonePermissionStatus: Equatable {
    case allowed
    case denied
    case notDetermined
    case unavailable

    var canRecord: Bool {
        self == .allowed
    }

    var settingsStatusText: String {
        switch self {
        case .allowed:
            return "Microphone: Allowed"
        case .denied:
            return "Microphone: Not Allowed"
        case .notDetermined:
            return "Microphone: Permission Needed"
        case .unavailable:
            return "Microphone: Unavailable"
        }
    }

    var settingsDescription: String {
        switch self {
        case .allowed:
            return "Recording can start after you choose a dictation action."
        case .denied:
            return "Recording is blocked until microphone access is allowed in System Settings."
        case .notDetermined:
            return "Request microphone access before starting dictation."
        case .unavailable:
            return "Recording is blocked because no microphone input is available."
        }
    }

    var settingsSystemImage: String {
        switch self {
        case .allowed:
            return "checkmark.circle"
        case .denied, .unavailable:
            return "xmark.octagon"
        case .notDetermined:
            return "exclamationmark.triangle"
        }
    }

    var settingsActionTitle: String? {
        switch self {
        case .allowed, .unavailable:
            return nil
        case .denied:
            return "Open Microphone Settings"
        case .notDetermined:
            return "Request Microphone Access"
        }
    }
}

enum MicrophoneAuthorizationStatus: Equatable {
    case allowed
    case denied
    case notDetermined
}

protocol MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool { get }

    func authorizationStatus() -> MicrophoneAuthorizationStatus
    func requestAccess(completion: @escaping (Bool) -> Void)
}

struct AVFoundationMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool {
        AVCaptureDevice.default(for: .audio) != nil
    }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .allowed
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}

struct MicrophonePermissionService {
    private let client: MicrophonePermissionClient

    init(client: MicrophonePermissionClient = AVFoundationMicrophonePermissionClient()) {
        self.client = client
    }

    func currentStatus() -> MicrophonePermissionStatus {
        guard client.hasAvailableAudioInput else {
            return .unavailable
        }

        return status(for: client.authorizationStatus())
    }

    func requestPermission(completion: @escaping (MicrophonePermissionStatus) -> Void) {
        guard client.hasAvailableAudioInput else {
            completion(.unavailable)
            return
        }

        switch client.authorizationStatus() {
        case .allowed:
            completion(.allowed)
        case .denied:
            completion(.denied)
        case .notDetermined:
            client.requestAccess { isAllowed in
                completion(isAllowed ? .allowed : .denied)
            }
        }
    }

    private func status(for authorizationStatus: MicrophoneAuthorizationStatus) -> MicrophonePermissionStatus {
        switch authorizationStatus {
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        }
    }

    @discardableResult
    func openMicrophoneSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}
