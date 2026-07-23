import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

struct IOSTextFixEditorProductionClientTests {
    @Test
    func savePersistsBeforeRefreshingRuntimeProjections() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = TextFixCatalogRepository(
            applicationSupportDirectoryURL: root
        )
        let recorder = TextFixEditorRefreshRecorder(
            repository: repository
        )
        let client = IOSTextFixEditorClient(
            repository: repository,
            refreshAfterSave: {
                await recorder.recordRefresh()
            }
        )
        let expected = try TextFixCatalog.defaults.addingCustomAction(
            TextFixAction(
                id: "custom.test",
                kind: .customPrompt,
                title: "Test",
                icon: .custom,
                prompt: "Rewrite this text for a test.",
                isEnabled: true
            )
        )

        let saved = try await client.save(expected)

        #expect(saved == expected)
        #expect(try await client.load() == expected)
        #expect(await recorder.catalogObservedAtRefresh() == expected)
    }
}

private actor TextFixEditorRefreshRecorder {
    private let repository: TextFixCatalogRepository
    private var observedCatalog: TextFixCatalog?

    init(repository: TextFixCatalogRepository) {
        self.repository = repository
    }

    func recordRefresh() async {
        observedCatalog = try? await repository.load()
    }

    func catalogObservedAtRefresh() -> TextFixCatalog? {
        observedCatalog
    }
}
