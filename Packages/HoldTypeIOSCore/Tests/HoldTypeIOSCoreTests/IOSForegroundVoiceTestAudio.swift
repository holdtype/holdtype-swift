import AVFAudio
import Foundation

func makeForegroundVoiceTestM4A(durationSeconds: Int) throws -> Data {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-v1-test-audio-\(UUID().uuidString).m4a",
        isDirectory: false
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let sampleRate = 16_000.0
    let channelCount: AVAudioChannelCount = 1
    let frameCount = AVAudioFrameCount(
        Int(sampleRate) * max(durationSeconds, 1)
    )
    guard let pcmFormat = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate,
        channels: channelCount
    ),
    let buffer = AVAudioPCMBuffer(
        pcmFormat: pcmFormat,
        frameCapacity: frameCount
    ),
    let samples = buffer.floatChannelData?[0] else {
        throw IOSForegroundVoiceTestAudioError.setupFailed
    }
    buffer.frameLength = frameCount
    for index in 0..<Int(frameCount) {
        let time = Double(index) / sampleRate
        samples[index] = Float(sin(2 * Double.pi * 440 * time) * 0.05)
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
    try file?.write(from: buffer)
    file = nil
    return try Data(contentsOf: url)
}

private enum IOSForegroundVoiceTestAudioError: Error {
    case setupFailed
}
