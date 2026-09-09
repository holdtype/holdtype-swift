import Foundation
import OSLog

/// Opt-in monotonic markers only. No audio, text, credentials, or disk writer.
nonisolated enum DictationStartTiming {
    static let enabled = ProcessInfo.processInfo.environment["HOLDTYPE_DEBUG_START_TIMING"] == "1"
    private static let logger = Logger(subsystem: "app.holdtype.HoldType", category: "StartTiming")

    static func mark(_ stage: String, inputTimestamp: UInt64 = 0) {
        guard enabled else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        logger.info("start_stage=\(stage, privacy: .public) uptime_ns=\(now, privacy: .public) input_ns=\(inputTimestamp, privacy: .public)")
    }
}
