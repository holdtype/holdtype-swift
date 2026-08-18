#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BProtectedStorageObserverHostedTests {
    @Test func hostedPrivateRecoveryOwnerEmitsOnlyPrivateScopeBeforeSyntheticMutation() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST"] == "1" else {
            return
        }
        let rawHome = try #require(environment["HOME"])
        let rawTemporary = try #require(environment["TMPDIR"])
        let taskHome = URL(fileURLWithPath: rawHome).standardizedFileURL
        let taskRoot = taskHome.deletingLastPathComponent()
        let suffix = taskRoot.lastPathComponent.dropFirst(
            "holdtype-dev-vlogs-observer.".count)
        #expect(taskHome.lastPathComponent == "home")
        #expect(taskRoot.deletingLastPathComponent().path == "/tmp")
        #expect(taskRoot.lastPathComponent.hasPrefix("holdtype-dev-vlogs-observer."))
        #expect(suffix.count == 8 && suffix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
        #expect(rawTemporary.hasPrefix(rawHome + "/"))
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath()
        #expect(home == taskHome.resolvingSymlinksInPath())
        let applicationSupport = try #require(FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first)
        #expect(applicationSupport.resolvingSymlinksInPath().path.hasPrefix(home.path + "/"))
        let recovery = TranscriptionFailureRecoveryArtifactFormat.defaultDirectoryURL(
            fileManager: .default)
        #expect(recovery.resolvingSymlinksInPath().path.hasPrefix(home.path + "/"))
        let observer = DevVlogsPhase0BProtectedStorageObserver.shared
        #expect(observer.isInstalledForTesting)
        let countBefore = observer.ownerInitializationCount
        _ = TranscriptionFailureRecoveryStore(directoryURL: recovery)
        #expect(observer.ownerInitializationCount == countBefore + 1)
        #expect(observer.latestOwnerScopeWasPrivate)
    }
}
#endif
