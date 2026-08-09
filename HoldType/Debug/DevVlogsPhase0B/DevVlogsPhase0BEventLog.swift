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
    case cameraAuthorizationGranted = "camera_authorization_granted"
    case cameraAuthorizationAlreadyAuthorized = "camera_authorization_already_authorized"
    case cameraAuthorizationDenied = "camera_authorization_denied"
    case cameraAuthorizationRestricted = "camera_authorization_restricted"
    case cameraAuthorizationTimedOut = "camera_authorization_timed_out"
    case cameraAuthorizationCancelled = "camera_authorization_cancelled"
    case cameraAuthorizationActivationPolicyFailed = "camera_authorization_activation_policy_failed"
    case cameraAuthorizationActivationRejected = "camera_authorization_activation_rejected"
    case cameraAuthorizationActivationTimedOut = "camera_authorization_activation_timed_out"
    case cameraAuthorizationActivationCancelled = "camera_authorization_activation_cancelled"
    case cameraAuthorizationHarnessUnavailable = "camera_authorization_harness_unavailable"
    case cameraAuthorizationStatusUnknown = "camera_authorization_status_unknown"
    case cameraAuthorizationAcknowledgmentInvalid = "camera_authorization_acknowledgment_invalid"
    case cameraAuthorizationAcknowledgmentTimedOut = "camera_authorization_acknowledgment_timed_out"
    case cameraAuthorizationAcknowledgmentCancelled = "camera_authorization_acknowledgment_cancelled"
    case cameraPermissionRequired = "camera_permission_required"
    case cameraPermissionDenied = "camera_permission_denied"
    case cameraSelectionDisconnected = "camera_selection_disconnected"
    case cameraStartDeviceUnavailable = "camera_start_device_unavailable"
    case cameraSelectionBusy = "camera_selection_busy"
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
    case cameraProbe = "camera_probe"
    case passthroughIncompatible = "passthrough_incompatible"
    case passthroughExportFailed = "passthrough_export_failed"
    case finalization
    case finalProbe = "final_probe"
    case videoPreservationFailed = "video_preservation_failed"
    case eventLog = "event_log"
    case alreadyRun = "already_run"
}

enum DevVlogsPhase0BVideoPreservationFailureDimension: String, Codable, Equatable, CaseIterable {
    case expectedOneVideoTrack = "expected_one_video_track"
    case readerUnavailable = "reader_unavailable"
    case readingFailed = "reading_failed"
    case sampleCountMismatch = "sample_count_mismatch"
    case sampleBoundaryMismatch = "sample_boundary_mismatch"
    case encodedPayloadMismatch = "encoded_payload_mismatch"
    case sampleDurationMismatch = "sample_duration_mismatch"
    case presentationTimestampMismatch = "presentation_timestamp_mismatch"
    case decodeTimestampMismatch = "decode_timestamp_mismatch"
    case formatDescriptionMismatch = "format_description_mismatch"
    case dimensionsMismatch = "dimensions_mismatch"
    case transformMismatch = "transform_mismatch"
    case cancelled
    case timedOut = "timed_out"
    case unknown

    init(error: Error) {
        guard let error = error as? DevVlogsPhase0BVideoPreservationError else {
            self = .unknown
            return
        }
        switch error {
        case .expectedOneVideoTrack: self = .expectedOneVideoTrack
        case .readerUnavailable: self = .readerUnavailable
        case .readingFailed: self = .readingFailed
        case .sampleCountMismatch: self = .sampleCountMismatch
        case .sampleBoundaryMismatch: self = .sampleBoundaryMismatch
        case .encodedPayloadMismatch: self = .encodedPayloadMismatch
        case .sampleDurationMismatch: self = .sampleDurationMismatch
        case .presentationTimestampMismatch: self = .presentationTimestampMismatch
        case .decodeTimestampMismatch: self = .decodeTimestampMismatch
        case .formatDescriptionMismatch: self = .formatDescriptionMismatch
        case .dimensionsMismatch: self = .dimensionsMismatch
        case .transformMismatch: self = .transformMismatch
        case .cancelled: self = .cancelled
        case .timedOut: self = .timedOut
        }
    }
}

enum DevVlogsPhase0BCameraAuthorizationStage: String, Codable, Equatable, CaseIterable {
    case routeStarted = "route_started"
    case regularPolicySet = "regular_policy_set"
    case activationRequested = "activation_requested"
    case launchIdentityAcknowledged = "launch_identity_acknowledged"
    case activeStateConfirmed = "active_state_confirmed"
    case authorizationHarnessEntered = "authorization_harness_entered"
    case authorizationStatusInspected = "authorization_status_inspected"
    case requestAccessStarted = "request_access_started"

