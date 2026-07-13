//
//  KeyboardBridge.swift
//  HoldType
//
//  Created by Codex on 7/9/26.
//

import Foundation

nonisolated enum KeyboardBridgeConfiguration {
    static let appGroupIdentifier = "group.app.holdtype.HoldType.shared"

    // V3 removes the obsolete recent-results payload at the same cache URL.
    static let snapshotFilename = "keyboard-bridge-v1.json"
    static let maximumSnapshotBytes = 32 * 1_024
    static let maximumTextUTF8Bytes = 16 * 1_024
    static let latestLifetime: TimeInterval = 10 * 60
}

nonisolated struct KeyboardBridgeItem:
    Codable,
    Equatable,
    Identifiable,
    Sendable {
    enum ValidationError: Error, Equatable {
        case emptyText
        case textTooLarge(maximumUTF8Bytes: Int)
        case unsafeControlScalar(UInt32)
        case invalidDateRange
    }

    let resultID: UUID
    let text: String
    let createdAt: Date
    let expiresAt: Date

    var id: UUID {
        resultID
    }

    private enum CodingKeys: String, CodingKey {
        case resultID
        case text
        case createdAt
        case expiresAt
    }

    init(
        resultID: UUID,
        text: String,
        createdAt: Date,
        expiresAt: Date
    ) throws {
        guard text.unicodeScalars.contains(where: { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }) else {
            throw ValidationError.emptyText
        }
        guard text.utf8.count <= KeyboardBridgeConfiguration.maximumTextUTF8Bytes else {
            throw ValidationError.textTooLarge(
                maximumUTF8Bytes: KeyboardBridgeConfiguration.maximumTextUTF8Bytes
            )
        }

        if let unsafeScalar = text.unicodeScalars.first(where: Self.isUnsafeControlScalar) {
            throw ValidationError.unsafeControlScalar(unsafeScalar.value)
        }

        guard createdAt.timeIntervalSinceReferenceDate.isFinite,
              expiresAt.timeIntervalSinceReferenceDate.isFinite,
              expiresAt > createdAt else {
            throw ValidationError.invalidDateRange
        }

        self.resultID = resultID
        self.text = text
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    static func latest(
        resultID: UUID,
        text: String,
        createdAt: Date
    ) throws -> KeyboardBridgeItem {
        try KeyboardBridgeItem(
            resultID: resultID,
            text: text,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(
                KeyboardBridgeConfiguration.latestLifetime
            )
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            try self.init(
                resultID: container.decode(UUID.self, forKey: .resultID),
                text: container.decode(String.self, forKey: .text),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                expiresAt: container.decode(Date.self, forKey: .expiresAt)
            )
        } catch let error as ValidationError {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid keyboard bridge item: \(error)"
                )
            )
        }
    }

    private static func isUnsafeControlScalar(_ scalar: Unicode.Scalar) -> Bool {
        guard scalar.properties.generalCategory == .control else {
            return false
        }

        return scalar.value != 0x09 && scalar.value != 0x0A && scalar.value != 0x0D
    }
}

nonisolated struct KeyboardBridgeSnapshot: Codable, Equatable, Sendable {
    enum ValidationError: Error, Equatable {
        case incompatibleSchemaVersion(Int)
        case invalidRevision
        case invalidPublishedAt
        case invalidLatestLifetime
    }

    static let currentSchemaVersion = 3

    let schemaVersion: Int
    let revision: UInt64
    let publishedAt: Date
    let latest: KeyboardBridgeItem?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case publishedAt
        case latest
    }

    init(
        revision: UInt64,
        publishedAt: Date = Date(),
        latest: KeyboardBridgeItem?
    ) throws {
        try self.init(
            schemaVersion: Self.currentSchemaVersion,
            revision: revision,
            publishedAt: publishedAt,
            latest: latest
        )
    }

    func latestForInsertion(at date: Date = Date()) -> KeyboardBridgeItem? {
        guard let latest, latest.expiresAt > date else {
            return nil
        }

        return latest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            try self.init(
                schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
                revision: container.decode(UInt64.self, forKey: .revision),
                publishedAt: container.decode(Date.self, forKey: .publishedAt),
                latest: container.decodeIfPresent(
                    KeyboardBridgeItem.self,
                    forKey: .latest
                )
            )
        } catch let error as ValidationError {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid keyboard bridge snapshot: \(error)"
                )
            )
        }
    }

    private init(
        schemaVersion: Int,
        revision: UInt64,
        publishedAt: Date,
        latest: KeyboardBridgeItem?
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ValidationError.incompatibleSchemaVersion(schemaVersion)
        }
        guard revision > 0 else {
            throw ValidationError.invalidRevision
        }
        guard publishedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw ValidationError.invalidPublishedAt
        }
        guard latest.map({ Self.hasLifetime(
            $0,
            duration: KeyboardBridgeConfiguration.latestLifetime
        ) }) ?? true else {
            throw ValidationError.invalidLatestLifetime
        }
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.publishedAt = publishedAt
        self.latest = latest
    }

    private static func hasLifetime(
        _ item: KeyboardBridgeItem,
        duration: TimeInterval
    ) -> Bool {
        abs(item.expiresAt.timeIntervalSince(item.createdAt) - duration) <= 0.001
    }
}

