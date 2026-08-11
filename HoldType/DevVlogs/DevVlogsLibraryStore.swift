import Combine
import Foundation

enum DevVlogsLibraryLoadState: Equatable {
    case loading
    case ready
    case failed(message: String)
}

struct DevVlogsDeleteConfirmation: Equatable {
    let clipID: UUID
    let title: String
    let scope: String

    init?(clip: DevVlogsLibraryClip) {
        guard let clipID = clip.clipID, clip.health == .ready else { return nil }
        self.clipID = clipID
        title = "Delete this vlog clip?"
        scope = "This removes only this clip's video and Dev Vlogs metadata. Dictation audio, History, Recording Cache, completed videos, and other clips stay unchanged."
    }
}

@MainActor
final class DevVlogsLibraryStore: ObservableObject {
    @Published private(set) var snapshot: DevVlogsLibrarySnapshot = .empty
    @Published private(set) var loadState: DevVlogsLibraryLoadState = .loading

    private let destinationAccessProvider: () throws -> DevVlogsCaptureDestinationAccess
    private let repository: DevVlogsLibraryRepository
    private let ownershipRegistry: DevVlogsClipOwnershipRegistry

    convenience init(destinationStore: DevVlogsDestinationSetupStore) {
        self.init(
            destinationAccessProvider: { try destinationStore.acquireCaptureDestination() }
        )
    }

    init(
        destinationAccessProvider: @escaping () throws -> DevVlogsCaptureDestinationAccess,
        repository: DevVlogsLibraryRepository = DevVlogsLibraryRepository(),
        ownershipRegistry: DevVlogsClipOwnershipRegistry? = nil
    ) {
        self.destinationAccessProvider = destinationAccessProvider
        self.repository = repository
        self.ownershipRegistry = ownershipRegistry ?? .shared
    }

    init(previewSnapshot: DevVlogsLibrarySnapshot) {
        destinationAccessProvider = { throw DevVlogsLibraryError.destinationUnavailable }
        repository = DevVlogsLibraryRepository()
        ownershipRegistry = DevVlogsClipOwnershipRegistry()
        snapshot = previewSnapshot
        loadState = .ready
    }

    func refresh() async {
        loadState = .loading
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            snapshot = try await repository.load(rootURL: access.url)
            loadState = .ready
        } catch {
            snapshot = .empty
            loadState = .failed(message: Self.message(for: error))
        }
    }

    func setExcluded(_ isExcluded: Bool, clip: DevVlogsLibraryClip) async throws {
        guard let clipID = clip.clipID, clip.health == .ready else {
            throw DevVlogsLibraryError.sourceInvalid
        }
        let access = try destinationAccessProvider()
        defer { access.release() }
        try await repository.setExcluded(isExcluded, clipID: clipID, rootURL: access.url)
        snapshot = try await repository.load(rootURL: access.url)
        loadState = .ready
    }

    func delete(_ confirmation: DevVlogsDeleteConfirmation) async throws {
        guard let lease = ownershipRegistry.acquire(
            clipIDs: [confirmation.clipID],
            operation: .deleting
        ) else {
            throw DevVlogsLibraryError.clipBusy
        }
        defer { lease.release() }

        let access = try destinationAccessProvider()
        defer { access.release() }
        try await repository.delete(clipID: confirmation.clipID, rootURL: access.url)
        snapshot = try await repository.load(rootURL: access.url)
        loadState = .ready
    }

    func canDelete(_ clip: DevVlogsLibraryClip) -> Bool {
        guard let clipID = clip.clipID,
              clip.health == .ready else {
            return false
        }
        return ownershipRegistry.operation(for: clipID) == nil
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return DevVlogsLibraryError.destinationUnavailable.localizedDescription
    }
}