    var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

enum DevVlogsPhase0BHarnessFailure: Error, Equatable {
    case invalidConfiguration, audioStart
    case cameraStart(DevVlogsPhase0BFailureCategory)
    case captureStop, cameraProbe, passthroughIncompatible, passthroughExportFailed
    case finalization, finalProbe, eventLog, alreadyRun
    case videoPreservationFailed(DevVlogsPhase0BVideoPreservationFailureDimension)

    var category: DevVlogsPhase0BFailureCategory {
        switch self {
        case .invalidConfiguration: .invalidConfiguration
        case .audioStart: .audioStart
        case .cameraStart(let category): category
        case .captureStop: .captureStop
        case .cameraProbe: .cameraProbe
        case .passthroughIncompatible: .passthroughIncompatible
        case .passthroughExportFailed: .passthroughExportFailed
        case .finalization: .finalization
        case .finalProbe: .finalProbe
        case .videoPreservationFailed: .videoPreservationFailed
        case .eventLog: .eventLog
        case .alreadyRun: .alreadyRun
        }
    }
}

enum DevVlogsPhase0BOperatorSummary {
    static func line(for outcome: DevVlogsPhase0BHarnessOutcome) -> String {
        switch outcome {
        case .ready:
            return "dev_vlogs_phase_0b result=ready"
        case .failed(let failure):
            if case .videoPreservationFailed(let dimension) = failure {
                let result = switch dimension {
                case .cancelled: "cancelled"
                case .timedOut: "timed_out"
                default: "failed"
                }
                return "dev_vlogs_phase_0b result=\(result) category=\(failure.category.rawValue) " +
                    "preservation_error=\(dimension.rawValue) " +
                    "stages=camera_probe,passthrough,final_probe"
            } else {
                return "dev_vlogs_phase_0b result=failed category=\(failure.category.rawValue)"
            }
        }
    }
}

extension DevVlogsPhase0BCameraCaptureError {
    var redactedCategory: DevVlogsPhase0BFailureCategory {
        switch self {
        case .permissionRequired: .cameraPermissionRequired
        case .permissionDenied: .cameraPermissionDenied
        case .preferredDeviceDisconnected: .cameraSelectionDisconnected
        case .deviceUnavailableDuringStart: .cameraStartDeviceUnavailable
        case .preferredDeviceBusy: .cameraSelectionBusy
        case .videoInputUnavailable: .cameraConfigurationVideoInput
        case .movieOutputUnavailable: .cameraConfigurationMovieOutput
        case .sampleOutputUnavailable: .cameraConfigurationSampleOutput
        case .setupTimedOut: .cameraStartTimedOut
        case .firstFrameUnavailable: .cameraFirstFrameUnavailable
        case .recordingFailed: .cameraRecordingFailed
        case .disconnectedDuringCapture: .cameraInterruptionDisconnected
        case .runtimeFailure: .cameraSessionRuntimeFailure
        case .unknownPlatformFailure: .cameraUnknown
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

extension DevVlogsPhase0BMetric {
    static func realizedMediaEvidence(
        cameraProbe: DevVlogsPhase0BMediaProbeResult,
        finalProbe: DevVlogsPhase0BMediaProbeResult
    ) -> [Self] {
        var values: [Self] = []
        appendTrack("camera", cameraProbe.video, to: &values)
        appendTrack("final", finalProbe.video, to: &values)
        if let audio = finalProbe.audio { appendTrack("audio", audio, to: &values) }
        return values
    }

    static func captureEvidence(
        camera: DevVlogsPhase0BCameraCaptureArtifact,
        cameraProbe: DevVlogsPhase0BMediaProbeResult,
        finalProbe: DevVlogsPhase0BMediaProbeResult,
        preservation: DevVlogsPhase0BVideoPreservationResult
    ) -> [Self] {
        var values: [Self] = [
            .init(name: "camera_video_duration", value: cameraProbe.video.durationSeconds,
                  unit: "s", disposition: "evidence_only"),
            .init(name: "final_video_duration", value: finalProbe.video.durationSeconds,
                  unit: "s", disposition: "evidence_only"),
            .init(name: "preserved_sample_count", value: Double(preservation.sampleCount),
                  unit: "samples", disposition: "functional"),
            .init(name: "preserved_encoded_bytes", value: Double(preservation.encodedByteCount),
                  unit: "bytes", disposition: "functional"),
        ]
        append("camera_request_to_first_frame", camera.firstFrameMonotonicTime.map {
            ($0 - camera.requestMonotonicTime) * 1_000
        }, "ms", to: &values)
        appendTrack("camera", cameraProbe.video, to: &values)
        appendTrack("final", finalProbe.video, to: &values)
        append("audio_duration", finalProbe.audio?.durationSeconds, "s", to: &values)
        if let audio = finalProbe.audio { appendTrack("audio", audio, to: &values) }
        return values
    }

    private static func appendTrack(
        _ prefix: String,
        _ track: DevVlogsPhase0BMediaTrackProbe,
        to values: inout [Self]
    ) {
        append("\(prefix)_width", track.naturalDimensions.map { Double($0.width) }, "px", to: &values)
        append("\(prefix)_height", track.naturalDimensions.map { Double($0.height) }, "px", to: &values)
        append("\(prefix)_display_width", track.displayDimensions.map { Double($0.width) }, "px", to: &values)
        append("\(prefix)_display_height", track.displayDimensions.map { Double($0.height) }, "px", to: &values)
        append("\(prefix)_nominal_fps", track.nominalFrameRate.map(Double.init), "fps", to: &values)
        append("\(prefix)_derived_fps", track.derivedFrameRate, "fps", to: &values)
        append("\(prefix)_start_timestamp", track.startTimestampSeconds, "s", to: &values)
        append("\(prefix)_end_timestamp", track.endTimestampSeconds, "s", to: &values)
        append("\(prefix)_estimated_data_rate", Double(track.estimatedDataRate), "bps", to: &values)
        if let transform = track.preferredTransform {
            append("\(prefix)_transform_a", Double(transform.a), "coefficient", to: &values)
            append("\(prefix)_transform_b", Double(transform.b), "coefficient", to: &values)
            append("\(prefix)_transform_c", Double(transform.c), "coefficient", to: &values)
            append("\(prefix)_transform_d", Double(transform.d), "coefficient", to: &values)
        }
    }

    private static func append(
        _ name: String,
        _ value: Double?,
        _ unit: String,
        to values: inout [Self]
    ) {
        guard let value, value.isFinite else { return }
        values.append(.init(name: name, value: value, unit: unit, disposition: "evidence_only"))
    }
}

struct DevVlogsPhase0BVideoEvidence: Codable, Equatable {
    let cameraMediaSubtype: String
    let finalizedMediaSubtype: String
    let finalizedAudioMediaSubtype: String?
    let cameraFormat: String
    let finalizedFormat: String
    let preservationMethod: String
    let preservedSampleCount: Int
    let preservedEncodedByteCount: Int64
    let matched: Bool
}

struct DevVlogsPhase0BFailureStageEvidence: Codable, Equatable {
    let cameraProbePassed: Bool
    let passthroughCompleted: Bool
    let finalProbePassed: Bool
    let cameraMediaSubtype: String
    let finalizedMediaSubtype: String
    let finalizedAudioMediaSubtype: String?
    let cameraFormat: String
    let finalizedFormat: String
}

struct DevVlogsPhase0BEvent: Codable, Equatable {
    let runID: String
    let caseID: String
    let attemptID: String
    let monotonicMilliseconds: Int64
    let action: String
    let result: DevVlogsPhase0BResult
    let category: DevVlogsPhase0BFailureCategory?
    let furthestStage: DevVlogsPhase0BCameraAuthorizationStage?
    let deviceClass: DevVlogsPhase0BDeviceClass?
    let redactedDeviceLabel: String?
    let metrics: [DevVlogsPhase0BMetric]
    let videoEvidence: DevVlogsPhase0BVideoEvidence?
    let preservationFailureDimension: DevVlogsPhase0BVideoPreservationFailureDimension?
    let failureStageEvidence: DevVlogsPhase0BFailureStageEvidence?

    private enum CodingKeys: String, CodingKey {
        case runID, caseID, attemptID, monotonicMilliseconds, action, result, category
        case furthestStage = "furthest_stage"
        case deviceClass, redactedDeviceLabel, metrics, videoEvidence
        case preservationFailureDimension = "preservation_failure_dimension"
        case failureStageEvidence = "failure_stage_evidence"
    }

    init(
        runID: String,
        caseID: String,
        attemptID: String,
        monotonicMilliseconds: Int64,
        action: String,
        result: DevVlogsPhase0BResult,
        category: DevVlogsPhase0BFailureCategory? = nil,
        furthestStage: DevVlogsPhase0BCameraAuthorizationStage? = nil,
        deviceClass: DevVlogsPhase0BDeviceClass? = nil,
        redactedDeviceLabel: String? = nil,
        metrics: [DevVlogsPhase0BMetric] = [],
        videoEvidence: DevVlogsPhase0BVideoEvidence? = nil,
        preservationFailureDimension: DevVlogsPhase0BVideoPreservationFailureDimension? = nil,
        failureStageEvidence: DevVlogsPhase0BFailureStageEvidence? = nil
    ) {
        self.runID = runID
        self.caseID = caseID
        self.attemptID = attemptID
        self.monotonicMilliseconds = monotonicMilliseconds
        self.action = action
        self.result = result
        self.category = category
        self.furthestStage = furthestStage
        self.deviceClass = deviceClass
        self.redactedDeviceLabel = redactedDeviceLabel
        self.metrics = metrics
        self.videoEvidence = videoEvidence
        self.preservationFailureDimension = preservationFailureDimension
        self.failureStageEvidence = failureStageEvidence
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
