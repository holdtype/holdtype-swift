import HoldTypeDomain
import HoldTypePersistence
import Observation

nonisolated enum IOSVoiceFixesCatalogState: Equatable, Sendable {
    case notLoaded
    case loading
    case ready([TextFixAction])
    case unavailable
}

nonisolated struct IOSVoiceFixesCatalogClient: Sendable {
    typealias Load = @Sendable () async throws -> TextFixCatalog

    let load: Load

    init(load: @escaping Load) {
        self.load = load
    }

    init(repository: TextFixCatalogRepository) {
        load = { try await repository.load() }
    }
}

/// Process-owned presentation boundary for the app-private iOS Fixes catalog.
@MainActor
@Observable
final class IOSVoiceFixesCatalogOwner {
    private(set) var state = IOSVoiceFixesCatalogState.notLoaded

    @ObservationIgnored
    private let client: IOSVoiceFixesCatalogClient
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?

    init(client: IOSVoiceFixesCatalogClient) {
        self.client = client
    }

    convenience init(repository: TextFixCatalogRepository) {
        self.init(client: IOSVoiceFixesCatalogClient(repository: repository))
    }

    deinit {
        loadTask?.cancel()
    }

    var enabledActions: [TextFixAction] {
        guard case .ready(let actions) = state else { return [] }
        return actions
    }

    func refresh() async {
        if let loadTask {
            await loadTask.value
            return
        }

        state = .loading
        let client = client
        let task = Task { @MainActor [weak self] in
            do {
                let catalog = try await client.load()
                guard !Task.isCancelled else { return }
                self?.state = .ready(catalog.enabledActions)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .unavailable
            }
            self?.loadTask = nil
        }
        loadTask = task
        await task.value
    }
}
