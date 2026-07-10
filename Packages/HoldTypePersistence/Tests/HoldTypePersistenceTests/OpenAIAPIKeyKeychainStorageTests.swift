import Foundation
import Security
import Testing
@testable import HoldTypePersistence

private let testApplicationIdentifierAccessGroup = "TESTTEAMID.app.holdtype.HoldType.ios"

struct OpenAIAPIKeyKeychainStorageTests {
    @Test func savesANewNormalizedKeyUsingTheExactPrivateItemContract() async throws {
        let client = SecItemClientFake(
            updateStatuses: [errSecItemNotFound],
            addStatuses: [errSecSuccess]
        )
        let storage = try makeStorage(client: client)

        try await storage.saveOrReplaceAPIKey("  sk-package-secret\n")

        let calls = client.recordedCalls
        #expect(calls.map(\.kind) == [.update, .add])

        let updateCall = try #require(calls.first)
        assertExactIdentityQuery(updateCall.query)
        assertExactUpdateAttributes(updateCall.attributes, expectedText: "sk-package-secret")

        let addCall = try #require(calls.last)
        assertExactAddAttributes(addCall.attributes, expectedText: "sk-package-secret")
    }

    @Test func replacesByUpdateWithoutAddingOrDeleting() async throws {
        let client = SecItemClientFake(updateStatuses: [errSecSuccess])
        let storage = try makeStorage(client: client)

        try await storage.saveOrReplaceAPIKey("sk-replacement")

        let calls = client.recordedCalls
        #expect(calls.map(\.kind) == [.update])
        assertExactIdentityQuery(try #require(calls.first).query)
        assertExactUpdateAttributes(
            try #require(calls.first).attributes,
            expectedText: "sk-replacement"
        )
    }

    @Test func duplicateAddRaceRetriesTheStableUpdate() async throws {
        let client = SecItemClientFake(
            updateStatuses: [errSecItemNotFound, errSecSuccess],
            addStatuses: [errSecDuplicateItem]
        )
        let storage = try makeStorage(client: client)

        try await storage.saveOrReplaceAPIKey("sk-race")

        let calls = client.recordedCalls
        #expect(calls.map(\.kind) == [.update, .add, .update])
        assertExactIdentityQuery(try #require(calls.first).query)
        assertExactAddAttributes(calls[1].attributes, expectedText: "sk-race")
        assertExactIdentityQuery(try #require(calls.last).query)
    }

    @Test func addFailuresAreTypedWithoutAnyDeleteFallback() async throws {
        let lockedClient = SecItemClientFake(
            updateStatuses: [errSecItemNotFound],
            addStatuses: [errSecInteractionNotAllowed]
        )
        await expectError(
            .unavailableWhileLocked,
            from: try makeStorage(client: lockedClient)
        ) { storage in
            try await storage.saveOrReplaceAPIKey("sk-add-locked")
        }
        #expect(lockedClient.recordedCalls.map(\.kind) == [.update, .add])

        let failedClient = SecItemClientFake(
            updateStatuses: [errSecItemNotFound],
            addStatuses: [errSecNotAvailable]
        )
        await expectError(
            .keychainFailure,
            from: try makeStorage(client: failedClient)
        ) { storage in
            try await storage.saveOrReplaceAPIKey("sk-add-failed")
        }
        #expect(failedClient.recordedCalls.map(\.kind) == [.update, .add])
    }

    @Test func duplicateRaceRetryFailuresAreTypedAndStopAfterOneRetry() async throws {
        let lockedClient = SecItemClientFake(
            updateStatuses: [errSecItemNotFound, errSecInteractionNotAllowed],
            addStatuses: [errSecDuplicateItem]
        )
        await expectError(
            .unavailableWhileLocked,
            from: try makeStorage(client: lockedClient)
        ) { storage in
            try await storage.saveOrReplaceAPIKey("sk-race-locked")
        }
        #expect(lockedClient.recordedCalls.map(\.kind) == [.update, .add, .update])

        let failedClient = SecItemClientFake(
            updateStatuses: [errSecItemNotFound, errSecNotAvailable],
            addStatuses: [errSecDuplicateItem]
        )
        await expectError(
            .keychainFailure,
            from: try makeStorage(client: failedClient)
        ) { storage in
            try await storage.saveOrReplaceAPIKey("sk-race-failed")
        }
        #expect(failedClient.recordedCalls.map(\.kind) == [.update, .add, .update])
    }

    @Test func blankCandidateFailsBeforeAnySecItemCall() async throws {
        let client = SecItemClientFake()
        let storage = try makeStorage(client: client)

        do {
            try await storage.saveOrReplaceAPIKey(" \n\t ")
            Issue.record("Expected an empty-key failure")
        } catch let error as OpenAIAPIKeyKeychainStorageError {
            #expect(error == .emptyAPIKey)
        } catch {
            Issue.record("Unexpected error type")
        }

        #expect(client.recordedCalls.isEmpty)
    }

    @Test func loadsTheStableItemWithoutChangingItsProtectionContract() async throws {
        let client = SecItemClientFake(
            copyResults: [
                SecItemCopyResult(
                    status: errSecSuccess,
                    value: Data("  sk-loaded\n".utf8)
                ),
            ]
        )
        let storage = try makeStorage(client: client)

        #expect(try await storage.loadAPIKey() == "sk-loaded")

        let call = try #require(client.recordedCalls.first)
        #expect(call.kind == .copyMatching)
        assertExactLoadQuery(call.query)
    }

    @Test func missingItemLoadsAsNilAndRemoveIsIdempotent() async throws {
        let client = SecItemClientFake(
            copyResults: [SecItemCopyResult(status: errSecItemNotFound, value: nil)],
            deleteStatuses: [errSecItemNotFound, errSecSuccess]
        )
        let storage = try makeStorage(client: client)

        #expect(try await storage.loadAPIKey() == nil)
        try await storage.removeAPIKey()
        try await storage.removeAPIKey()

        let calls = client.recordedCalls
        #expect(calls.map(\.kind) == [.copyMatching, .delete, .delete])
        assertExactLoadQuery(try #require(calls.first).query)
        assertExactIdentityQuery(calls[1].query)
        assertExactIdentityQuery(try #require(calls.last).query)
    }

    @Test func lockedStatusIsTypedForEveryOperationPath() async throws {
        await expectError(
            .unavailableWhileLocked,
            from: try makeStorage(
                client: SecItemClientFake(updateStatuses: [errSecInteractionNotAllowed])
            )
        ) { storage in
            try await storage.saveOrReplaceAPIKey("sk-locked")
        }

        await expectError(
            .unavailableWhileLocked,
            from: try makeStorage(
                client: SecItemClientFake(
                    copyResults: [
                        SecItemCopyResult(status: errSecInteractionNotAllowed, value: nil),
                    ]
                )
            )
        ) { storage in
            _ = try await storage.loadAPIKey()
        }

        await expectError(
            .unavailableWhileLocked,
            from: try makeStorage(
                client: SecItemClientFake(deleteStatuses: [errSecInteractionNotAllowed])
            )
        ) { storage in
            try await storage.removeAPIKey()
        }
    }

    @Test func invalidSecItemResultAndStoredBytesHaveSeparateTypedFailures() async throws {
        await expectError(
            .invalidResult,
            from: try makeStorage(
                client: SecItemClientFake(
                    copyResults: [SecItemCopyResult(status: errSecSuccess, value: "not-data")]
                )
            )
        ) { storage in
            _ = try await storage.loadAPIKey()
        }

        await expectError(
            .invalidStoredAPIKey,
            from: try makeStorage(
                client: SecItemClientFake(
                    copyResults: [
                        SecItemCopyResult(status: errSecSuccess, value: Data([0xff])),
                    ]
                )
            )
        ) { storage in
            _ = try await storage.loadAPIKey()
        }

        await expectError(
            .invalidStoredAPIKey,
            from: try makeStorage(
                client: SecItemClientFake(
                    copyResults: [
                        SecItemCopyResult(status: errSecSuccess, value: Data(" \n".utf8)),
                    ]
                )
            )
        ) { storage in
            _ = try await storage.loadAPIKey()
        }
    }

    @Test func unsuccessfulReplacementDoesNotFallThroughToAddOrDelete() async throws {
        let client = SecItemClientFake(updateStatuses: [errSecNotAvailable])
        let storage = try makeStorage(client: client)

        await expectError(.keychainFailure, from: storage) { storage in
            try await storage.saveOrReplaceAPIKey("sk-preserve-existing")
        }

        #expect(client.recordedCalls.map(\.kind) == [.update])

        let unauthorizedClient = SecItemClientFake(updateStatuses: [errSecMissingEntitlement])
        let unauthorizedStorage = try makeStorage(client: unauthorizedClient)
        await expectError(.keychainFailure, from: unauthorizedStorage) { storage in
            try await storage.saveOrReplaceAPIKey("sk-unentitled-group")
        }
        #expect(unauthorizedClient.recordedCalls.map(\.kind) == [.update])
    }

    @Test func publicBoundaryIsSendableAndConstructionPerformsNoSecItemWork() throws {
        let client = SecItemClientFake()
        let storage = try makeStorage(client: client)

        requireSendable(OpenAIAPIKeyKeychainStorage.self)
        requireSendable(OpenAIAPIKeyKeychainStorageError.self)
        requireSendable(OpenAIAPIKeyStoring.self)
        _ = storage as any OpenAIAPIKeyStoring
        #expect(client.recordedCalls.isEmpty)
    }

    @Test func publicInitializerFailsClosedForEveryInvalidAppIdentity() throws {
        let invalidValues = [
            "",
            OpenAIAPIKeyKeychainStorage.containingAppBundleIdentifier,
            ".\(OpenAIAPIKeyKeychainStorage.containingAppBundleIdentifier)",
            "$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)",
            "group.app.holdtype.HoldType.shared",
            "group.app.holdtype.HoldType.ios",
            "TESTTEAMID.app.holdtype.HoldType.ios.keyboard",
            "TEST.TEAM.app.holdtype.HoldType.ios",
        ]

        for invalidValue in invalidValues {
            #expect(
                throws: OpenAIAPIKeyKeychainStorageError
                    .invalidApplicationIdentifierAccessGroup
            ) {
                _ = try OpenAIAPIKeyKeychainStorage(
                    applicationIdentifierAccessGroup: invalidValue
                )
            }
        }

        let storage = try OpenAIAPIKeyKeychainStorage(
            applicationIdentifierAccessGroup: testApplicationIdentifierAccessGroup
        )
        _ = storage as any OpenAIAPIKeyStoring
    }

    @Test func invalidAppIdentityFailsBeforeAnySecItemCall() {
        let client = SecItemClientFake()

        #expect(
            throws: OpenAIAPIKeyKeychainStorageError
                .invalidApplicationIdentifierAccessGroup
        ) {
            _ = try OpenAIAPIKeyKeychainStorage(
                client: client,
                applicationIdentifierAccessGroup: "group.app.holdtype.HoldType.shared"
            )
        }
        #expect(client.recordedCalls.isEmpty)
    }

    @Test func everyPublicErrorRenderingIsRedacted() {
        let forbiddenValues = [
            "sk-never-render-this",
            String(errSecInteractionNotAllowed),
            String(errSecNotAvailable),
            String(errSecMissingEntitlement),
        ]
        let errors: [OpenAIAPIKeyKeychainStorageError] = [
            .invalidApplicationIdentifierAccessGroup,
            .emptyAPIKey,
            .unavailableWhileLocked,
            .invalidResult,
            .invalidStoredAPIKey,
            .keychainFailure,
        ]

        for error in errors {
            let renderings = [
                error.description,
                error.debugDescription,
                error.localizedDescription,
                String(describing: error),
                String(reflecting: error),
            ]

            for rendering in renderings {
                for forbiddenValue in forbiddenValues {
                    #expect(!rendering.contains(forbiddenValue))
                }
            }
            #expect(error.customMirror.children.isEmpty)
        }
    }

    private func expectError(
        _ expectedError: OpenAIAPIKeyKeychainStorageError,
        from storage: OpenAIAPIKeyKeychainStorage,
        operation: (OpenAIAPIKeyKeychainStorage) async throws -> Void
    ) async {
        do {
            try await operation(storage)
            Issue.record("Expected \(expectedError)")
        } catch let error as OpenAIAPIKeyKeychainStorageError {
            #expect(error == expectedError)
        } catch {
            Issue.record("Unexpected error type")
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}

private func makeStorage(client: SecItemClientFake) throws -> OpenAIAPIKeyKeychainStorage {
    try OpenAIAPIKeyKeychainStorage(
        client: client,
        applicationIdentifierAccessGroup: testApplicationIdentifierAccessGroup
    )
}

private func assertExactIdentityQuery(_ query: [String: Any]?) {
    guard let query else {
        Issue.record("Expected an identity query")
        return
    }

    #expect(Set(query.keys) == [
        kSecClass as String,
        kSecAttrService as String,
        kSecAttrAccount as String,
        kSecAttrSynchronizable as String,
        kSecAttrAccessGroup as String,
    ])
    #expect((query[kSecClass as String] as? String) == (kSecClassGenericPassword as String))
    #expect(query[kSecAttrService as String] as? String == OpenAIAPIKeyKeychainStorage.service)
    #expect(query[kSecAttrAccount as String] as? String == OpenAIAPIKeyKeychainStorage.account)
    #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    assertExactApplicationIdentifierAccessGroup(query[kSecAttrAccessGroup as String])
}

private func assertExactLoadQuery(_ query: [String: Any]?) {
    guard let query else {
        Issue.record("Expected a load query")
        return
    }

    #expect(Set(query.keys) == [
        kSecClass as String,
        kSecAttrService as String,
        kSecAttrAccount as String,
        kSecAttrSynchronizable as String,
        kSecAttrAccessGroup as String,
        kSecReturnData as String,
        kSecMatchLimit as String,
    ])
    #expect((query[kSecClass as String] as? String) == (kSecClassGenericPassword as String))
    #expect(query[kSecAttrService as String] as? String == OpenAIAPIKeyKeychainStorage.service)
    #expect(query[kSecAttrAccount as String] as? String == OpenAIAPIKeyKeychainStorage.account)
    #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    #expect(query[kSecReturnData as String] as? Bool == true)
    #expect((query[kSecMatchLimit as String] as? String) == (kSecMatchLimitOne as String))
    assertExactApplicationIdentifierAccessGroup(query[kSecAttrAccessGroup as String])
}

private func assertExactAddAttributes(_ attributes: [String: Any]?, expectedText: String) {
    guard let attributes else {
        Issue.record("Expected add attributes")
        return
    }

    #expect(Set(attributes.keys) == [
        kSecClass as String,
        kSecAttrService as String,
        kSecAttrAccount as String,
        kSecAttrSynchronizable as String,
        kSecAttrAccessGroup as String,
        kSecAttrAccessible as String,
        kSecValueData as String,
    ])
    #expect((attributes[kSecClass as String] as? String) == (kSecClassGenericPassword as String))
    #expect(attributes[kSecAttrService as String] as? String == OpenAIAPIKeyKeychainStorage.service)
    #expect(attributes[kSecAttrAccount as String] as? String == OpenAIAPIKeyKeychainStorage.account)
    #expect(attributes[kSecAttrSynchronizable as String] as? Bool == false)
    #expect(
        (attributes[kSecAttrAccessible as String] as? String)
            == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    )
    #expect(
        (attributes[kSecValueData as String] as? Data).map { String(decoding: $0, as: UTF8.self) }
            == expectedText
    )
    assertExactApplicationIdentifierAccessGroup(attributes[kSecAttrAccessGroup as String])
}

