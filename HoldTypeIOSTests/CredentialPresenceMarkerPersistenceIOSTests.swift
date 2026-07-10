import Foundation
import HoldTypePersistence
import Testing

struct CredentialPresenceMarkerPersistenceIOSTests {
    @Test func publicRuntimeContractWorksThroughANormalIOSImport() throws {
        let date = try fixtureDate()
        let marker = try CredentialPresenceMarker(
            state: .mutationInProgress,
            updatedAt: date,
            mutationKind: .saveOrReplace
        )

        #expect(marker.state == .mutationInProgress)
        #expect(marker.updatedAt == date)
        #expect(marker.mutationKind == .saveOrReplace)
        requireSendable(CredentialPresenceMarker.self)
        requireSendable(CredentialPresenceMarker.State.self)
        requireSendable(CredentialPresenceMarker.MutationKind.self)
        #expect(((marker as Any) is any Encodable) == false)
        #expect(((marker as Any) is any Decodable) == false)
    }

    @Test func publicRepositoryPersistsEveryExactV1Fixture() throws {
        let directoryURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("credential-presence-v1.json")
        let repository = CredentialPresenceMarkerRepository(fileURL: fileURL)
        let date = try fixtureDate()
        let fixtures = [
            try Fixture(
                marker: CredentialPresenceMarker(state: .present, updatedAt: date),
                json: #"{"schemaVersion":1,"state":"present","updatedAt":"2026-07-10T12:34:56.000Z"}"#
            ),
            try Fixture(
                marker: CredentialPresenceMarker(state: .absent, updatedAt: date),
                json: #"{"schemaVersion":1,"state":"absent","updatedAt":"2026-07-10T12:34:56.000Z"}"#
            ),
            try Fixture(
                marker: CredentialPresenceMarker(state: .unknown, updatedAt: date),
                json: #"{"schemaVersion":1,"state":"unknown","updatedAt":"2026-07-10T12:34:56.000Z"}"#
            ),
            try Fixture(
                marker: CredentialPresenceMarker(
                    state: .mutationInProgress,
                    updatedAt: date,
                    mutationKind: .saveOrReplace
                ),
                json: #"{"mutationKind":"saveOrReplace","schemaVersion":1,"state":"mutationInProgress","updatedAt":"2026-07-10T12:34:56.000Z"}"#
            ),
            try Fixture(
                marker: CredentialPresenceMarker(
                    state: .mutationInProgress,
                    updatedAt: date,
                    mutationKind: .remove
                ),
                json: #"{"mutationKind":"remove","schemaVersion":1,"state":"mutationInProgress","updatedAt":"2026-07-10T12:34:56.000Z"}"#
            ),
        ]

        for fixture in fixtures {
            try repository.save(fixture.marker)
            #expect(try Data(contentsOf: fileURL) == fixture.data)
            #expect(try repository.load() == fixture.marker)
        }

        let keys = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        ).keys
        #expect(Set(keys) == ["schemaVersion", "state", "updatedAt", "mutationKind"])

        let resourceValues = try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(resourceValues.isExcludedFromBackup == true)
    }

    @Test func missingAndInvalidFilesKeepTheirPublicSemanticsAndBytes() throws {
        let directoryURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("credential-presence-v1.json")
        let repository = CredentialPresenceMarkerRepository(fileURL: fileURL)

        #expect(try repository.load() == nil)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let cases: [(Data, CredentialPresenceMarkerRepositoryError)] = [
            (Data("not-json".utf8), .corruptData),
            (
                Data(#"{"schemaVersion":2,"state":"present","updatedAt":"2026-07-10T12:34:56.000Z"}"#.utf8),
                .unsupportedSchemaVersion
            ),
            (
                Data(#"{"schemaVersion":1,"state":"mutationInProgress","updatedAt":"2026-07-10T12:34:56.000Z"}"#.utf8),
                .invalidMutationCombination
            ),
        ]

        for (sourceData, expectedError) in cases {
            try sourceData.write(to: fileURL, options: .atomic)
            #expect(throws: expectedError) {
                _ = try repository.load()
            }
            #expect(try Data(contentsOf: fileURL) == sourceData)
        }
    }

    @Test func publicRepositoryReportsFailedReplacementWithoutChangingTheBlockingSource() throws {
        let directoryURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let blockingURL = directoryURL.appendingPathComponent("not-a-directory")
        let blockingBytes = Data("blocking-source".utf8)
        try blockingBytes.write(to: blockingURL)
        let repository = CredentialPresenceMarkerRepository(
            fileURL: blockingURL.appendingPathComponent("credential-presence-v1.json")
        )
        let marker = try CredentialPresenceMarker(
            state: .present,
            updatedAt: fixtureDate()
        )

        #expect(throws: CredentialPresenceMarkerRepositoryError.writeFailed) {
            try repository.save(marker)
        }
        #expect(try Data(contentsOf: blockingURL) == blockingBytes)
    }

    @Test func oversizedAndNonRegularSourcesAreRejectedWithoutChangingThem() throws {
        let directoryURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = directoryURL.appendingPathComponent("credential-presence-v1.json")
        let oversizedData = Data(repeating: 0x61, count: 16 * 1_024 + 1)
        try oversizedData.write(to: fileURL)
        let repository = CredentialPresenceMarkerRepository(fileURL: fileURL)

        #expect(throws: CredentialPresenceMarkerRepositoryError.storageLimitExceeded) {
            _ = try repository.load()
        }
        #expect(try Data(contentsOf: fileURL) == oversizedData)

        try FileManager.default.removeItem(at: fileURL)
        let sentinelURL = directoryURL.appendingPathComponent("sentinel")
        try Data("sentinel".utf8).write(to: sentinelURL)
        try FileManager.default.createSymbolicLink(
            at: fileURL,
            withDestinationURL: sentinelURL
        )
        #expect(throws: CredentialPresenceMarkerRepositoryError.readFailed) {
            _ = try repository.load()
        }
        #expect(try Data(contentsOf: sentinelURL) == Data("sentinel".utf8))
        #expect(
            try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path) ==
                sentinelURL.path
        )
    }

    private func makeTemporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-credential-marker-tests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func fixtureDate() throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try #require(
            formatter.date(from: "2026-07-10T12:34:56.000Z")
        )
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}

private struct Fixture {
    let marker: CredentialPresenceMarker
    let data: Data

    init(marker: CredentialPresenceMarker, json: String) throws {
        self.marker = marker
        self.data = Data(json.utf8)
    }
}
