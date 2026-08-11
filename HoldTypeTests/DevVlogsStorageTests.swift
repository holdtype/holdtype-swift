import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsStorageTests {
    @Test func initialDefaultIsExactAndDoesNotCreateTheFolder() throws {
        let fixture = try makeFixture()
        let store = fixture.store()

        #expect(store.status == DevVlogsDestinationStatus(
            selection: .proposedDefault(path: fixture.defaultURL.path),
            availability: .needsSetup
        ))
        #expect(fixture.fileAccess.createdURLs.isEmpty)
    }

    @Test func explicitDefaultActionCreatesOnlyTheExactDefaultFolderAfterParentValidation() throws {
        let fixture = try makeFixture()
        fixture.fileAccess.states[fixture.defaultURL.deletingLastPathComponent().path] = .directory(isWritable: true)
        let store = fixture.store()

        store.useOrCreateDefaultFolder()

        #expect(fixture.fileAccess.createdURLs == [fixture.defaultURL])
        #expect(store.status == DevVlogsDestinationStatus(
            selection: .defaultFolder(path: fixture.defaultURL.path),
            availability: .available
        ))
    }

    @Test func customFolderPersistsBookmarkAndBalancesSecurityScope() throws {
        let fixture = try makeFixture()
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fixture.fileAccess.states[customURL.path] = .directory(isWritable: true)
        let store = fixture.store()

        store.selectCustomFolder(customURL)

        #expect(store.status == DevVlogsDestinationStatus(
            selection: .custom(displayName: "Dev Vlogs", pathSnapshot: customURL.path),
            availability: .available
        ))
        #expect(fixture.bookmarks.startedURLs == [customURL])
        #expect(fixture.bookmarks.stoppedURLs == [customURL])

        let reloadedStore = fixture.store()
        reloadedStore.refresh()
        #expect(reloadedStore.status.selection == .custom(displayName: "Dev Vlogs", pathSnapshot: customURL.path))
    }

    @Test func staleCustomBookmarkIsRefreshedAndRemainsSelected() throws {
        let fixture = try makeFixture()
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fixture.fileAccess.states[customURL.path] = .directory(isWritable: true)
        let store = fixture.store()
        store.selectCustomFolder(customURL)
        fixture.bookmarks.isStale = true

        store.refresh()

        #expect(fixture.bookmarks.createdBookmarkCount == 2)
        #expect(store.status.selection == .custom(displayName: "Dev Vlogs", pathSnapshot: customURL.path))
        #expect(store.status.availability == .available)
    }

    @Test func unresolvedCustomBookmarkStaysSelectedAndNeverFallsBackToDefault() throws {
        let fixture = try makeFixture()
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fixture.fileAccess.states[customURL.path] = .directory(isWritable: true)
        let store = fixture.store()
        store.selectCustomFolder(customURL)
        fixture.bookmarks.shouldFailResolution = true

        store.refresh()

        #expect(store.status.selection == .custom(displayName: "Dev Vlogs", pathSnapshot: customURL.path))
        #expect(store.status.availability == .unavailable(.bookmarkUnavailable))
        #expect(fixture.fileAccess.createdURLs.isEmpty)
    }

    @Test func readOnlyCustomFolderIsTruthfullyUnavailableWithoutAWriteProbe() throws {
        let fixture = try makeFixture()
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fixture.fileAccess.states[customURL.path] = .directory(isWritable: false)
        let store = fixture.store()

        store.selectCustomFolder(customURL)

        #expect(store.status.availability == .unavailable(.readOnly))
        #expect(fixture.fileAccess.createdURLs.isEmpty)
    }

    @Test func explicitDefaultSelectionPreservesTheInactiveCustomBookmark() throws {
        let fixture = try makeFixture()
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fixture.fileAccess.states[customURL.path] = .directory(isWritable: true)
        fixture.fileAccess.states[fixture.defaultURL.deletingLastPathComponent().path] = .directory(isWritable: true)
        let store = fixture.store()
        store.selectCustomFolder(customURL)

        store.useOrCreateDefaultFolder()

        #expect(store.status.selection == .defaultFolder(path: fixture.defaultURL.path))
        #expect(store.hasInactiveCustomFolder)
    }

    private func makeFixture() throws -> StorageFixture {
        let suiteName = "DevVlogsStorageTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return StorageFixture(userDefaults: userDefaults, suiteName: suiteName)
    }

    @MainActor
    private final class StorageFixture {
        let userDefaults: UserDefaults
        let suiteName: String
        let bookmarks = BookmarkResolverFake()
        let fileAccess = FileAccessFake()
        let defaultURL = URL(fileURLWithPath: "/fixture/Movies/HoldType Dev Vlogs")

        init(userDefaults: UserDefaults, suiteName: String) {
            self.userDefaults = userDefaults
            self.suiteName = suiteName
        }

        deinit {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        func store() -> DevVlogsDestinationSetupStore {
            DevVlogsDestinationSetupStore(
                userDefaults: userDefaults,
                bookmarkResolver: bookmarks,
                fileAccess: fileAccess,
                defaultDestinationURL: defaultURL
            )
        }
    }

    private final class BookmarkResolverFake: DevVlogsDestinationBookmarkResolving {
        var isStale = false
        var shouldFailResolution = false
        private(set) var createdBookmarkCount = 0
        private(set) var startedURLs: [URL] = []
        private(set) var stoppedURLs: [URL] = []

        func bookmarkData(for url: URL) throws -> Data {
            createdBookmarkCount += 1
            return Data(url.path.utf8)
        }

        func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution {
            if shouldFailResolution {
                throw BookmarkError.unresolved
            }
            return DevVlogsBookmarkResolution(
                url: URL(fileURLWithPath: String(decoding: data, as: UTF8.self)),
                isStale: isStale
            )
        }

        func startAccessingSecurityScopedResource(at url: URL) -> Bool {
            startedURLs.append(url)
            return true
        }

        func stopAccessingSecurityScopedResource(at url: URL) {
            stoppedURLs.append(url)
        }

        private enum BookmarkError: Error {
            case unresolved
        }
    }

    private final class FileAccessFake: DevVlogsDestinationFileAccessing {
        var states: [String: DevVlogsDestinationDirectoryState] = [:]
        private(set) var createdURLs: [URL] = []

        func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState {
            states[url.path] ?? .missing
        }

        func createDirectory(at url: URL) throws {
            createdURLs.append(url)
            states[url.path] = .directory(isWritable: true)
        }
    }
}
