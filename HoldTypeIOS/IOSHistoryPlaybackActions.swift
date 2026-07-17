import Foundation
import HoldTypeDomain
import HoldTypePersistence

enum IOSHistoryPlaybackAttempt: Equatable {
    case played
    case unavailable
    case failed
}

enum IOSSavedRecordingHistoryLoadResult: Equatable {
    case loaded([IOSSavedAcceptedRecording])
    case failed
}

enum IOSSavedRecordingHistoryDiscardAttempt: Equatable {
    case discarded
    case alreadyAbsent
    case stale
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
    private let loadSavedRecordings:
        () async -> IOSSavedRecordingHistoryLoadResult
    private let playSavedRecording:
        (IOSSavedAcceptedRecording) async -> IOSHistoryPlaybackAttempt
    private let discardSavedRecording:
        (IOSSavedAcceptedRecording) async
            -> IOSSavedRecordingHistoryDiscardAttempt
    private let stopPlayback: () async -> Void

    init(
        cache: IOSAcceptedAudioCache,
        loadPolicy: @escaping @Sendable () async -> RecordingCachePolicy,
        player: IOSHistoryAudioPlaybackOwner
    ) {
        resolvePlayableResultIDs = { resultIDs in
            var playable = Set<UUID>()
            playable.reserveCapacity(resultIDs.count)
            let policy = (await loadPolicy()).normalized
            for resultID in resultIDs {
                if (try? await cache.playableAudioFileURL(
                    resultID: resultID,
                    policy: policy
                )) != nil {
                    playable.insert(resultID)
                }
            }
            return playable
        }
        playRecording = { resultID in
            guard let fileURL = try? await cache.playableAudioFileURL(
                resultID: resultID,
                policy: await loadPolicy()
            ) else {
                return .unavailable
            }
            return player.playCachedAudio(at: fileURL)
                ? .played
                : .failed
        }
        loadSavedRecordings = {
            do {
                return .loaded(try await cache.savedRecordings())
            } catch {
                return .failed
            }
        }
        playSavedRecording = { expected in
            do {
                guard let fileURL = try await cache.savedAudioFileURL(
                    ifCurrent: expected
                ) else {
                    return .unavailable
                }
                return player.playCachedAudio(at: fileURL)
                    ? .played
                    : .failed
            } catch {
                return .unavailable
            }
        }
        discardSavedRecording = { expected in
            do {
                switch try await cache.discardSavedRecording(
                    ifCurrent: expected
                ) {
                case .discarded:
                    return .discarded
                case .alreadyAbsent:
                    return .alreadyAbsent
                }
            } catch IOSAcceptedAudioCacheError.staleSavedRecording {
                return .stale
            } catch {
                return .failed
            }
        }
        stopPlayback = {
            _ = await player.stopAndDeactivate()
        }
    }

    init(
        resolvePlayableResultIDs: @escaping ([UUID]) async -> Set<UUID>,
        playRecording: @escaping (UUID) async
            -> IOSHistoryPlaybackAttempt,
        loadSavedRecordings: @escaping () async
            -> IOSSavedRecordingHistoryLoadResult = { .loaded([]) },
        playSavedRecording: @escaping (IOSSavedAcceptedRecording) async
            -> IOSHistoryPlaybackAttempt = { _ in .unavailable },
        discardSavedRecording: @escaping (IOSSavedAcceptedRecording) async
            -> IOSSavedRecordingHistoryDiscardAttempt = { _ in .alreadyAbsent },
        stopPlayback: @escaping () async -> Void = {}
    ) {
        self.resolvePlayableResultIDs = resolvePlayableResultIDs
        self.playRecording = playRecording
        self.loadSavedRecordings = loadSavedRecordings
        self.playSavedRecording = playSavedRecording
        self.discardSavedRecording = discardSavedRecording
        self.stopPlayback = stopPlayback
    }

    func playableResultIDs(_ resultIDs: [UUID]) async -> Set<UUID> {
        await resolvePlayableResultIDs(resultIDs)
    }

    func play(resultID: UUID) async -> IOSHistoryPlaybackAttempt {
        await playRecording(resultID)
    }

    func savedRecordings() async -> IOSSavedRecordingHistoryLoadResult {
        await loadSavedRecordings()
    }

    func playSaved(
        _ expected: IOSSavedAcceptedRecording
    ) async -> IOSHistoryPlaybackAttempt {
        await playSavedRecording(expected)
    }

    func discardSaved(
        _ expected: IOSSavedAcceptedRecording
    ) async -> IOSSavedRecordingHistoryDiscardAttempt {
        await discardSavedRecording(expected)
    }

    func stop() async {
        await stopPlayback()
    }
}
