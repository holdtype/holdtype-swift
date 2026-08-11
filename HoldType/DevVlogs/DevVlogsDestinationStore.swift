import Combine
import Foundation

@MainActor
final class DevVlogsDestinationSetupStore: ObservableObject {
    private enum Key {
        static let destination = "holdtype.dev-vlogs.destination"
    }

    private enum PersistedSelection: String, Codable {
        case defaultFolder
        case custom
    }

    private struct PersistedDestination: Codable {
        let selection: PersistedSelection
        let bookmarkData: Data?
        let displayName: String
        let pathSnapshot: String
        let inactiveCustomBookmarkData: Data?
        let inactiveCustomDisplayName: String?
        let inactiveCustomPathSnapshot: String?
    }

    @Published private(set) var status: DevVlogsDestinationStatus

    private let userDefaults: UserDefaults?
    private let bookmarkResolver: any DevVlogsDestinationBookmarkResolving
    private let fileAccess: any DevVlogsDestinationFileAccessing
    private let defaultDestinationURL: URL
    private var persistedDestination: PersistedDestination?

    var hasInactiveCustomFolder: Bool {
        persistedDestination?.inactiveCustomBookmarkData != nil
    }

    init(
        userDefaults: UserDefaults = .standard,
        bookmarkResolver: any DevVlogsDestinationBookmarkResolving = URLDevVlogsDestinationBookmarkResolver(),
        fileAccess: any DevVlogsDestinationFileAccessing = FileManagerDevVlogsDestinationFileAccess(),
        defaultDestinationURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/HoldType Dev Vlogs", isDirectory: true)
    ) {
        self.userDefaults = userDefaults
        self.bookmarkResolver = bookmarkResolver
        self.fileAccess = fileAccess
        self.defaultDestinationURL = defaultDestinationURL
        persistedDestination = Self.load(from: userDefaults)
        status = Self.initialStatus(
            persistedDestination: persistedDestination,
            defaultDestinationURL: defaultDestinationURL
        )
    }

    init(
        status: DevVlogsDestinationStatus,
        bookmarkResolver: any DevVlogsDestinationBookmarkResolving,
        fileAccess: any DevVlogsDestinationFileAccessing,
        defaultDestinationURL: URL
    ) {
        userDefaults = nil
        self.status = status
        self.bookmarkResolver = bookmarkResolver
        self.fileAccess = fileAccess
        self.defaultDestinationURL = defaultDestinationURL
        persistedDestination = nil
    }

    func useOrCreateDefaultFolder() {
        let inactiveCustomDestination = persistedDestination?.selection == .custom ? persistedDestination : nil
        persistedDestination = PersistedDestination(
            selection: .defaultFolder,
            bookmarkData: nil,
            displayName: "Default folder",
            pathSnapshot: defaultDestinationURL.path,
            inactiveCustomBookmarkData: inactiveCustomDestination?.bookmarkData,
            inactiveCustomDisplayName: inactiveCustomDestination?.displayName,
            inactiveCustomPathSnapshot: inactiveCustomDestination?.pathSnapshot
        )
        persist()

        let parentState = fileAccess.directoryState(at: defaultDestinationURL.deletingLastPathComponent())
        guard case .directory(let isWritable) = parentState, isWritable else {
            status = DevVlogsDestinationStatus(
                selection: .defaultFolder(path: defaultDestinationURL.path),
                availability: .unavailable(reason(for: parentState))
            )
            return
        }

        if fileAccess.directoryState(at: defaultDestinationURL) == .missing {
            do {
                try fileAccess.createDirectory(at: defaultDestinationURL)
            } catch {
                status = DevVlogsDestinationStatus(
                    selection: .defaultFolder(path: defaultDestinationURL.path),
                    availability: .unavailable(.inaccessible)
                )
                return
            }
        }

        refresh()
    }

    func selectCustomFolder(_ url: URL) {
        do {
            let bookmarkData = try bookmarkResolver.bookmarkData(for: url)
            persistedDestination = PersistedDestination(
                selection: .custom,
                bookmarkData: bookmarkData,
                displayName: url.lastPathComponent,
                pathSnapshot: url.path,
                inactiveCustomBookmarkData: nil,
                inactiveCustomDisplayName: nil,
                inactiveCustomPathSnapshot: nil
            )
            persist()
            refresh()
        } catch {
            status = DevVlogsDestinationStatus(
                selection: .custom(displayName: url.lastPathComponent, pathSnapshot: url.path),
                availability: .unavailable(.bookmarkUnavailable)
            )
        }
    }

