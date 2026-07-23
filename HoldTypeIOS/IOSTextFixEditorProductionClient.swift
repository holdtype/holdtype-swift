import HoldTypeDomain
import HoldTypePersistence

extension IOSTextFixEditorClient {
    typealias RefreshAfterSave =
        @MainActor @Sendable () async -> Void

    /// Persists the canonical app-private catalog first, then refreshes every
    /// process-owned projection. Projection refresh failures remain
    /// non-destructive because the repository save is already authoritative.
    init(
        repository: TextFixCatalogRepository,
        refreshAfterSave: @escaping RefreshAfterSave
    ) {
        load = {
            try await repository.load()
        }
        save = { catalog in
            let savedCatalog = try await repository.save(catalog)
            await refreshAfterSave()
            return savedCatalog
        }
    }

    @MainActor
    static func production(
        repository: TextFixCatalogRepository,
        voiceRuntime: IOSForegroundVoiceRuntime,
        keyboardRuntime: IOSKeyboardFixRuntimeOwner?
    ) -> Self {
        Self(repository: repository) {
            [weak voiceRuntime, weak keyboardRuntime] in
            await voiceRuntime?.voiceFixesCatalogOwner.refresh()
            _ = await keyboardRuntime?.refreshCatalogMetadata()
        }
    }
}
