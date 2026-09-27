import AVFoundation
import Foundation

/// Decoder-backed validation of completed local audio, without retaining samples.
public nonisolated enum TranscriptionAudioValidation {
    public static func validate(_ url: URL) throws {
        do {
            let audio = try AVAudioFile(forReading: url)
            let format = audio.processingFormat
            guard audio.length > 0, format.sampleRate > 0,
                  format.channelCount > 0, format.channelCount <= 32,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let expectedFrames = audio.length
            var decodedFrames: AVAudioFramePosition = 0
            while decodedFrames < expectedFrames {
                try Task.checkCancellation()
                let frames = AVAudioFrameCount(min(4096, expectedFrames - decodedFrames))
                try audio.read(into: buffer, frameCount: frames)
                guard buffer.frameLength == frames else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                decodedFrames += AVAudioFramePosition(buffer.frameLength)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw OpenAITranscriptionServiceError.invalidRecording(.unreadableAudioFile(url))
        }
    }
}
