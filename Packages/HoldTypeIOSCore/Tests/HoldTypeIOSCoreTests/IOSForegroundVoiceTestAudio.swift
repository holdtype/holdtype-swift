import AVFAudio
import Foundation

private let foregroundVoiceTestAudioEncodingLock = NSLock()

func makeForegroundVoiceTestM4A(durationSeconds: Int) throws -> Data {
    // AVAudioFile's AAC writer is process-global enough to be flaky when the
    // processor and transcription-executor suites synthesize fixtures at the
    // same time. Keep fixture encoding serialized; product audio paths are not
    // involved in this helper.
    foregroundVoiceTestAudioEncodingLock.lock()
    defer { foregroundVoiceTestAudioEncodingLock.unlock() }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-v1-test-audio-\(UUID().uuidString).m4a",
        isDirectory: false
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let sampleRate = 16_000.0
    let channelCount: AVAudioChannelCount = 1
    let totalFrameCount = Int(sampleRate) * max(durationSeconds, 1)
    let encodingChunkFrameCount: AVAudioFrameCount = 4_096
    guard let pcmFormat = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate,
        channels: channelCount
    ),
    let buffer = AVAudioPCMBuffer(
        pcmFormat: pcmFormat,
        frameCapacity: encodingChunkFrameCount
    ),
    let samples = buffer.floatChannelData?[0] else {
        throw IOSForegroundVoiceTestAudioError.setupFailed
    }

    var file: AVAudioFile? = try AVAudioFile(
        forWriting: url,
        settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channelCount),
            AVEncoderBitRateKey: 32_000,
        ]
    )
    // A five-minute fixture contains 4.8 million frames. Encoding it as one
    // giant AVAudioPCMBuffer can corrupt the Swift test helper process after
    // AVAudioFile.write returns. Bounded writes match real recorder behavior
    // and keep one continuous waveform by using the absolute sample index.
    var writtenFrameCount = 0
    while writtenFrameCount < totalFrameCount {
        let currentFrameCount = min(
            Int(encodingChunkFrameCount),
            totalFrameCount - writtenFrameCount
        )
        buffer.frameLength = AVAudioFrameCount(currentFrameCount)
        for localIndex in 0..<currentFrameCount {
            let absoluteIndex = writtenFrameCount + localIndex
            let time = Double(absoluteIndex) / sampleRate
            samples[localIndex] = Float(
                sin(2 * Double.pi * 440 * time) * 0.05
            )
        }
        try file?.write(from: buffer)
        writtenFrameCount += currentFrameCount
    }
    file = nil
    return try Data(contentsOf: url)
}

private enum IOSForegroundVoiceTestAudioError: Error {
    case setupFailed
}