    func refresh() {
        guard let persistedDestination else {
            status = DevVlogsDestinationStatus(
                selection: .proposedDefault(path: defaultDestinationURL.path),
                availability: .needsSetup
            )
            return
        }

        switch persistedDestination.selection {
        case .defaultFolder:
            status = DevVlogsDestinationStatus(
                selection: .defaultFolder(path: defaultDestinationURL.path),
                availability: availability(at: defaultDestinationURL)
            )
        case .custom:
            refreshCustomDestination(persistedDestination)
        }
    }

    private func refreshCustomDestination(_ destination: PersistedDestination) {
        guard let bookmarkData = destination.bookmarkData,
              let resolution = try? bookmarkResolver.resolveBookmarkData(bookmarkData) else {
            status = unavailableCustomStatus(destination, reason: .bookmarkUnavailable)
            return
        }

        guard bookmarkResolver.startAccessingSecurityScopedResource(at: resolution.url) else {
            status = unavailableCustomStatus(destination, reason: .securityScopeDenied)
            return
        }
        defer {
            bookmarkResolver.stopAccessingSecurityScopedResource(at: resolution.url)
        }

        if resolution.isStale {
            guard let refreshedBookmark = try? bookmarkResolver.bookmarkData(for: resolution.url) else {
                status = unavailableCustomStatus(destination, reason: .bookmarkUnavailable)
                return
            }
            persistedDestination = PersistedDestination(
                selection: .custom,
                bookmarkData: refreshedBookmark,
                displayName: resolution.url.lastPathComponent,
                pathSnapshot: resolution.url.path,
                inactiveCustomBookmarkData: nil,
                inactiveCustomDisplayName: nil,
                inactiveCustomPathSnapshot: nil
            )
            persist()
        }

        status = DevVlogsDestinationStatus(
            selection: .custom(displayName: resolution.url.lastPathComponent, pathSnapshot: resolution.url.path),
            availability: availability(at: resolution.url)
        )
    }

    private func unavailableCustomStatus(
        _ destination: PersistedDestination,
        reason: DevVlogsDestinationUnavailableReason
    ) -> DevVlogsDestinationStatus {
        DevVlogsDestinationStatus(
            selection: .custom(displayName: destination.displayName, pathSnapshot: destination.pathSnapshot),
            availability: .unavailable(reason)
        )
    }

    private func availability(at url: URL) -> DevVlogsDestinationAvailability {
        switch fileAccess.directoryState(at: url) {
        case .directory(let isWritable):
            return isWritable ? .available : .unavailable(.readOnly)
        case .missing:
            return .unavailable(.missing)
        case .symbolicLink:
            return .unavailable(.symbolicLink)
        case .notDirectory:
            return .unavailable(.notDirectory)
        case .inaccessible:
            return .unavailable(.inaccessible)
        }
    }

    private func reason(for state: DevVlogsDestinationDirectoryState) -> DevVlogsDestinationUnavailableReason {
        switch state {
        case .missing:
            return .missing
        case .directory:
            return .readOnly
        case .symbolicLink:
            return .symbolicLink
        case .notDirectory:
            return .notDirectory
        case .inaccessible:
            return .inaccessible
        }
    }

    private func persist() {
        guard let userDefaults,
              let persistedDestination,
              let data = try? JSONEncoder().encode(persistedDestination) else {
            return
        }
        userDefaults.set(data, forKey: Key.destination)
    }

    private static func load(from userDefaults: UserDefaults) -> PersistedDestination? {
        guard let data = userDefaults.data(forKey: Key.destination) else {
            return nil
        }
        return try? JSONDecoder().decode(PersistedDestination.self, from: data)
    }

    private static func initialStatus(
        persistedDestination: PersistedDestination?,
        defaultDestinationURL: URL
    ) -> DevVlogsDestinationStatus {
        guard let persistedDestination else {
            return DevVlogsDestinationStatus(
                selection: .proposedDefault(path: defaultDestinationURL.path),
                availability: .needsSetup
            )
        }

        switch persistedDestination.selection {
        case .defaultFolder:
            return DevVlogsDestinationStatus(
                selection: .defaultFolder(path: defaultDestinationURL.path),
                availability: .unavailable(.inaccessible)
            )
        case .custom:
            return DevVlogsDestinationStatus(
                selection: .custom(
                    displayName: persistedDestination.displayName,
                    pathSnapshot: persistedDestination.pathSnapshot
                ),
                availability: .unavailable(.bookmarkUnavailable)
            )
        }
    }
}
