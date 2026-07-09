import Foundation

/// Transient handle to one completed recording in the current app runtime.
/// Durable journals and history must store a separately owned relative identifier.
public struct AudioRecordingArtifact: Equatable, Sendable {
    public let fileURL: URL
    public let duration: TimeInterval
    public let byteCount: Int64

    public init(
        fileURL: URL,
        duration: TimeInterval,
        byteCount: Int64
    ) {
        self.fileURL = fileURL
        self.duration = duration
        self.byteCount = byteCount
    }
}
