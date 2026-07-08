//
//  TranscriptHistoryAudioPlaybackAction.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import AVFoundation
import Foundation

protocol TranscriptHistoryAudioPlaying: AnyObject {
    func playCachedAudio(at fileURL: URL) throws
}

enum TranscriptHistoryAudioPlaybackError: Error, Equatable {
    case unavailable
    case playbackFailed
}

final class TranscriptHistoryAudioPlayer: NSObject, TranscriptHistoryAudioPlaying {
    private var currentPlayer: AVAudioPlayer?

    func playCachedAudio(at fileURL: URL) throws {
        do {
            currentPlayer?.stop()
            let player = try AVAudioPlayer(contentsOf: fileURL)
            guard player.prepareToPlay(), player.play() else {
                throw TranscriptHistoryAudioPlaybackError.playbackFailed
            }
            currentPlayer = player
        } catch let error as TranscriptHistoryAudioPlaybackError {
            throw error
        } catch {
            throw TranscriptHistoryAudioPlaybackError.playbackFailed
        }
    }
}

struct TranscriptHistoryAudioPlaybackAction {
    private let audioPlayer: any TranscriptHistoryAudioPlaying
    private let fileManager: FileManager

    init(
        audioPlayer: any TranscriptHistoryAudioPlaying = TranscriptHistoryAudioPlayer(),
        fileManager: FileManager = .default
    ) {
        self.audioPlayer = audioPlayer
        self.fileManager = fileManager
    }

    func canPlay(_ entry: TranscriptHistoryEntry, settings: AppSettings) -> Bool {
        guard settings.recordingCachePolicy.keepsRecordings,
              let cachedAudioFileURL = entry.cachedAudioFileURL else {
            return false
        }

        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: cachedAudioFileURL.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    func play(_ entry: TranscriptHistoryEntry, settings: AppSettings) -> TranscriptHistoryAudioPlaybackResult {
        guard canPlay(entry, settings: settings),
              let cachedAudioFileURL = entry.cachedAudioFileURL else {
            return .unavailable
        }

        do {
            try audioPlayer.playCachedAudio(at: cachedAudioFileURL)
            return .playing
        } catch {
            return .failed
        }
    }
}

enum TranscriptHistoryAudioPlaybackResult: Equatable {
    case playing
    case unavailable
    case failed

    var statusText: String {
        switch self {
        case .playing:
            return "Playing cached recording."
        case .unavailable:
            return "Cached recording is no longer available."
        case .failed:
            return "Could not play cached recording."
        }
    }
}
