//
//  TranscriptRecoveryHistoryStore.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Combine
import Foundation
import HoldTypeDomain

protocol TranscriptHistoryPersistence {
    func loadTranscriptHistoryData(forKey key: String) throws -> Data?
    func saveTranscriptHistoryData(_ data: Data, forKey key: String) throws
    func removeTranscriptHistoryData(forKey key: String) throws
}

extension UserDefaults: TranscriptHistoryPersistence {
    func loadTranscriptHistoryData(forKey key: String) throws -> Data? {
        data(forKey: key)
    }

    func saveTranscriptHistoryData(_ data: Data, forKey key: String) throws {
        set(data, forKey: key)
    }

    func removeTranscriptHistoryData(forKey key: String) throws {
        removeObject(forKey: key)
    }
}

@MainActor
protocol TranscriptRecoveryHistoryRecording: AnyObject {
    func recordAcceptedTranscript(_ request: AcceptedTranscriptHistoryRequest) throws
}

enum TranscriptRecoveryHistoryError: Error, Equatable, LocalizedError {
    case emptyTranscript
    case invalidEntry
    case loadFailed
    case unreadableHistory
    case saveFailed
    case clearFailed

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "Empty transcripts are not saved to recovery history."
        case .invalidEntry:
            return "The transcript could not be prepared for recovery history."
        case .loadFailed:
            return "Transcript history could not be loaded."
        case .unreadableHistory:
            return "Saved transcript history could not be read."
        case .saveFailed:
            return "Transcript history could not be saved."
        case .clearFailed:
            return "Transcript history could not be cleared."
        }
    }
}

@MainActor
final class TranscriptRecoveryHistoryStore: ObservableObject, TranscriptRecoveryHistoryRecording {
    static let shared = TranscriptRecoveryHistoryStore()
    nonisolated static let defaultStorageKey = "holdtype.transcriptHistory.entries"
    nonisolated static let defaultRetentionLimit =
        RetentionConfiguration.acceptedHistoryEntryLimit

    @Published private(set) var entries: [TranscriptHistoryEntry]
    @Published private(set) var storageErrorMessage: String?

    private let persistence: any TranscriptHistoryPersistence
    private let storageKey: String
    private let retentionLimit: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = TranscriptRecoveryHistoryStore.defaultStorageKey,
        retentionLimit: Int = TranscriptRecoveryHistoryStore.defaultRetentionLimit
    ) {
        self.init(
            persistence: userDefaults,
            storageKey: storageKey,
            retentionLimit: retentionLimit
        )
    }

    init(
        persistence: any TranscriptHistoryPersistence,
        storageKey: String = TranscriptRecoveryHistoryStore.defaultStorageKey,
        retentionLimit: Int = TranscriptRecoveryHistoryStore.defaultRetentionLimit,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.persistence = persistence
        self.storageKey = storageKey
        self.retentionLimit = max(1, retentionLimit)
        self.encoder = encoder
        self.decoder = decoder
        entries = []
        storageErrorMessage = nil

        reload()
    }

    func recordAcceptedTranscript(_ request: AcceptedTranscriptHistoryRequest) throws {
        guard request.historyEnabled else {
            return
        }

        let entry: TranscriptHistoryEntry
        do {
            entry = try TranscriptHistoryEntry(
                transcriptText: request.acceptedTranscript.text,
                transcriptionModel: request.transcriptionModel,
                languageCode: request.languageCode,
                audioDuration: request.audioDuration,
                cachedAudioFileURL: request.cachedAudioFileURL
            )
        } catch TranscriptHistoryEntry.ValidationError.emptyTranscriptText {
            throw TranscriptRecoveryHistoryError.emptyTranscript
        } catch {
            throw TranscriptRecoveryHistoryError.invalidEntry
        }

        let updatedEntries = retainedEntries([entry] + entries)
        do {
            try save(updatedEntries)
            entries = updatedEntries
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = Self.userFacingMessage(for: error)
            throw error
        }
    }

    func reload() {
        do {
            entries = try load()
            storageErrorMessage = nil
        } catch {
            entries = []
            storageErrorMessage = Self.userFacingMessage(for: error)
        }
    }

    func clear() throws {
        do {
            try persistence.removeTranscriptHistoryData(forKey: storageKey)
            entries = []
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = Self.userFacingMessage(
                for: TranscriptRecoveryHistoryError.clearFailed
            )
            throw TranscriptRecoveryHistoryError.clearFailed
        }
    }

    @discardableResult
    func deleteEntry(id: TranscriptHistoryEntry.ID) throws -> Bool {
        let updatedEntries = entries.filter { $0.id != id }
        guard updatedEntries.count != entries.count else {
            return false
        }

        do {
            if updatedEntries.isEmpty {
                do {
                    try persistence.removeTranscriptHistoryData(forKey: storageKey)
                } catch {
                    throw TranscriptRecoveryHistoryError.saveFailed
                }
            } else {
                try save(updatedEntries)
            }
            entries = updatedEntries
            storageErrorMessage = nil
            return true
        } catch {
            storageErrorMessage = Self.userFacingMessage(for: error)
            throw error
        }
    }

    private func load() throws -> [TranscriptHistoryEntry] {
        let data: Data?
        do {
            data = try persistence.loadTranscriptHistoryData(forKey: storageKey)
        } catch {
            throw TranscriptRecoveryHistoryError.loadFailed
        }

        guard let data else {
            return []
        }

        do {
            return retainedEntries(try decoder.decode([TranscriptHistoryEntry].self, from: data))
        } catch {
            throw TranscriptRecoveryHistoryError.unreadableHistory
        }
    }

    private func save(_ entries: [TranscriptHistoryEntry]) throws {
        do {
            try persistence.saveTranscriptHistoryData(
                try encoder.encode(retainedEntries(entries)),
                forKey: storageKey
            )
        } catch {
            throw TranscriptRecoveryHistoryError.saveFailed
        }
    }

    private func retainedEntries(_ entries: [TranscriptHistoryEntry]) -> [TranscriptHistoryEntry] {
        let newestFirstEntries = entries.enumerated().sorted { lhs, rhs in
            if lhs.element.createdAt != rhs.element.createdAt {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return lhs.offset < rhs.offset
        }.map(\.element)

        return Array(newestFirstEntries.prefix(retentionLimit))
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        return error.localizedDescription
    }
}