private func assertExactUpdateAttributes(_ attributes: [String: Any]?, expectedText: String) {
    guard let attributes else {
        Issue.record("Expected update attributes")
        return
    }

    #expect(Set(attributes.keys) == [
        kSecValueData as String,
    ])
    #expect(
        (attributes[kSecValueData as String] as? Data).map { String(decoding: $0, as: UTF8.self) }
            == expectedText
    )
    #expect(attributes[kSecAttrAccessGroup as String] == nil)
}

private func assertExactApplicationIdentifierAccessGroup(_ value: Any?) {
    #expect(value as? String == testApplicationIdentifierAccessGroup)
    #expect(value as? String != "group.app.holdtype.HoldType.shared")
}

private final class SecItemClientFake: SecItemClient, @unchecked Sendable {
    struct Call {
        enum Kind: Equatable {
            case add
            case update
            case copyMatching
            case delete
        }

        let kind: Kind
        let query: [String: Any]?
        let attributes: [String: Any]?
    }

    private let lock = NSLock()
    private var calls: [Call] = []
    private var updateStatuses: [OSStatus]
    private var addStatuses: [OSStatus]
    private var copyResults: [SecItemCopyResult]
    private var deleteStatuses: [OSStatus]

    init(
        updateStatuses: [OSStatus] = [],
        addStatuses: [OSStatus] = [],
        copyResults: [SecItemCopyResult] = [],
        deleteStatuses: [OSStatus] = []
    ) {
        self.updateStatuses = updateStatuses
        self.addStatuses = addStatuses
        self.copyResults = copyResults
        self.deleteStatuses = deleteStatuses
    }

    var recordedCalls: [Call] {
        lock.withLock { calls }
    }

    func add(attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            calls.append(Call(kind: .add, query: nil, attributes: attributes))
            return addStatuses.isEmpty ? errSecSuccess : addStatuses.removeFirst()
        }
    }

    func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            calls.append(Call(kind: .update, query: query, attributes: attributes))
            return updateStatuses.isEmpty ? errSecSuccess : updateStatuses.removeFirst()
        }
    }

    func copyMatching(query: [String: Any]) -> SecItemCopyResult {
        lock.withLock {
            calls.append(Call(kind: .copyMatching, query: query, attributes: nil))
            return copyResults.isEmpty
                ? SecItemCopyResult(status: errSecItemNotFound, value: nil)
                : copyResults.removeFirst()
        }
    }

    func delete(query: [String: Any]) -> OSStatus {
        lock.withLock {
            calls.append(Call(kind: .delete, query: query, attributes: nil))
            return deleteStatuses.isEmpty ? errSecSuccess : deleteStatuses.removeFirst()
        }
    }
}
