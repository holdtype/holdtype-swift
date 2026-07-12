import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypeIOSCore

struct IOSFailedHistoryServiceTests {
    @Test func productionCompositionIsProcessOwnedRedactedAndProviderFreeOnLoad()
        async throws {
        let root = try failedHistoryServiceTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let keyStore = FailedHistoryServiceAPIKeyStore(
            storedKey: "sk-service-test"
        )
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let service = IOSFailedHistoryService(
            applicationSupportDirectoryURL: root,
            credentialCoordinator: credentialCoordinator
        )

        requireSendable(IOSFailedHistoryService.self)
        #expect(String(describing: service) == "IOSFailedHistoryService(redacted)")
        #expect(service.customMirror.children.isEmpty)
        #expect(await service.loadFailedHistory() == .pendingLocalRecovery)
        #expect(await keyStore.loadCallCount() == 0)
    }

    @Test func localOnlyCompositionKeepsHistoryAvailableWithoutCredentials()
        async throws {
        let root = try failedHistoryServiceTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = IOSFailedHistoryService(
            applicationSupportDirectoryURL: root,
            credentialCoordinator: nil
        )

        #expect(await service.loadFailedHistory() == .pendingLocalRecovery)
        #expect(String(reflecting: service) == "IOSFailedHistoryService(redacted)")
    }
}

private actor FailedHistoryServiceAPIKeyStore: OpenAIAPIKeyStoring {
    private var storedKey: String?
    private var loads = 0

    init(storedKey: String?) {
        self.storedKey = storedKey
    }

    func saveOrReplaceAPIKey(_ candidate: String) async throws {
        storedKey = candidate
    }

    func loadAPIKey() async throws -> String? {
        loads += 1
        return storedKey
    }

    func removeAPIKey() async throws {
        storedKey = nil
    }

    func loadCallCount() -> Int { loads }
}

private func failedHistoryServiceTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-failed-history-service-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return root
}

private func requireSendable<T: Sendable>(_ type: T.Type) {
    _ = type
}
