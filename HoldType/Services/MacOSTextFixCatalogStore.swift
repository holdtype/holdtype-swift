import Foundation
import HoldTypeDomain
import HoldTypePersistence

protocol MacOSTextFixCatalogStoring: Sendable {
    func load() async throws -> TextFixCatalog
    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog
}

enum MacOSTextFixCatalogBuildChannel: Equatable, Sendable {
    case production
    case development

    static var current: Self {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }

    func applicationSupportRootURL(in rootURL: URL) -> URL {
        switch self {
        case .production:
            rootURL
        case .development:
            rootURL.appendingPathComponent(
                "app.holdtype.HoldType.debug",
                isDirectory: true
            )
        }
    }
}

struct MacOSTextFixCatalogStore: MacOSTextFixCatalogStoring, Sendable {
    private let repository: TextFixCatalogRepository

    init(
        applicationSupportDirectoryURL: URL =
            Self.defaultApplicationSupportDirectoryURL(),
        buildChannel: MacOSTextFixCatalogBuildChannel = .current
    ) {
        repository = TextFixCatalogRepository(
            macOSApplicationSupportDirectoryURL:
                buildChannel.applicationSupportRootURL(
                    in: applicationSupportDirectoryURL
                )
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
