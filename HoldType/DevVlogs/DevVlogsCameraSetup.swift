import AppKit
import AVFoundation
import Combine
import Foundation

enum DevVlogsCameraPermissionStatus: Equatable {
    case allowed
    case denied
    case notDetermined
    case unavailable

    var title: String {
        switch self {
        case .allowed:
            return "Camera access allowed"
        case .denied:
            return "Camera access not allowed"
        case .notDetermined:
            return "Camera access needed"
        case .unavailable:
            return "Camera access unavailable"
        }
    }

    var description: String {
        switch self {
        case .allowed:
            return "Choose the camera Dev Vlogs should use when capture is available."
        case .denied:
            return "Allow camera access in System Settings to choose a camera for Dev Vlogs."
        case .notDetermined:
            return "Request camera access to choose a camera for Dev Vlogs."
        case .unavailable:
            return "Camera access is unavailable on this Mac right now."
        }
    }

    var systemImage: String {
        switch self {
        case .allowed:
            return "checkmark.circle"
        case .denied, .unavailable:
            return "xmark.octagon"
        case .notDetermined:
            return "exclamationmark.triangle"
        }
    }
}

enum DevVlogsCameraAuthorizationStatus: Equatable {
    case allowed
    case denied
    case notDetermined
}

struct DevVlogsCamera: Identifiable, Equatable {
    let id: String
    let label: String

    func hasSameIdentity(as other: DevVlogsCamera) -> Bool {
        id == other.id
    }
}

struct DevVlogsCameraDiscoveryCandidate: Equatable {
    let id: String
    let label: String
    let isConnected: Bool
    let isSuspended: Bool
}

enum DevVlogsCameraDiscovery {
    nonisolated static var deviceTypes: [AVCaptureDevice.DeviceType] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external
        ]

        if #available(macOS 14.0, *) {
            deviceTypes.append(.continuityCamera)
        }

        return deviceTypes
    }

    static func availableCameras(
        from candidates: [DevVlogsCameraDiscoveryCandidate]
    ) -> [DevVlogsCamera] {
        candidates
            .filter { $0.isConnected && !$0.isSuspended }
            .map { DevVlogsCamera(id: $0.id, label: $0.label) }
            .sorted {
                $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                    || ($0.label == $1.label && $0.id < $1.id)
            }
    }
}

protocol DevVlogsCameraSetupClient {
    var cameraDeviceChangeNotifications: [Notification.Name] { get }

    func authorizationStatus() -> DevVlogsCameraAuthorizationStatus
    func availableCameras() throws -> [DevVlogsCamera]
    func requestAccess(completion: @escaping (Bool) -> Void)
    func openCameraSettings() -> Bool
}

struct AVFoundationDevVlogsCameraSetupClient: DevVlogsCameraSetupClient {
    let cameraDeviceChangeNotifications = [
        AVCaptureDevice.wasConnectedNotification,
        AVCaptureDevice.wasDisconnectedNotification
    ]

    func authorizationStatus() -> DevVlogsCameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
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

    func availableCameras() throws -> [DevVlogsCamera] {
        DevVlogsCameraDiscovery.availableCameras(
            from: AVCaptureDevice.DiscoverySession(
                deviceTypes: DevVlogsCameraDiscovery.deviceTypes,
                mediaType: .video,
                position: .unspecified
            ).devices.map {
                DevVlogsCameraDiscoveryCandidate(
                    id: $0.uniqueID,
                    label: $0.localizedName,
                    isConnected: $0.isConnected,
                    isSuspended: $0.isSuspended
                )
            }
        )
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }

    func openCameraSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}

struct DevVlogsCameraSetupPreviewClient: DevVlogsCameraSetupClient {
    private enum PreviewError: Error {
        case discoveryFailed
    }

    let status: DevVlogsCameraAuthorizationStatus
    let cameras: [DevVlogsCamera]
    let discoveryFails: Bool

    let cameraDeviceChangeNotifications: [Notification.Name] = []

    init(
        status: DevVlogsCameraAuthorizationStatus,
        cameras: [DevVlogsCamera] = [DevVlogsCamera(id: "built-in", label: "Built-in Camera")],
        discoveryFails: Bool = false
    ) {
        self.status = status
        self.cameras = cameras
        self.discoveryFails = discoveryFails
    }

    func authorizationStatus() -> DevVlogsCameraAuthorizationStatus {
        status
    }

    func availableCameras() throws -> [DevVlogsCamera] {
        if discoveryFails {
            throw PreviewError.discoveryFailed
        }

        return cameras
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        completion(status == .allowed)
    }

    func openCameraSettings() -> Bool {
        false
    }
}

@MainActor
final class DevVlogsCameraSetupStore: ObservableObject {
    @Published private(set) var permissionStatus: DevVlogsCameraPermissionStatus = .unavailable
    @Published private(set) var cameras: [DevVlogsCamera] = []

    private let client: any DevVlogsCameraSetupClient

    init() {
        client = AVFoundationDevVlogsCameraSetupClient()
    }

    init(client: any DevVlogsCameraSetupClient) {
        self.client = client
    }

    func refresh() {
        permissionStatus = status(for: client.authorizationStatus())

        do {
            cameras = try client.availableCameras()
        } catch {
            cameras = []
            permissionStatus = .unavailable
        }
    }

    func cameraDeviceChangePublisher(
        notificationCenter: NotificationCenter = .default
    ) -> AnyPublisher<Void, Never> {
        Publishers.MergeMany(
            client.cameraDeviceChangeNotifications.map { notificationName in
                notificationCenter.publisher(for: notificationName)
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
        )
        .eraseToAnyPublisher()
    }

    func refreshAfterCameraDeviceChange() {
        refresh()
    }

    func refreshAfterApplicationActivation() {
        refresh()
    }

    func requestAccessIfNeeded(isEnabled: Bool) {
        guard isEnabled, permissionStatus == .notDetermined else {
            return
        }

        client.requestAccess { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    @discardableResult
    func openCameraSettingsIfNeeded(isEnabled: Bool) -> Bool {
        guard isEnabled, permissionStatus == .denied else {
            return false
        }

        return client.openCameraSettings()
    }

    private func status(
        for authorizationStatus: DevVlogsCameraAuthorizationStatus
    ) -> DevVlogsCameraPermissionStatus {
        switch authorizationStatus {
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        }
    }
}
