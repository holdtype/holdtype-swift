import Foundation

enum DevVlogsReadiness: Equatable {
    case off
    case setupRequired
    case ready
    case degradedCameraUnavailable
    case degradedDestinationUnavailable

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .setupRequired:
            return "Setup required"
        case .ready:
            return "Ready"
        case .degradedCameraUnavailable:
            return "Degraded: camera unavailable"
        case .degradedDestinationUnavailable:
            return "Degraded: destination unavailable"
        }
    }
}

struct DevVlogsReadinessInput: Equatable {
    let isEnabled: Bool
    let preferredCamera: DevVlogsCamera?
    let cameraPermissionStatus: DevVlogsCameraPermissionStatus
    let availableCameras: [DevVlogsCamera]
    let applicationPolicy: DevVlogsApplicationPolicy
    let destination: DevVlogsDestinationStatus
}

enum DevVlogsReadinessReducer {
    static func reduce(_ input: DevVlogsReadinessInput) -> DevVlogsReadiness {
        guard input.isEnabled else {
            return .off
        }

        guard input.preferredCamera != nil,
              input.applicationPolicy.hasEffectiveEligibility,
              input.destination.isConfigured else {
            return .setupRequired
        }

        guard input.cameraPermissionStatus == .allowed,
              let preferredCamera = input.preferredCamera,
              input.availableCameras.contains(where: { $0.hasSameIdentity(as: preferredCamera) }) else {
            return .degradedCameraUnavailable
        }

        guard input.destination.isAvailable else {
            return .degradedDestinationUnavailable
        }

        return .ready
    }
}
