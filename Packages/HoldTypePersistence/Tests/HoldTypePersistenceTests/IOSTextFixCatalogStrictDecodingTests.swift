import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSTextFixCatalogStrictDecodingTests {
    @Test func malformedRootsSchemasAndDuplicateMembersPreserveSource() async {
        let fixtures: [(Data, IOSTextFixCatalogRepositoryError)] = [
            (Data("not-json".utf8), .malformedData),
            (Data("[]".utf8), .topLevelNotObject),
            (Data("null".utf8), .topLevelNotObject),
            (
                Data(#"{"actions":[]}"#.utf8),
                .missingRequiredValue(path: "schemaVersion")
            ),
            (
                Data(#"{"actions":[],"schemaVersion":1.0}"#.utf8),
                .invalidValueType(path: "schemaVersion")
            ),
            (
                Data(#"{"actions":[],"schemaVersion":true}"#.utf8),
                .invalidValueType(path: "schemaVersion")
            ),
            (
                Data(
                    #"{"actions":[],"future":"PRIVATE","schemaVersion":2}"#.utf8
                ),
                .unsupportedSchemaVersion
            ),
            (
                Data(
                    #"{"actions":[],"schemaVersion":1,"schema\u0056ersion":1}"#.utf8
                ),
                .malformedData
            ),
            (
                Data(#"{"actions":[],"future":"PRIVATE","schemaVersion":1}"#.utf8),
                .unexpectedFields(path: "$")
            ),
        ]

        for (data, error) in fixtures {
            await expectLoadFailure(data: data, expectedError: error)
        }
    }

    @Test func exactActionFieldsAndTypesAreRequiredAndUnknownValuesFailClosed()
        async throws {
        let custom = try textFixActionObject(makeCustomTextFixAction())
        let fixtures: [(Data, IOSTextFixCatalogRepositoryError)] = [
            (
                try textFixRootData(actions: nil),
                .missingRequiredValue(path: "actions")
            ),
            (
                Data(#"{"actions":{},"schemaVersion":1}"#.utf8),
                .invalidValueType(path: "actions")
            ),
            (
                try textFixRootData(actions: ["not-an-object"]),
                .invalidValueType(path: "actions")
            ),
            (
                try textFixRootData(actions: [
                    textFixBuiltInActionObjects()[0],
                    textFixBuiltInActionObjects()[1],
                    replacingTextFixField(
                        custom,
                        key: "kind",
                        value: "future-private-kind"
                    ),
                ]),
                .invalidValue(path: "actions[2].kind")
            ),
            (
                try textFixRootData(actions: [
                    textFixBuiltInActionObjects()[0],
                    textFixBuiltInActionObjects()[1],
                    replacingTextFixField(
                        custom,
                        key: "icon",
                        value: "future-private-icon"
                    ),
                ]),
                .invalidValue(path: "actions[2].icon")
            ),
            (
                try textFixRootData(actions: [
                    textFixBuiltInActionObjects()[0],
                    textFixBuiltInActionObjects()[1],
                    replacingTextFixField(
                        custom,
                        key: "isEnabled",
                        value: "true"
                    ),
                ]),
                .invalidValueType(path: "actions[2].isEnabled")
            ),
            (
                try textFixRootData(actions: [
                    textFixBuiltInActionObjects()[0],
                    textFixBuiltInActionObjects()[1],
                    replacingTextFixField(
                        custom,
                        key: "prompt",
                        value: NSNull()
                    ),
                ]),
                .invalidValueType(path: "actions[2].prompt")
            ),
            (
                try textFixRootData(actions: [
                    textFixBuiltInActionObjects()[0],
                    textFixBuiltInActionObjects()[1],
                    replacingTextFixField(
                        custom,
                        key: "future-private-field",
                        value: "secret"
                    ),
                ]),
                .unexpectedFields(path: "actions[2]")
            ),
        ]

        for (data, error) in fixtures {
            await expectLoadFailure(data: data, expectedError: error)
        }

        var missingID = custom
        missingID.removeValue(forKey: "id")
        await expectLoadFailure(
            data: try textFixRootData(actions: [
                textFixBuiltInActionObjects()[0],
                textFixBuiltInActionObjects()[1],
                missingID,
            ]),
            expectedError: .missingRequiredValue(path: "actions[2].id")
        )
    }

    @Test func domainValidationRejectsInvalidPayloadsDuplicatesCountsAndOrder()
        async throws {
        let builtIns = textFixBuiltInActionObjects()
        let custom = try textFixActionObject(makeCustomTextFixAction())
        let invalidActions: [[Any]] = [
            [],
            [builtIns[1], builtIns[0]],
            [
                builtIns[0],
                builtIns[1],
                replacingTextFixField(
                    custom,
                    key: "prompt",
                    value: " \n\t "
                ),
            ],
            [
                builtIns[0],
                builtIns[1],
                removingTextFixField(custom, key: "prompt"),
            ],
            [
                replacingTextFixField(
                    builtIns[0],
                    key: "isEnabled",
                    value: false
                ),
                builtIns[1],
            ],
            [
                replacingTextFixField(
                    builtIns[0],
                    key: "title",
                    value: "Renamed Translate"
                ),
                builtIns[1],
            ],
            [
                builtIns[0],
                replacingTextFixField(
                    builtIns[1],
                    key: "icon",
                    value: TextFixIcon.custom.rawValue
                ),
            ],
            [
                builtIns[0],
                builtIns[1],
                custom,
                custom,
            ],
        ]
        let expected: [IOSTextFixCatalogRepositoryError] = [
            .invalidCatalog,
            .invalidCatalog,
            .invalidValue(path: "actions[2]"),
            .invalidValue(path: "actions[2]"),
            .invalidValue(path: "actions[0]"),
            .invalidValue(path: "actions[0]"),
            .invalidValue(path: "actions[1]"),
            .invalidCatalog,
        ]

        for (actions, error) in zip(invalidActions, expected) {
            await expectLoadFailure(
                data: try textFixRootData(actions: actions),
                expectedError: error
            )
        }

        let overlongTitle = String(
            repeating: "a",
            count: TextFixAction.maximumTitleCharacterCount + 1
        )
        try await expectInvalidAction(
            replacingTextFixField(
                custom,
                key: "title",
                value: overlongTitle
            )
        )
        let oversizedPrompt = String(
            repeating: "a",
            count: TextFixAction.maximumPromptUTF8ByteCount + 1
        )
        try await expectInvalidAction(
            replacingTextFixField(
                custom,
                key: "prompt",
                value: oversizedPrompt
            )
        )

        let tooManyCustomActions = (0..<99).map { index -> Any in
            replacingTextFixField(
                custom,
                key: "id",
                value: "custom.\(index)"
            )
        }
        await expectLoadFailure(
            data: try textFixRootData(
                actions: builtIns.map { $0 as Any } + tooManyCustomActions
            ),
            expectedError: .invalidCatalog
        )
    }

    @Test func oneMiBSourceCeilingFailsBeforeDecodeAndNeverRewrites() async {
        let data = Data(
            repeating: 0x20,
            count: IOSTextFixCatalogRepository.maximumByteCount + 1
        )

        await expectLoadFailure(
            data: data,
            expectedError: .sourceTooLarge
        )
    }

    private func expectInvalidAction(_ action: [String: Any]) async throws {
        await expectLoadFailure(
            data: try textFixRootData(
                actions: textFixBuiltInActionObjects().map { $0 as Any }
                    + [action]
            ),
            expectedError: .invalidValue(path: "actions[2]")
        )
    }

    private func expectLoadFailure(
        data: Data,
        expectedError: IOSTextFixCatalogRepositoryError
    ) async {
        let fileSystem = TextFixCatalogFileSystemFake(data: data)
        do {
            _ = try await makeTextFixCatalogRepository(
                fileSystem: fileSystem
            ).load()
            Issue.record("Expected \(expectedError)")
        } catch let error as IOSTextFixCatalogRepositoryError {
            #expect(error == expectedError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(fileSystem.data == data)
        #expect(fileSystem.replacementCallCount == 0)
    }

}