nonisolated enum KeyboardBridgeStoreError:
    Error,
    LocalizedError,
    Equatable {
    case appGroupContainerUnavailable(String)
    case snapshotReadFailed
    case snapshotDecodeFailed
    case snapshotEncodeFailed
    case snapshotWriteFailed
    case snapshotTooLarge(maximumBytes: Int, actualBytes: Int)
    case incompatibleSchemaVersion(found: Int, supported: Int)
    case nonIncreasingRevision(current: UInt64, proposed: UInt64)
    case revisionExhausted

    var errorDescription: String? {
        switch self {
        case .appGroupContainerUnavailable:
            return "The HoldType App Group container is unavailable."
        case .snapshotReadFailed:
            return "The keyboard bridge snapshot could not be read."
        case .snapshotDecodeFailed:
            return "The keyboard bridge snapshot is invalid."
        case .snapshotEncodeFailed:
            return "The keyboard bridge snapshot could not be encoded."
        case .snapshotWriteFailed:
            return "The keyboard bridge snapshot could not be saved."
        case .snapshotTooLarge:
            return "The keyboard bridge snapshot exceeds its size limit."
        case .incompatibleSchemaVersion:
            return "The keyboard bridge snapshot uses an unsupported version."
        case .nonIncreasingRevision:
            return "The keyboard bridge revision must increase."
        case .revisionExhausted:
            return "The keyboard bridge revision cannot increase further."
        }
    }
}

