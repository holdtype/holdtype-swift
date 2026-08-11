import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsSceneTests {
    @Test func devVlogsSceneUsesStableWindowIdentifier() {
        #expect(DevVlogsScene.identifier == "holdtype.dev-vlogs")
        #expect(HoldTypeWindowTitle.titled("Dev Vlogs") == "HoldType: Dev Vlogs")
    }

    @Test func storageIsTheFourthVisibleDevVlogsSection() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HoldType/DevVlogs/DevVlogsWindowRoot.swift")
        let source = try String(contentsOf: sourceURL)

        let overview = try #require(source.range(of: "Label(\"Overview\""))
        let capture = try #require(source.range(of: "Label(\"Capture\""))
        let applications = try #require(source.range(of: "Label(\"Applications\""))
        let storage = try #require(source.range(of: "Label(\"Storage\""))

        #expect(overview.lowerBound < capture.lowerBound)
        #expect(capture.lowerBound < applications.lowerBound)
        #expect(applications.lowerBound < storage.lowerBound)
    }

    @Test func windowRootOwnsOnlyPassiveReadinessRefreshes() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HoldType/DevVlogs/DevVlogsWindowRoot.swift")
        let source = try String(contentsOf: sourceURL)

        #expect(source.contains("DevVlogsReadinessCoordinator.refresh"))
        #expect(source.contains("cameraDeviceChangePublisher"))
        #expect(source.contains("newPhase == .active"))
        #expect(!source.contains("requestAccess"))
        #expect(!source.contains("createDirectory"))
        #expect(!source.contains("Keychain"))
        #expect(!source.contains("DictationRuntime"))
        #expect(!source.contains("frontmost"))
    }
}
