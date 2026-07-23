import HoldTypeDomain

actor FixesEditorPreviewStore: MacOSTextFixCatalogStoring {
    private var catalog: TextFixCatalog

    init(catalog: TextFixCatalog) {
        self.catalog = catalog
    }

    func load() async throws -> TextFixCatalog {
        catalog
    }

    func save(_ catalog: TextFixCatalog) async throws -> TextFixCatalog {
        self.catalog = catalog
        return catalog
    }
}

@MainActor
func makeFixesEditorPreviewModel(
    catalog: TextFixCatalog = .defaults,
    selectedActionID: String? = nil,
    addsNewFix: Bool = false
) -> FixesEditorModel {
    let model = FixesEditorModel(
        store: FixesEditorPreviewStore(catalog: catalog),
        identifierGenerator: { "custom.preview" },
        preloadedCatalog: catalog
    )
    if let selectedActionID {
        model.selectAction(id: selectedActionID)
    }
    if addsNewFix {
        model.addFix()
    }
    return model
}
