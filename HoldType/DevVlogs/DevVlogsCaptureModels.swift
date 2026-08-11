import Foundation

enum DevVlogsCaptureSkipReason: String, Codable, Equatable {
    case disabled
    case triggerApplicationUnknown
    case triggerApplicationIneligible
    case captureAlreadyActive
    case cameraPermissionUnavailable
    case preferredCameraUnavailable
    case destinationUnavailable
    case dictationDidNotComplete

    var message: String {
        switch self {
        case .disabled:
            return "Dev Vlogs is off."
        case .triggerApplicationUnknown:
            return "The trigger application could not be identified."
        case .triggerApplicationIneligible:
            return "The trigger application is not included in Dev Vlogs."
        case .captureAlreadyActive:
            return "Another Dev Vlogs capture is already active."
        case .cameraPermissionUnavailable:
            return "Camera access is unavailable."
        case .preferredCameraUnavailable:
            return "The preferred camera is unavailable or busy."
        case .destinationUnavailable:
            return "The Dev Vlogs destination is unavailable."
        case .dictationDidNotComplete:
            return "The dictation did not produce finalized audio for this clip."
        }
    }
}

enum DevVlogsCaptureState: Equatable {
    case idle
    case preparing(attemptID: UUID)
    case capturing(attemptID: UUID)
    case finalizing(attemptID: UUID)
    case saved(clipID: UUID)
    case skipped(attemptID: UUID, reason: DevVlogsCaptureSkipReason)
    case failed(attemptID: UUID, message: String)

    var title: String {
        switch self {
        case .idle:
            return "No vlog attempt yet"
        case .preparing:
            return "Preparing"
        case .capturing:
            return "Capturing"
        case .finalizing:
            return "Finalizing"
        case .saved:
            return "Saved"
        case .skipped:
            return "Skipped"
        case .failed:
            return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "An eligible dictation can save one local camera clip."
        case .preparing:
            return "Checking the frozen camera and destination."
        case .capturing:
            return "Camera video is being recorded with this dictation."
        case .finalizing:
            return "Adding the finalized dictation audio without re-encoding video."
        case .saved:
            return "One playable local clip was saved."
        case .skipped(_, let reason):
            return reason.message
        case .failed(_, let message):
            return message
        }
    }
}

struct DevVlogsTriggerApplication: Equatable {
    let bundleIdentifier: String
    let displayName: String
}

struct DevVlogsCaptureSnapshot: Equatable {
    let attemptID: UUID
    let startedAt: Date
    let triggerApplication: DevVlogsTriggerApplication
    let preferredCamera: DevVlogsCamera
}

struct DevVlogsRealizedVideoFormat: Codable, Equatable {
    let width: Int
    let height: Int
    let nominalFrameRate: Double
    let codec: String
}

struct DevVlogsCameraCaptureResult: Equatable {
    let fileURL: URL
    let duration: TimeInterval
    let startedAtUptime: TimeInterval
}

struct DevVlogsFinalizedMedia: Equatable {
    let fileURL: URL
    let duration: TimeInterval
    let byteCount: Int64
    let realizedVideoFormat: DevVlogsRealizedVideoFormat
}

struct DevVlogsPublishedClip: Equatable {
    let id: UUID
    let fileURL: URL
}