nonisolated struct KeyboardBridgeStore {
    private static let maximumLegacySnapshotBytes = 128 * 1_024

    private struct SnapshotHeader: Decodable {
        let schemaVersion: Int
        let revision: UInt64
    }

    private let directoryURL: URL
    private let fileManager: FileManager
    private let writingOptions: Data.WritingOptions

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        writingOptions: Data.WritingOptions = [
            .atomic,
            .completeFileProtectionUntilFirstUserAuthentication,
        ]
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.writingOptions = writingOptions
    }

    static func appGroup(
        identifier: String = KeyboardBridgeConfiguration.appGroupIdentifier,
        fileManager: FileManager = .default
    ) throws -> KeyboardBridgeStore {
        guard let directoryURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            throw KeyboardBridgeStoreError.appGroupContainerUnavailable(identifier)
        }

        return KeyboardBridgeStore(directoryURL: directoryURL, fileManager: fileManager)
    }

    func load() throws -> KeyboardBridgeSnapshot? {
        guard let data = try storedData() else {
            return nil
        }

        let header = try decodeHeader(from: data)
        guard header.schemaVersion == KeyboardBridgeSnapshot.currentSchemaVersion else {
            throw KeyboardBridgeStoreError.incompatibleSchemaVersion(
                found: header.schemaVersion,
                supported: KeyboardBridgeSnapshot.currentSchemaVersion
            )
        }

        do {
            return try decoder.decode(KeyboardBridgeSnapshot.self, from: data)
        } catch {
            throw KeyboardBridgeStoreError.snapshotDecodeFailed
        }
    }

    func nextRevision() throws -> UInt64 {
        guard let header = try replacementHeader() else {
            return 1
        }
        guard header.revision < UInt64.max else {
            throw KeyboardBridgeStoreError.revisionExhausted
        }

        return header.revision + 1
    }

    /// Removes obsolete V1/V2 payload fields even while Latest publication is
    /// still release-gated. The replacement remains a bounded, empty cache.
    @discardableResult
    func replaceLegacySnapshotIfNeeded(
        at publishedAt: Date = Date()
    ) throws -> Bool {
        guard let header = try storedLegacyHeaderForCutover() else {
            return false
        }
        guard header.revision < UInt64.max else {
            throw KeyboardBridgeStoreError.revisionExhausted
        }

        let replacement = try KeyboardBridgeSnapshot(
            revision: header.revision + 1,
            publishedAt: publishedAt,
            latest: nil
        )
        try save(replacement)
        return true
    }

    func save(_ snapshot: KeyboardBridgeSnapshot) throws {
        if let currentHeader = try replacementHeader(),
           snapshot.revision <= currentHeader.revision {
            throw KeyboardBridgeStoreError.nonIncreasingRevision(
                current: currentHeader.revision,
                proposed: snapshot.revision
            )
        }

        let data: Data
        do {
            data = try encoder.encode(snapshot)
        } catch {
            throw KeyboardBridgeStoreError.snapshotEncodeFailed
        }
        try validateSize(of: data)

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try data.write(to: snapshotURL, options: writingOptions)
        } catch {
            throw KeyboardBridgeStoreError.snapshotWriteFailed
        }
    }

    private func storedHeaderForReplacement() throws -> SnapshotHeader? {
        guard let data = try storedData() else {
            return nil
        }

        let header = try decodeHeader(from: data)
        guard header.schemaVersion == 1 ||
                header.schemaVersion == 2 ||
                header.schemaVersion == KeyboardBridgeSnapshot.currentSchemaVersion else {
            throw KeyboardBridgeStoreError.incompatibleSchemaVersion(
                found: header.schemaVersion,
                supported: KeyboardBridgeSnapshot.currentSchemaVersion
            )
        }

        return header
    }

    private func storedLegacyHeaderForCutover() throws -> SnapshotHeader? {
        guard let data = try storedData(
            maximumBytes: Self.maximumLegacySnapshotBytes
        ) else {
            return nil
        }

        let header = try decodeHeader(from: data)
        guard header.schemaVersion == 1 || header.schemaVersion == 2 else {
            return nil
        }
        return header
    }

    /// A malformed or oversized cache has no trustworthy revision and may be
    /// atomically replaced from canonical app state. Read failures and future
    /// schema versions remain fail-closed.
    private func replacementHeader() throws -> SnapshotHeader? {
        do {
            return try storedHeaderForReplacement()
        } catch let error as KeyboardBridgeStoreError {
            switch error {
            case .snapshotDecodeFailed, .snapshotTooLarge:
                return nil
            default:
                throw error
            }
        }
    }

    private func storedData() throws -> Data? {
        try storedData(
            maximumBytes: KeyboardBridgeConfiguration.maximumSnapshotBytes
        )
    }

    private func storedData(maximumBytes: Int) throws -> Data? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            return nil
        }

        if let attributes = try? fileManager.attributesOfItem(
            atPath: snapshotURL.path
        ),
           let size = attributes[.size] as? NSNumber,
           size.intValue > maximumBytes {
            throw KeyboardBridgeStoreError.snapshotTooLarge(
                maximumBytes: maximumBytes,
                actualBytes: size.intValue
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: snapshotURL)
        } catch {
            throw KeyboardBridgeStoreError.snapshotReadFailed
        }
        try validateSize(of: data, maximumBytes: maximumBytes)
        return data
    }

    private func decodeHeader(from data: Data) throws -> SnapshotHeader {
        do {
            return try decoder.decode(SnapshotHeader.self, from: data)
        } catch {
            throw KeyboardBridgeStoreError.snapshotDecodeFailed
        }
    }

    private func validateSize(of data: Data) throws {
        try validateSize(
            of: data,
            maximumBytes: KeyboardBridgeConfiguration.maximumSnapshotBytes
        )
    }

    private func validateSize(
        of data: Data,
        maximumBytes: Int
    ) throws {
        guard data.count <= maximumBytes else {
            throw KeyboardBridgeStoreError.snapshotTooLarge(
                maximumBytes: maximumBytes,
                actualBytes: data.count
            )
        }
    }

    private var snapshotURL: URL {
        directoryURL.appendingPathComponent(
            KeyboardBridgeConfiguration.snapshotFilename,
            isDirectory: false
        )
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
