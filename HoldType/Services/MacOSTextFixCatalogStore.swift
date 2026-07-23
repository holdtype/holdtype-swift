import Foundation
import HoldTypeDomain
import HoldTypePersistence

protocol MacOSTextFixCatalogStoring: Sendable {
    func load() async throws -> TextFixCatalog
    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog
}

struct MacOSTextFixCatalogStore: MacOSTextFixCatalogStoring, Sendable {
    private let repository: TextFixCatalogRepository

    init(
        applicationSupportDirectoryURL: URL =
            Self.defaultApplicationSupportDirectoryURL()
    ) {
        repository = TextFixCatalogRepository(
            macOSApplicationSupportDirectoryURL:
                applicationSupportDirectoryURL
        )
    }

    init(repository: TextFixCatalogRepository) {
        self.repository = repository
    }

    func load() async throws -> TextFixCatalog {
        try await repository.load()
    }

    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog {
        try await repository.save(catalog)
    }

    private static func defaultApplicationSupportDirectoryURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
    }
}
