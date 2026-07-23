import HoldTypeDomain
import HoldTypePersistence
@testable import HoldType

actor FixesEditorTestStore: MacOSTextFixCatalogStoring {
    struct Snapshot: Sendable {
        let catalog: TextFixCatalog
        let loadCount: Int
        let saveCount: Int
    }

    enum SaveFailure: Error {
        case expected
    }

    private var catalog: TextFixCatalog
    private var loadError: TextFixCatalogRepositoryError?
    private var saveFails: Bool
    private var loadCount = 0
    private var saveCount = 0

    init(
        catalog: TextFixCatalog = .defaults,
        loadError: TextFixCatalogRepositoryError? = nil,
        saveFails: Bool = false
    ) {
        self.catalog = catalog
        self.loadError = loadError
        self.saveFails = saveFails
    }

    func load() async throws -> TextFixCatalog {
        loadCount += 1
        if let loadError {
            throw loadError
        }
        return catalog
    }

    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog {
        saveCount += 1
        if saveFails {
            throw SaveFailure.expected
        }
        self.catalog = catalog
        return catalog
    }

    func setLoadError(_ error: TextFixCatalogRepositoryError?) {
        loadError = error
    }

    func setSaveFails(_ saveFails: Bool) {
        self.saveFails = saveFails
    }

    func snapshot() -> Snapshot {
        Snapshot(
            catalog: catalog,
            loadCount: loadCount,
            saveCount: saveCount
        )
    }
}
