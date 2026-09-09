import Foundation
import HoldTypeDomain

/// Optional camera preparation never sits in the microphone start path. A late
/// camera is discarded once its dictation attempt ends, without delaying audio.
@MainActor
final class DictationDevVlogsAttempt {
    private let capture: any DevVlogsCaptureCoordinating
    private var generation = 0
    private var startTask: Task<Void, Never>?

    init(capture: any DevVlogsCaptureCoordinating) { self.capture = capture }

    func start() {
        generation += 1
        let token = generation
        let audioStartedAt = ProcessInfo.processInfo.systemUptime
        let begin = capture.prepareStart(audioStartedAt: audioStartedAt)
        startTask = Task { @MainActor [self] in
            guard token == generation, !Task.isCancelled else { return }
            await begin()
            guard token == generation, !Task.isCancelled else {
                return
            }
            startTask = nil
        }
    }

    func end() {
        generation += 1
        startTask?.cancel()
        startTask = nil
        capture.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
    }

    func finish(audioArtifact: AudioRecordingArtifact) async {
        if startTask != nil {
            end()
        } else {
            await capture.finishAttempt(audioArtifact: audioArtifact)
        }
    }
}
