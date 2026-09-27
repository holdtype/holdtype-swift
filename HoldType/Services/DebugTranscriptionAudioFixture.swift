#if DEBUG
import AVFoundation
import Foundation

enum DebugTranscriptionAudioFixture {
    static func write(to url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 8192, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = buffer.frameCapacity
        buffer.floatChannelData?[0].initialize(repeating: 0, count: 8192)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
#endif
