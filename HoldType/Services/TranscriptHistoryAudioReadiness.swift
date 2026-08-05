import AVFoundation
import Foundation

struct TranscriptHistoryAudioReadiness: Sendable {
    private let customValidation: (@Sendable (URL) -> Bool)?

    nonisolated init(isPlayableAudioFile: (@Sendable (URL) -> Bool)? = nil) {
        customValidation = isPlayableAudioFile
    }

    nonisolated func isPlayableAudioFile(at fileURL: URL) -> Bool {
        if let customValidation {
            return customValidation(fileURL)
        }

        guard fileURL.isFileURL else {
            return false
        }

        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let format = audioFile.processingFormat
            guard audioFile.length > 0,
                  format.sampleRate > 0,
                  format.channelCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1) else {
                return false
            }

            try audioFile.read(into: buffer, frameCount: 1)
            return buffer.frameLength == 1
        } catch {
            return false
        }
    }
}
