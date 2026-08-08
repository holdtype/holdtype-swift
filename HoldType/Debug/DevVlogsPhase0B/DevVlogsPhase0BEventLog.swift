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
