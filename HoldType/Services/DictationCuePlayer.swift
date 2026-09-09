//
//  DictationCuePlayer.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import AVFoundation
import Foundation
import HoldTypeDomain

nonisolated enum DictationCue: Equatable, Sendable {
    case startRecording
    case stopRecording
    case recordingLimitWarning(VoiceSessionWarningUrgency)
    case recordingLimitReached

    var frequencies: [Double] {
        switch self {
        case .startRecording:
            return [523.25, 659.25]
        case .stopRecording:
            return [587.33, 440.00]
        case .recordingLimitWarning(.amber):
            return [698.46]
        case .recordingLimitWarning(.red):
            return [880.00]
        case .recordingLimitReached:
            return [783.99, 587.33, 440.00]
        }
    }
}

protocol DictationCuePlaying: AnyObject {
    @MainActor
    func play(_ cue: DictationCue)
}

final class NativeDictationCuePlayer: DictationCuePlaying {
    nonisolated static let shared = NativeDictationCuePlayer()
    private let worker = DictationCueWorker()
    nonisolated init() {}
    @MainActor func play(_ cue: DictationCue) { worker.enqueue(cue) }
}

nonisolated private final class DictationCueWorker: @unchecked Sendable {
    private enum Constants {
        static let sampleRate: Double = 44_100
        static let noteDuration: TimeInterval = 0.09
        static let noteGap: TimeInterval = 0.025
        static let attackDuration: TimeInterval = 0.015
        static let maxGain: Double = 0.18
    }

    private lazy var engine = AVAudioEngine()
    private lazy var playerNode = AVAudioPlayerNode()
    private var isConfigured = false
    private let queue = DispatchQueue(label: "app.holdtype.dictation-cues", qos: .userInitiated)
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var generation = 0

    func enqueue(_ cue: DictationCue) {
        queue.async { self.play(cue) }
    }


    private func play(_ cue: DictationCue) {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Constants.sampleRate,
            channels: 1
        ),
            let buffer = cachedBuffer(for: cue, format: format)
        else {
            return
        }

        do {
            try prepareIfNeeded(format: format)
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
            playerNode.play()
            generation += 1
            let currentGeneration = generation
            queue.asyncAfter(deadline: .now() + 1) { [self] in
                guard generation == currentGeneration else { return }
                playerNode.stop()
                engine.stop()
            }
        } catch {
            return
        }
    }

    private func prepareIfNeeded(format: AVAudioFormat) throws {
        if !isConfigured {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            isConfigured = true
        }

        if !engine.isRunning {
            try engine.start()
        }
    }

    private func cachedBuffer(for cue: DictationCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let key = cue.frequencies.map(String.init(describing:)).joined(separator: ",")
        if let buffer = buffers[key] { return buffer }
        let buffer = makeBuffer(for: cue, format: format)
        buffers[key] = buffer
        return buffer
    }

    private func makeBuffer(for cue: DictationCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let noteFrameCount = Int(Constants.noteDuration * format.sampleRate)
        let gapFrameCount = Int(Constants.noteGap * format.sampleRate)
        let noteCount = cue.frequencies.count
        let totalFrameCount = noteFrameCount * noteCount + gapFrameCount * max(0, noteCount - 1)

        guard totalFrameCount > 0,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(totalFrameCount)
              ),
              let samples = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(totalFrameCount)

        var writeIndex = 0
        for (noteIndex, frequency) in cue.frequencies.enumerated() {
            writeNote(
                frequency: frequency,
                frameCount: noteFrameCount,
                sampleRate: format.sampleRate,
                samples: samples,
                startIndex: writeIndex
            )
            writeIndex += noteFrameCount

            guard noteIndex < noteCount - 1 else {
                continue
            }

            for gapFrame in 0..<gapFrameCount {
                samples[writeIndex + gapFrame] = 0
            }
            writeIndex += gapFrameCount
        }

        return buffer
    }

    private func writeNote(
        frequency: Double,
        frameCount: Int,
        sampleRate: Double,
        samples: UnsafeMutablePointer<Float>,
        startIndex: Int
    ) {
        guard frameCount > 0 else {
            return
        }

        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let phase = 2 * Double.pi * frequency * time
            let gain = envelopeGain(frame: frame)
            samples[startIndex + frame] = Float(sin(phase) * gain)
        }
    }

    private func envelopeGain(frame: Int) -> Double {
        let duration = Constants.noteDuration
        let time = Double(frame) / Constants.sampleRate
        let remainingTime = max(0, duration - time)

        if time < Constants.attackDuration {
            return Constants.maxGain * (time / Constants.attackDuration)
        }

        if remainingTime < Constants.attackDuration {
            return Constants.maxGain * (remainingTime / Constants.attackDuration)
        }

        return Constants.maxGain
    }
}
