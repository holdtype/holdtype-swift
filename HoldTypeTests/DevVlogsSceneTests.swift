import Testing
@testable import HoldType

@MainActor
struct DevVlogsSceneTests {
    @Test func devVlogsSceneUsesStableWindowIdentifier() {
        #expect(DevVlogsScene.identifier == "holdtype.dev-vlogs")
        #expect(HoldTypeWindowTitle.titled("Dev Vlogs") == "HoldType: Dev Vlogs")
    }
}
