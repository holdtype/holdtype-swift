#if DEBUG
import Foundation

enum DevVlogsPhase0BResult: String, Codable, Equatable {
    case started
    case ready
    case failed
    case cancelled
    case timedOut = "timed_out"
    case notAvailable = "not_available"
}

enum DevVlogsPhase0BDeviceClass: String, Codable, Equatable {
    case builtIn = "built_in"
    case external
    case continuity
    case unknown
}

enum DevVlogsPhase0BFailureCategory: String, Codable, Equatable, CaseIterable {
    case invalidConfiguration = "invalid_configuration"
    case audioStart = "audio_start"
    case cameraPermissionRequired = "camera_permission_required"
    case cameraPermissionDenied = "camera_permission_denied"
    case cameraSelectionDisconnected = "camera_selection_disconnected"
    case cameraSelectionBusy = "camera_selection_busy"
    case cameraConfigurationPreset = "camera_configuration_preset"
    case cameraConfigurationVideoInput = "camera_configuration_video_input"
    case cameraConfigurationMovieOutput = "camera_configuration_movie_output"
    case cameraConfigurationSampleOutput = "camera_configuration_sample_output"
    case cameraStartTimedOut = "camera_start_timed_out"
    case cameraFirstFrameUnavailable = "camera_first_frame_unavailable"
    case cameraRecordingFailed = "camera_recording_failed"
    case cameraInterruptionDisconnected = "camera_interruption_disconnected"
    case cameraSessionRuntimeFailure = "camera_session_runtime_failure"
    case cameraSessionNotCapturing = "camera_session_not_capturing"
    case cameraUnknown = "camera_unknown"
    case captureStop = "capture_stop"
    case finalization
    case probe
    case eventLog = "event_log"
    case alreadyRun = "already_run"
}

enum DevVlogsPhase0BHarnessFailure: Error, Equatable {
    case invalidConfiguration, audioStart
    case cameraStart(DevVlogsPhase0BFailureCategory)
    case captureStop, finalization, probe, eventLog, alreadyRun

    var category: DevVlogsPhase0BFailureCategory {
        switch self {
        case .invalidConfiguration: .invalidConfiguration
        case .audioStart: .audioStart
        case .cameraStart(let category): category
        case .captureStop: .captureStop
        case .finalization: .finalization
        case .probe: .probe
        case .eventLog: .eventLog
        case .alreadyRun: .alreadyRun
        }
    }
}

enum DevVlogsPhase0BOperatorSummary {
    static func line(for outcome: DevVlogsPhase0BHarnessOutcome) -> String {
        switch outcome {
        case .ready:
            "dev_vlogs_phase_0b result=ready"
        case .failed(let failure):
            "dev_vlogs_phase_0b result=failed category=\(failure.category.rawValue)"
        }
    }
}

extension DevVlogsPhase0BCameraCaptureError {
    var redactedCategory: DevVlogsPhase0BFailureCategory {
        switch self {
        case .permissionRequired: .cameraPermissionRequired
        case .permissionDenied: .cameraPermissionDenied
        case .preferredDeviceDisconnected: .cameraSelectionDisconnected
        case .preferredDeviceBusy: .cameraSelectionBusy
        case .unsupportedCandidatePreset: .cameraConfigurationPreset
        case .videoInputUnavailable: .cameraConfigurationVideoInput
        case .movieOutputUnavailable: .cameraConfigurationMovieOutput
        case .sampleOutputUnavailable: .cameraConfigurationSampleOutput
        case .setupTimedOut: .cameraStartTimedOut
        case .firstFrameUnavailable: .cameraFirstFrameUnavailable
        case .recordingFailed: .cameraRecordingFailed
        case .disconnectedDuringCapture: .cameraInterruptionDisconnected
        case .runtimeFailure: .cameraSessionRuntimeFailure
        case .notCapturing: .cameraSessionNotCapturing
        }
    }

    static func redactedCategory(for error: Error) -> DevVlogsPhase0BFailureCategory {
        (error as? Self)?.redactedCategory ?? .cameraUnknown
    }
}

struct DevVlogsPhase0BMetric: Codable, Equatable {
    let name: String
    let value: Double
    let unit: String
    let disposition: String
}

struct DevVlogsPhase0BEvent: Codable, Equatable {
    let runID: String
    let caseID: String
    let attemptID: String
    let monotonicMilliseconds: Int64
    let action: String
    let result: DevVlogsPhase0BResult
    let category: DevVlogsPhase0BFailureCategory?
    let deviceClass: DevVlogsPhase0BDeviceClass?
    let redactedDeviceLabel: String?
    let metrics: [DevVlogsPhase0BMetric]

    init(
        runID: String,
        caseID: String,
        attemptID: String,
        monotonicMilliseconds: Int64,
        action: String,
        result: DevVlogsPhase0BResult,
        category: DevVlogsPhase0BFailureCategory? = nil,
        deviceClass: DevVlogsPhase0BDeviceClass? = nil,
        redactedDeviceLabel: String? = nil,
        metrics: [DevVlogsPhase0BMetric] = []
    ) {
        self.runID = runID
        self.caseID = caseID
        self.attemptID = attemptID
        self.monotonicMilliseconds = monotonicMilliseconds
        self.action = action
        self.result = result
        self.category = category
        self.deviceClass = deviceClass
        self.redactedDeviceLabel = redactedDeviceLabel
        self.metrics = metrics
    }
}

protocol DevVlogsPhase0BEventLogging {
    func record(_ event: DevVlogsPhase0BEvent) throws
}

struct DevVlogsPhase0BJSONLEventLog: DevVlogsPhase0BEventLogging {
    private let fileURL: URL
    private let encoder: JSONEncoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    func record(_ event: DevVlogsPhase0BEvent) throws {
        var data = try encoder.encode(event)
        data.append(0x0A)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            guard FileManager.default.createFile(atPath: fileURL.path, contents: data) else {
                throw DevVlogsPhase0BEventLogError.couldNotCreateLog
            }
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}

enum DevVlogsPhase0BEventLogError: Error, Equatable {
    case couldNotCreateLog
}

struct DevVlogsPhase0BInMemoryEventLog: DevVlogsPhase0BEventLogging {
    let recordEvent: (DevVlogsPhase0BEvent) throws -> Void

    func record(_ event: DevVlogsPhase0BEvent) throws {
        try recordEvent(event)
    }
}
#endif
