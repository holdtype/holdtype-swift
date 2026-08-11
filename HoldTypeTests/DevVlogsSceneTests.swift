import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsSceneTests {
    @Test func devVlogsSceneUsesStableWindowIdentifier() {
        #expect(DevVlogsScene.identifier == "holdtype.dev-vlogs")
        #expect(HoldTypeWindowTitle.titled("Dev Vlogs") == "HoldType: Dev Vlogs")
    }

    @Test func applicationsIsTheThirdVisibleDevVlogsSection() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HoldType/DevVlogs/DevVlogsWindowRoot.swift")
        let source = try String(contentsOf: sourceURL)

        let overview = try #require(source.range(of: "Label(\"Overview\""))
        let capture = try #require(source.range(of: "Label(\"Capture\""))
        let applications = try #require(source.range(of: "Label(\"Applications\""))

        #expect(overview.lowerBound < capture.lowerBound)
        #expect(capture.lowerBound < applications.lowerBound)
    }
}
