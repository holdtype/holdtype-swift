import Foundation
import HoldTypeDomain
import HoldTypePersistence

enum IOSHistoryPlaybackAttempt: Equatable {
    case played
    case unavailable
    case failed
}

/// Applies the saved recording-cache policy independently from History UI.
/// Disabling retention stops local playback before managed files are removed.
@MainActor
struct IOSRecordingCacheLifecycleActions {
    private let applyPolicy: (RecordingCachePolicy) async -> Bool

    init(
        cache: IOSAcceptedAudioCache,
        player: IOSHistoryAudioPlaybackOwner?
    ) {
        self.init(
            stopPlayback: {
                guard let player else { return }
                _ = await player.stopAndDeactivate()
            },
            reconcileCache: { policy in
                do {
                    try await cache.reconcile(policy: policy)
                    return true
                } catch {
                    return false
                }
            }
        )
    }

    init(
        stopPlayback: @escaping () async -> Void = {},
        reconcileCache: @escaping (RecordingCachePolicy) async -> Bool
    ) {
        applyPolicy = { policy in
            let policy = policy.normalized
            if !policy.keepsRecordings {
                await stopPlayback()
            }
            return await reconcileCache(policy)
        }
    }

    func reconcile(policy: RecordingCachePolicy) async -> Bool {
        await applyPolicy(policy.normalized)
    }
}

/// Small containing-app boundary between the text-only History screen and the
/// independent accepted-recording cache.
@MainActor
struct IOSHistoryPlaybackActions {
    private let resolvePlayableResultIDs: ([UUID]) async -> Set<UUID>
    private let playRecording: (UUID) async -> IOSHistoryPlaybackAttempt
    private let stopPlayback: () async -> Void

    init(
        cache: IOSAcceptedAudioCache,
        loadPolicy: @escaping @Sendable () async -> RecordingCachePolicy,
        player: IOSHistoryAudioPlaybackOwner
    ) {
        resolvePlayableResultIDs = { resultIDs in
            guard (await loadPolicy()).normalized.keepsRecordings else {
                return []
            }

            var playable = Set<UUID>()
            playable.reserveCapacity(resultIDs.count)
            for resultID in resultIDs {
                if await cache.cachedAudioFileURLIfAvailable(
                    resultID: resultID
                ) != nil {
                    playable.insert(resultID)
                }
            }
            return playable
        }
        playRecording = { resultID in
            guard (await loadPolicy()).normalized.keepsRecordings,
                  let fileURL = await cache
                    .cachedAudioFileURLIfAvailable(resultID: resultID) else {
                return .unavailable
            }
            return player.playCachedAudio(at: fileURL)
                ? .played
                : .failed
        }
        stopPlayback = {
            _ = await player.stopAndDeactivate()
        }
    }

    init(
        resolvePlayableResultIDs: @escaping ([UUID]) async -> Set<UUID>,
        playRecording: @escaping (UUID) async
            -> IOSHistoryPlaybackAttempt,
        stopPlayback: @escaping () async -> Void = {}
    ) {
        self.resolvePlayableResultIDs = resolvePlayableResultIDs
        self.playRecording = playRecording
        self.stopPlayback = stopPlayback
    }

    func playableResultIDs(_ resultIDs: [UUID]) async -> Set<UUID> {
        await resolvePlayableResultIDs(resultIDs)
    }

    func play(resultID: UUID) async -> IOSHistoryPlaybackAttempt {
        await playRecording(resultID)
    }

    func stop() async {
        await stopPlayback()
    }
}
