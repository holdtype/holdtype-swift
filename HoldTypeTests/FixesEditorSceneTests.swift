import Testing
@testable import HoldType

@MainActor
struct FixesEditorSceneTests {
    @Test func editorSceneUsesStableWindowIdentifier() {
        #expect(FixesEditorScene.identifier == "holdtype.manage-fixes")
    }
}
