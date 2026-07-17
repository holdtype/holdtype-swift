import Foundation
import HoldTypeDomain

@MainActor
protocol RecordingDurationMonitoring: AnyObject {
    func start(onElapsedWholeSecond: @escaping @MainActor (Int) -> Void)
    func stop()
}

@MainActor
final class ContinuousRecordingDurationMonitor: RecordingDurationMonitoring {
    private var task: Task<Void, Never>?

    func start(onElapsedWholeSecond: @escaping @MainActor (Int) -> Void) {
        stop()
        task = Task { @MainActor in
            let clock = ContinuousClock()
            let startedAt = clock.now
            var lastDeliveredSecond = 0

            while !Task.isCancelled,
                  lastDeliveredSecond < VoiceSessionWarningSchedule.maximumDurationWholeSeconds {
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    return
                }

                let elapsedComponents = startedAt.duration(to: clock.now).components
                let elapsedWholeSecond = min(
                    VoiceSessionWarningSchedule.maximumDurationWholeSeconds,
                    max(0, Int(elapsedComponents.seconds))
                )
                guard elapsedWholeSecond > lastDeliveredSecond else {
                    continue
                }

                for second in (lastDeliveredSecond + 1)...elapsedWholeSecond {
                    guard !Task.isCancelled else {
                        return
                    }
                    onElapsedWholeSecond(second)
                }
                lastDeliveredSecond = elapsedWholeSecond
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
