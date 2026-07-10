import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSTranscriptionUsageRepositoryTests {
    @Test func storageLocationAndPolicyAreStablePrivateAndBounded() async throws {
        let applicationSupportURL = URL(
            fileURLWithPath: "/private/app/Library/Application Support",
            isDirectory: true
        )
        let expectedURL = applicationSupportURL
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("ios-transcription-usage.json")
        #expect(
            IOSTranscriptionUsageStorageLocation.fileURL(in: applicationSupportURL) ==
                expectedURL
        )
        #expect(IOSTranscriptionUsageStorageLocation.directoryName == "HoldType")
        #expect(
            IOSTranscriptionUsageStorageLocation.fileName ==
                "ios-transcription-usage.json"
        )
        #expect(IOSTranscriptionUsageRepository.maximumByteCount == 4 * 1_024 * 1_024)
        #expect(IOSTranscriptionUsageRepository.retentionDayCount == 365)

        let fileSystem = UsageFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)
        #expect(try await repository.load().isEmpty)
        #expect(fileSystem.replacementCallCount == 0)
        #expect(fileSystem.removalCallCount == 0)
        let readPolicy = try #require(fileSystem.readPolicies.last)
        #expect(readPolicy.maximumByteCount == 4 * 1_024 * 1_024)
        #expect(readPolicy.fileProtection == .complete)
        #expect(readPolicy.excludesFromBackup)

        _ = try await repository.record(usage(id: "10000000-0000-0000-0000-000000000000"))
        let replacementPolicy = try #require(fileSystem.replacementPolicies.last)
        #expect(replacementPolicy.maximumByteCount == 4 * 1_024 * 1_024)
        #expect(replacementPolicy.fileProtection == .complete)
        #expect(replacementPolicy.excludesFromBackup)
    }

    @Test func recordWritesCanonicalV1AndExplicitUnknownPriceNulls() async throws {
        let clock = UsageClock(
            Date(timeIntervalSince1970: 1_752_148_496.987_654)
        )
        let fileSystem = UsageFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem, clock: clock)
        let id = "11111111-1111-1111-1111-111111111111"

        #expect(
            try await repository.record(
                usage(id: id, model: " Custom-Model ", duration: 90)
            ) == .inserted
        )

        let data = try #require(fileSystem.data)
        let expectedJSON = #"{"events":[{"durationSeconds":90,"estimatedCostUSD":null,"id":"11111111-1111-1111-1111-111111111111","model":"custom-model","priceUSDPerMinute":null,"pricingSource":null,"timestamp":"2025-07-10T11:54:56.988Z"}],"schemaVersion":1}"#
        #expect(
            String(decoding: data, as: UTF8.self) == expectedJSON
        )
        let loaded = try await repository.load()
        let event = try #require(loaded.first)
        #expect(loaded.count == 1)
        #expect(event.timestamp == canonicalDate("2025-07-10T11:54:56.988Z"))
        #expect(event.model == "custom-model")
        #expect(event.priceUSDPerMinute == nil)
        #expect(event.estimatedCostUSD == nil)
        #expect(event.pricingSource == nil)
    }

    @Test func recordFreezesKnownPriceAndAChangedTableAffectsOnlyNewRows() async throws {
        let clock = UsageClock(canonicalDate("2026-07-10T12:00:00.000Z"))
        let fileSystem = UsageFileSystemFake()
        let firstRepository = makeRepository(fileSystem: fileSystem, clock: clock)
        _ = try await firstRepository.record(
            usage(
                id: "20000000-0000-0000-0000-000000000000",
                model: "gpt-4o-transcribe",
                duration: 60
            )
        )

        clock.value = canonicalDate("2026-07-10T13:00:00.000Z")
        let changedPricing = try TranscriptionUsagePricing(
            ratesUSDPerMinute: ["gpt-4o-transcribe": 0.1],
            sourceLabel: "fixture pricing v2"
        )
        let secondRepository = makeRepository(
            fileSystem: fileSystem,
            clock: clock,
            pricing: changedPricing
        )
        _ = try await secondRepository.record(
            usage(
                id: "30000000-0000-0000-0000-000000000000",
                model: "gpt-4o-transcribe",
                duration: 60
            )
        )

        let events = try await secondRepository.load()
        #expect(events.map(\.priceUSDPerMinute) == [0.1, 0.006])
        #expect(events.map(\.estimatedCostUSD) == [0.1, 0.006])
        #expect(
            events.map(\.pricingSource) == [
                "fixture pricing v2",
                "OpenAI pricing reviewed 2026-06-22",
            ]
        )
    }

    @Test func newestFirstOrderUsesAscendingUUIDForEqualTimestamps() async throws {
        let clock = UsageClock(canonicalDate("2026-07-10T12:00:00.000Z"))
        let fileSystem = UsageFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem, clock: clock)
        let ids = [
            "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
            "00000000-0000-0000-0000-000000000001",
            "80000000-0000-0000-0000-000000000000",
        ]
        for id in ids {
            _ = try await repository.record(usage(id: id))
        }

        #expect(
            try await repository.load().map(\.id.uuidString) == [
                "00000000-0000-0000-0000-000000000001",
                "80000000-0000-0000-0000-000000000000",
                "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
            ]
        )
    }

    @Test func duplicateIsFirstFrozenAndWritesOnlyRequiredCompaction() async throws {
        let now = canonicalDate("2026-07-10T12:00:00.000Z")
        let clock = UsageClock(now)
        let fileSystem = UsageFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem, clock: clock)
        let id = "40000000-0000-0000-0000-000000000000"

        #expect(try await repository.record(usage(id: id, duration: 30)) == .inserted)
        let firstData = try #require(fileSystem.data)
        let firstReplacementCount = fileSystem.replacementCallCount
        clock.value = canonicalDate("2026-07-11T12:00:00.000Z")
        #expect(try await repository.record(usage(id: id, duration: 90)) == .duplicate)
        #expect(fileSystem.data == firstData)
        #expect(fileSystem.replacementCallCount == firstReplacementCount)
        #expect(try await repository.load().first?.durationSeconds == 30)

        let stale = eventObject(
            id: "50000000-0000-0000-0000-000000000000",
            timestamp: "2025-01-01T00:00:00.000Z"
        )
        let retained = eventObject(
            id: id,
            timestamp: "2026-07-10T12:00:00.000Z",
            duration: 30,
            cost: 0.003
        )
        fileSystem.data = try fixtureData(events: [retained, stale])
        let beforeCompaction = fileSystem.replacementCallCount

        #expect(try await repository.record(usage(id: id, duration: 120)) == .duplicate)
        #expect(fileSystem.replacementCallCount == beforeCompaction + 1)
        #expect(try await repository.load().map(\.id.uuidString) == [id])
    }

    @Test func anExpiredSameIDIsOutsideTheBoundedIdempotencyWindow() async throws {
        let id = "60000000-0000-0000-0000-000000000000"
        let expired = eventObject(
            id: id,
            timestamp: "2025-01-01T00:00:00.000Z",
            duration: 30,
            cost: 0.003
        )
        let source = try fixtureData(events: [expired])
        let fileSystem = UsageFileSystemFake(data: source)
        let repository = makeRepository(fileSystem: fileSystem)

        #expect(try await repository.record(usage(id: id, duration: 90)) == .inserted)
        #expect(fileSystem.replacementCallCount == 1)
        let loaded = try await repository.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.durationSeconds == 90)
    }

    @Test func retentionUsesCalendarDaysAcrossSpringForwardAndFallBack() async throws {
        let calendar = pacificCalendar()
        let scenarios = [
            (year: 2026, month: 3, day: 9),
            (year: 2026, month: 11, day: 2),
        ]

        for scenario in scenarios {
            let now = date(
                year: scenario.year,
                month: scenario.month,
                day: scenario.day,
                hour: 12,
                calendar: calendar
            )
            let cutoff = try #require(
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: calendar.startOfDay(for: now)
                )
            )
            let justExpired = cutoff.addingTimeInterval(-0.001)
            let future = now.addingTimeInterval(10 * 24 * 60 * 60)
            let rows = [
                eventObject(
                    id: "70000000-0000-0000-0000-000000000000",
                    timestamp: timestampString(future)
                ),
                eventObject(
                    id: "71000000-0000-0000-0000-000000000000",
                    timestamp: timestampString(cutoff)
                ),
                eventObject(
                    id: "72000000-0000-0000-0000-000000000000",
                    timestamp: timestampString(justExpired)
                ),
            ]
            let fileSystem = UsageFileSystemFake(data: try fixtureData(events: rows))
            let repository = makeRepository(
                fileSystem: fileSystem,
                clock: UsageClock(now),
                calendar: calendar,
                retentionDayCount: 2
            )

            let loaded = try await repository.load()
            #expect(
                loaded.map(\.id.uuidString) == [
                    "70000000-0000-0000-0000-000000000000",
                    "71000000-0000-0000-0000-000000000000",
                ]
            )
            #expect(fileSystem.replacementCallCount == 1)
            #expect(fileSystem.removalCallCount == 0)
        }
    }

    @Test func loadRemovesExistingEmptyOrEntirelyExpiredFiles() async throws {
        let emptySource = try fixtureData(events: [])
        let emptyFileSystem = UsageFileSystemFake(data: emptySource)
        let emptyRepository = makeRepository(fileSystem: emptyFileSystem)
        #expect(try await emptyRepository.load().isEmpty)
        #expect(emptyFileSystem.data == nil)
        #expect(emptyFileSystem.removalCallCount == 1)

        let expiredSource = try fixtureData(events: [
            eventObject(
                id: "73000000-0000-0000-0000-000000000000",
                timestamp: "2025-01-01T00:00:00.000Z"
            ),
        ])
        let expiredFileSystem = UsageFileSystemFake(data: expiredSource)
        let expiredRepository = makeRepository(fileSystem: expiredFileSystem)
        #expect(try await expiredRepository.load().isEmpty)
        #expect(expiredFileSystem.data == nil)
        #expect(expiredFileSystem.removalCallCount == 1)
    }

    @Test func compactionFailuresAreSurfacedAndPreserveSource() async throws {
        let retained = eventObject(
            id: "74000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T11:00:00.000Z"
        )
        let expired = eventObject(
            id: "75000000-0000-0000-0000-000000000000",
            timestamp: "2025-01-01T00:00:00.000Z"
        )
        let source = try fixtureData(events: [retained, expired])
        let replaceFailureFileSystem = UsageFileSystemFake(data: source)
        replaceFailureFileSystem.replacementFailure = .writeFailed
        let replaceFailureRepository = makeRepository(fileSystem: replaceFailureFileSystem)

        await expectError(.compactionFailed) {
            _ = try await replaceFailureRepository.load()
        }
        #expect(replaceFailureFileSystem.data == source)

        let duplicateFailureFileSystem = UsageFileSystemFake(data: source)
        duplicateFailureFileSystem.replacementFailure = .writeFailed
        let duplicateFailureRepository = makeRepository(
            fileSystem: duplicateFailureFileSystem
        )
        await expectError(.compactionFailed) {
            _ = try await duplicateFailureRepository.record(
                usage(id: "74000000-0000-0000-0000-000000000000")
            )
        }
        #expect(duplicateFailureFileSystem.data == source)

        let removeSource = try fixtureData(events: [expired])
        let removeFailureFileSystem = UsageFileSystemFake(data: removeSource)
        removeFailureFileSystem.removalFailure = .removeFailed
        let removeFailureRepository = makeRepository(fileSystem: removeFailureFileSystem)
        await expectError(.compactionFailed) {
            _ = try await removeFailureRepository.load()
        }
        #expect(removeFailureFileSystem.data == removeSource)
    }

    @Test func strictWireRejectsCorruptionAndPreservesEverySource() async throws {
        let canonical = eventObject(
            id: "80000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T12:00:00.000Z"
        )
        var missingField = canonical
        missingField.removeValue(forKey: "durationSeconds")
        var extraField = canonical
        extraField["transcript"] = "sensitive transcript"
        var lowerUUID = canonical
        lowerUUID["id"] = "80000000-0000-0000-0000-00000000000a"
        var noncanonicalModel = canonical
        noncanonicalModel["model"] = " GPT-4O-Transcribe "
        var zeroDuration = canonical
        zeroDuration["durationSeconds"] = 0
        var booleanDuration = canonical
        booleanDuration["durationSeconds"] = true
        var incompletePrice = canonical
        incompletePrice["estimatedCostUSD"] = NSNull()
        var incompleteRate = canonical
        incompleteRate["priceUSDPerMinute"] = NSNull()
        var incompleteSource = canonical
        incompleteSource["pricingSource"] = NSNull()
        var onlyRate = canonical
        onlyRate["estimatedCostUSD"] = NSNull()
        onlyRate["pricingSource"] = NSNull()
        var onlyCost = canonical
        onlyCost["priceUSDPerMinute"] = NSNull()
        onlyCost["pricingSource"] = NSNull()
        var onlySource = canonical
        onlySource["priceUSDPerMinute"] = NSNull()
        onlySource["estimatedCostUSD"] = NSNull()
        var booleanRate = canonical
        booleanRate["priceUSDPerMinute"] = true
        var negativeRate = canonical
        negativeRate["priceUSDPerMinute"] = -0.006
        negativeRate["estimatedCostUSD"] = 0.006
        var negativeCost = canonical
        negativeCost["estimatedCostUSD"] = -0.006
        var inconsistentCost = canonical
        inconsistentCost["priceUSDPerMinute"] = 0.006
        inconsistentCost["estimatedCostUSD"] = 1
        inconsistentCost["pricingSource"] = "source"
        var noncanonicalSource = canonical
        noncanonicalSource["priceUSDPerMinute"] = 0.006
        noncanonicalSource["estimatedCostUSD"] = 0.006
        noncanonicalSource["pricingSource"] = " source "
        var blankSource = canonical
        blankSource["pricingSource"] = " \n "

        let fixtures: [(Data, IOSTranscriptionUsageRepositoryError)] = [
            (Data("not-json".utf8), .malformedData),
            (Data("[]".utf8), .topLevelNotObject),
            (Data(#"{"events":[]}"#.utf8), .missingSchemaVersion),
            (Data(#"{"events":[],"schemaVersion":2}"#.utf8), .unsupportedSchemaVersion),
            (Data(#"{"events":[],"schemaVersion":true}"#.utf8), .invalidFieldType),
            (Data(#"{"events":[],"schemaVersion":1.0}"#.utf8), .invalidFieldType),
            (Data(#"{"events":[],"schemaVersion":1.5}"#.utf8), .invalidFieldType),
            (
                Data(#"{"events":[],"schemaVersion":9223372036854775808}"#.utf8),
                .invalidFieldType
            ),
            (Data(#"{"events":[],"extra":0,"schemaVersion":1}"#.utf8), .invalidRootFields),
            (Data(#"{"schemaVersion":1}"#.utf8), .invalidRootFields),
            (try fixtureData(events: [missingField]), .invalidEventFields),
            (try fixtureData(events: [extraField]), .invalidEventFields),
            (try fixtureData(events: [lowerUUID]), .invalidIdentifier),
            (try fixtureData(events: [noncanonicalModel]), .invalidEvent),
            (try fixtureData(events: [zeroDuration]), .invalidEvent),
            (try fixtureData(events: [booleanDuration]), .invalidFieldType),
            (try fixtureData(events: [incompletePrice]), .invalidEvent),
            (try fixtureData(events: [incompleteRate]), .invalidEvent),
            (try fixtureData(events: [incompleteSource]), .invalidEvent),
            (try fixtureData(events: [onlyRate]), .invalidEvent),
            (try fixtureData(events: [onlyCost]), .invalidEvent),
            (try fixtureData(events: [onlySource]), .invalidEvent),
            (try fixtureData(events: [booleanRate]), .invalidFieldType),
            (try fixtureData(events: [negativeRate]), .invalidEvent),
            (try fixtureData(events: [negativeCost]), .invalidEvent),
            (try fixtureData(events: [inconsistentCost]), .invalidEvent),
            (try fixtureData(events: [noncanonicalSource]), .invalidEvent),
            (try fixtureData(events: [blankSource]), .invalidEvent),
        ]

        for (source, expectedError) in fixtures {
            let fileSystem = UsageFileSystemFake(data: source)
            let repository = makeRepository(fileSystem: fileSystem)
            await expectError(expectedError) {
                _ = try await repository.load()
            }
            #expect(fileSystem.data == source)
            #expect(fileSystem.replacementCallCount == 0)
            #expect(fileSystem.removalCallCount == 0)
        }
    }

    @Test func timestampUUIDDuplicateAndOrderFormsAreStrict() async throws {
        let id = "90000000-0000-0000-0000-000000000000"
        let invalidTimestamps = [
            "2026-07-10T12:00:00Z",
            "2026-07-10T12:00:00.00Z",
            "2026-07-10T12:00:00.0000Z",
            "2026-07-10T12:00:00.000+00:00",
            "0000-07-10T12:00:00.000Z",
            "10000-07-10T12:00:00.000Z",
        ]
        for timestamp in invalidTimestamps {
            let source = try fixtureData(events: [
                eventObject(id: id, timestamp: timestamp),
            ])
            let fileSystem = UsageFileSystemFake(data: source)
            let repository = makeRepository(fileSystem: fileSystem)
            await expectError(.invalidTimestamp) {
                _ = try await repository.load()
            }
            #expect(fileSystem.data == source)
        }

        let first = eventObject(
            id: id,
            timestamp: "2026-07-10T12:00:00.000Z"
        )
        let duplicateSource = try fixtureData(events: [first, first])
        let duplicateFileSystem = UsageFileSystemFake(data: duplicateSource)
        let duplicateRepository = makeRepository(fileSystem: duplicateFileSystem)
        await expectError(.duplicateIdentifier) {
            _ = try await duplicateRepository.load()
        }

        let olderFirst = eventObject(
            id: "A0000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-09T12:00:00.000Z"
        )
        let newerSecond = eventObject(
            id: "B0000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T12:00:00.000Z"
        )
        let outOfOrderData = try fixtureData(events: [olderFirst, newerSecond])
        let orderFileSystem = UsageFileSystemFake(data: outOfOrderData)
        let orderRepository = makeRepository(fileSystem: orderFileSystem)
        await expectError(.invalidEventOrder) {
            _ = try await orderRepository.load()
        }

        let largerEqualID = eventObject(
            id: "F0000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T12:00:00.000Z"
        )
        let smallerEqualID = eventObject(
            id: "10000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T12:00:00.000Z"
        )
        let equalOrderData = try fixtureData(events: [largerEqualID, smallerEqualID])
        let equalOrderFileSystem = UsageFileSystemFake(data: equalOrderData)
        let equalOrderRepository = makeRepository(fileSystem: equalOrderFileSystem)
        await expectError(.invalidEventOrder) {
            _ = try await equalOrderRepository.load()
        }
    }

    @Test func exactSourceLimitIsAcceptedAndOneByteMoreFailsBeforeDecode() async throws {
        let limit = IOSTranscriptionUsageRepository.maximumByteCount
        let validPrefix = try fixtureData(events: [])
        let exactData = validPrefix + Data(repeating: 0x20, count: limit - validPrefix.count)
        let exactFileSystem = UsageFileSystemFake(data: exactData)
        let exactRepository = makeRepository(fileSystem: exactFileSystem)
        #expect(try await exactRepository.load().isEmpty)
        #expect(exactFileSystem.readPolicies.last?.maximumByteCount == limit)

        let oversizedData = exactData + Data([0x20])
        let oversizedFileSystem = UsageFileSystemFake(data: oversizedData)
        let oversizedRepository = makeRepository(fileSystem: oversizedFileSystem)
        await expectError(.sourceTooLarge) {
            _ = try await oversizedRepository.load()
        }
        #expect(oversizedFileSystem.data == oversizedData)
        #expect(oversizedFileSystem.replacementCallCount == 0)
        #expect(oversizedFileSystem.removalCallCount == 0)
    }

    @Test func exactFourMiBEncodingIsAcceptedAndOneByteMorePreservesSource() async throws {
        let limit = IOSTranscriptionUsageRepository.maximumByteCount
        let existing = eventObject(
            id: "A0100000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T11:00:00.000Z"
        )
        let source = try fixtureData(events: [existing])
        let generatorFileSystem = UsageFileSystemFake(data: source)
        let generatorRepository = makeRepository(fileSystem: generatorFileSystem)
        _ = try await generatorRepository.record(
            usage(
                id: "A0200000-0000-0000-0000-000000000000",
                model: "x"
            )
        )
        let baseline = try #require(generatorFileSystem.data)
        let addedModelByteCount = limit - baseline.count
        #expect(addedModelByteCount > 0)
        let exactModel = "x" + String(repeating: "x", count: addedModelByteCount)

        let exactFileSystem = UsageFileSystemFake(data: source)
        let exactRepository = makeRepository(fileSystem: exactFileSystem)
        #expect(
            try await exactRepository.record(
                usage(
                    id: "A0200000-0000-0000-0000-000000000000",
                    model: exactModel
                )
            ) == .inserted
        )
        #expect(exactFileSystem.data?.count == limit)

        let overflowFileSystem = UsageFileSystemFake(data: source)
        let overflowRepository = makeRepository(fileSystem: overflowFileSystem)
        await expectError(.encodedDataTooLarge) {
            _ = try await overflowRepository.record(
                usage(
                    id: "A0200000-0000-0000-0000-000000000000",
                    model: exactModel + "x"
                )
            )
        }
        #expect(overflowFileSystem.data == source)
        #expect(overflowFileSystem.replacementCallCount == 0)
    }

    @Test func encodedOverflowPreservesEveryValidWithinWindowRow() async throws {
        let existing = eventObject(
            id: "A1000000-0000-0000-0000-000000000000",
            timestamp: "2026-07-10T11:00:00.000Z"
        )
        let source = try fixtureData(events: [existing])
        let limit = source.count + 100
        let fileSystem = UsageFileSystemFake(data: source)
        let repository = makeRepository(
            fileSystem: fileSystem,
            maximumByteCount: limit
        )
        let largeModel = String(repeating: "x", count: 1_000)

        await expectError(.encodedDataTooLarge) {
            _ = try await repository.record(
                usage(
                    id: "A2000000-0000-0000-0000-000000000000",
                    model: largeModel
                )
            )
        }
        #expect(fileSystem.data == source)
        #expect(fileSystem.replacementCallCount == 0)
        #expect(try await repository.load().map(\.id.uuidString) == [
            "A1000000-0000-0000-0000-000000000000",
        ])
    }

    @Test func resetIsDirectIdempotentTypedAndCanRemoveCorruptSource() async throws {
        let corrupt = Data("credential transcript prompt raw-audio".utf8)
        let fileSystem = UsageFileSystemFake(data: corrupt)
        let repository = makeRepository(fileSystem: fileSystem)

        try await repository.reset()
        #expect(fileSystem.data == nil)
        try await repository.reset()
        #expect(fileSystem.removalCallCount == 2)

        fileSystem.data = corrupt
        fileSystem.removalFailure = .removeFailed
        await expectError(.resetFailed) {
            try await repository.reset()
        }
        #expect(fileSystem.data == corrupt)
    }

    @Test func readAndInsertionFailuresAreTypedAndPreserveSource() async throws {
        let source = try fixtureData(events: [
            eventObject(
                id: "A3000000-0000-0000-0000-000000000000",
                timestamp: "2026-07-10T11:00:00.000Z"
            ),
        ])
        let readFailureFileSystem = UsageFileSystemFake(data: source)
        readFailureFileSystem.readFailure = .readFailed
        let readFailureRepository = makeRepository(fileSystem: readFailureFileSystem)
        await expectError(.readFailed) {
            _ = try await readFailureRepository.load()
        }
        #expect(readFailureFileSystem.data == source)

        let writeFailureFileSystem = UsageFileSystemFake(data: source)
        writeFailureFileSystem.replacementFailure = .writeFailed
        let writeFailureRepository = makeRepository(fileSystem: writeFailureFileSystem)
        await expectError(.writeFailed) {
            _ = try await writeFailureRepository.record(
                usage(id: "A4000000-0000-0000-0000-000000000000")
            )
        }
        #expect(writeFailureFileSystem.data == source)
    }

    @Test func publicErrorsDoNotExposeStoredValuesOrPaths() async throws {
        let sensitiveValues = [
            "/private/container/ios-transcription-usage.json",
            "sk-sensitive-key",
            "sensitive transcript",
            "sensitive prompt",
        ]
        for error in [
            IOSTranscriptionUsageRepositoryError.readFailed,
            .malformedData,
            .invalidEvent,
            .writeFailed,
            .resetFailed,
        ] {
            var dumped = ""
            dump(error, to: &dumped)
            let renderings = [
                String(describing: error),
                String(reflecting: error),
                error.localizedDescription,
                dumped,
            ]
            for rendering in renderings {
                for sensitiveValue in sensitiveValues {
                    #expect(!rendering.contains(sensitiveValue))
                }
            }
        }
    }

    @Test func nonfiniteClockFailsBeforeReadingOrMutatingStorage() async throws {
        for interval in [Double.nan, .infinity, -.infinity] {
            let fileSystem = UsageFileSystemFake()
            let repository = makeRepository(
                fileSystem: fileSystem,
                clock: UsageClock(Date(timeIntervalSinceReferenceDate: interval))
            )
            await expectError(.invalidTimestamp) {
                _ = try await repository.record(
                    usage(id: "A5000000-0000-0000-0000-000000000000")
                )
            }
            #expect(fileSystem.readPolicies.isEmpty)
            #expect(fileSystem.replacementCallCount == 0)
            #expect(fileSystem.removalCallCount == 0)
        }
    }

    @Test func invalidInjectedRetentionCountFailsWithoutMutation() async throws {
        let fileSystem = UsageFileSystemFake(data: try fixtureData(events: []))
        let repository = makeRepository(
            fileSystem: fileSystem,
            retentionDayCount: 0
        )
        await expectError(.calendarCalculationFailed) {
            _ = try await repository.load()
        }
        #expect(fileSystem.replacementCallCount == 0)
        #expect(fileSystem.removalCallCount == 0)
    }

    @Test func actorSerializesConcurrentDistinctAndSameIDRecords() async throws {
        let distinctFileSystem = UsageFileSystemFake()
        let distinctRepository = makeRepository(fileSystem: distinctFileSystem)
        let distinctUsages = try (0..<24).map { index in
            try SuccessfulTranscriptionUsage(
                transcriptionID: identifier(String(format: "%08X-0000-0000-0000-%012X", index + 1, index + 1)),
                model: "gpt-4o-transcribe",
                audioDuration: 60
            )
        }

        let distinctResults = try await withThrowingTaskGroup(
            of: IOSTranscriptionUsageRecordResult.self
        ) { group in
            for usage in distinctUsages {
                group.addTask {
                    try await distinctRepository.record(usage)
                }
            }
            var results: [IOSTranscriptionUsageRecordResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        #expect(distinctResults.allSatisfy { $0 == .inserted })
        #expect(try await distinctRepository.load().count == distinctUsages.count)

        let sameFileSystem = UsageFileSystemFake()
        let sameRepository = makeRepository(fileSystem: sameFileSystem)
        let sameUsage = try usage(id: "B0000000-0000-0000-0000-000000000000")
        let sameResults = try await withThrowingTaskGroup(
            of: IOSTranscriptionUsageRecordResult.self
        ) { group in
            for _ in 0..<24 {
                group.addTask {
                    try await sameRepository.record(sameUsage)
                }
            }
            var results: [IOSTranscriptionUsageRecordResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        #expect(sameResults.filter { $0 == .inserted }.count == 1)
        #expect(sameResults.filter { $0 == .duplicate }.count == 23)
        #expect(sameFileSystem.replacementCallCount == 1)
        #expect(try await sameRepository.load().count == 1)
    }

    private func makeRepository(
        fileSystem: UsageFileSystemFake,
        clock: UsageClock? = nil,
        maximumByteCount: Int = IOSTranscriptionUsageRepository.maximumByteCount,
        pricing: TranscriptionUsagePricing = .current,
        calendar: Calendar? = nil,
        retentionDayCount: Int = IOSTranscriptionUsageRepository.retentionDayCount
    ) -> IOSTranscriptionUsageRepository {
        let resolvedClock = clock ?? UsageClock(
            canonicalDate("2026-07-10T12:00:00.000Z")
        )
        return IOSTranscriptionUsageRepository(
            fileURL: URL(fileURLWithPath: "/app-private/ios-transcription-usage.json"),
            fileSystem: fileSystem,
            maximumByteCount: maximumByteCount,
            pricing: pricing,
            calendar: calendar ?? utcCalendar(),
            retentionDayCount: retentionDayCount,
            now: { resolvedClock.value }
        )
    }

    private func usage(
        id: String,
        model: String = "gpt-4o-transcribe",
        duration: TimeInterval = 60
    ) throws -> SuccessfulTranscriptionUsage {
        try SuccessfulTranscriptionUsage(
            transcriptionID: identifier(id),
            model: model,
            audioDuration: duration
        )
    }

    private func identifier(_ string: String) throws -> UUID {
        try #require(UUID(uuidString: string))
    }

    private func eventObject(
        id: String,
        timestamp: String,
        model: String = "gpt-4o-transcribe",
        duration: Double = 60,
        price: Any = 0.006,
        cost: Any = 0.006,
        source: Any = "OpenAI pricing reviewed 2026-06-22"
    ) -> [String: Any] {
        [
            "id": id,
            "timestamp": timestamp,
            "model": model,
            "durationSeconds": duration,
            "priceUSDPerMinute": price,
            "estimatedCostUSD": cost,
            "pricingSource": source,
        ]
    }

    private func fixtureData(events: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 1, "events": events],
            options: [.sortedKeys]
        )
    }

    private func expectError(
        _ expected: IOSTranscriptionUsageRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected)")
        } catch let error as IOSTranscriptionUsageRepositoryError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func canonicalDate(_ string: String) -> Date {
        let formatter = timestampFormatter()
        return formatter.date(from: string) ?? Date(timeIntervalSince1970: 0)
    }

    private func timestampString(_ date: Date) -> String {
        timestampFormatter().string(from: date)
    }

    private func timestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.isLenient = false
        return formatter
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func pacificCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

private final class UsageClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Date

    init(_ value: Date) {
        storedValue = value
    }

    var value: Date {
        get {
            lock.withLock { storedValue }
        }
        set {
            lock.withLock { storedValue = newValue }
        }
    }
}

private final class UsageFileSystemFake:
    ProtectedAtomicMetadataFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedData: Data?
    private var storedReadPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementCallCount = 0
    private var storedRemovalCallCount = 0
    private var storedReadFailure: UsageFileSystemFakeError?
    private var storedReplacementFailure: UsageFileSystemFakeError?
    private var storedRemovalFailure: UsageFileSystemFakeError?

    init(data: Data? = nil) {
        storedData = data
    }

    var data: Data? {
        get { lock.withLock { storedData } }
        set { lock.withLock { storedData = newValue } }
    }

    var readPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReadPolicies }
    }

    var replacementPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReplacementPolicies }
    }

    var replacementCallCount: Int {
        lock.withLock { storedReplacementCallCount }
    }

    var removalCallCount: Int {
        lock.withLock { storedRemovalCallCount }
    }

    var replacementFailure: UsageFileSystemFakeError? {
        get { lock.withLock { storedReplacementFailure } }
        set { lock.withLock { storedReplacementFailure = newValue } }
    }

    var readFailure: UsageFileSystemFakeError? {
        get { lock.withLock { storedReadFailure } }
        set { lock.withLock { storedReadFailure = newValue } }
    }

    var removalFailure: UsageFileSystemFakeError? {
        get { lock.withLock { storedRemovalFailure } }
        set { lock.withLock { storedRemovalFailure = newValue } }
    }

    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        try lock.withLock {
            storedReadPolicies.append(policy)
            if let storedReadFailure {
                throw storedReadFailure
            }
            if let storedData, storedData.count > policy.maximumByteCount {
                throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
            }
            return storedData
        }
    }

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        try lock.withLock {
            storedReplacementCallCount += 1
            storedReplacementPolicies.append(policy)
            if let storedReplacementFailure {
                throw storedReplacementFailure
            }
            if data.count > policy.maximumByteCount {
                throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
            }
            storedData = data
        }
    }

    func removeFileIfPresent(at fileURL: URL) throws {
        try lock.withLock {
            storedRemovalCallCount += 1
            if let storedRemovalFailure {
                throw storedRemovalFailure
            }
            storedData = nil
        }
    }
}

private enum UsageFileSystemFakeError: Error {
    case readFailed
    case writeFailed
    case removeFailed
}
