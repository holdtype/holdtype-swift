import HoldTypeDomain
import HoldTypePersistence
import Testing
@testable import HoldType

@MainActor
struct FixesEditorModelLoadingTests {
    @Test func loadPinsBuiltInsAndSearchesTitlesAndPromptContent() async {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)

        await model.loadIfNeeded()

        #expect(model.catalog == .defaults)
        #expect(
            model.visibleActions.prefix(2).map(\.id) == [
                TextFixAction.translateIdentifier,
                TextFixAction.fixIdentifier,
            ]
        )
        #expect(model.visibleActions[0].isBuiltIn)
        #expect(model.visibleActions[1].isBuiltIn)
        #expect(model.selectedActionID == TextFixAction.translateIdentifier)

        model.setSearchText("shorter")
        #expect(model.visibleActions.map(\.id) == ["default.make-shorter"])

        model.setSearchText("bullet-point list")
        #expect(model.visibleActions.map(\.id) == ["default.bullet-points"])
    }

    @Test func builtInsExposeNoEditableDraftOrMutationControls() async {
        let model = FixesEditorModel(store: FixesEditorTestStore())
        await model.loadIfNeeded()

        for id in [
            TextFixAction.translateIdentifier,
            TextFixAction.fixIdentifier,
        ] {
            model.selectAction(id: id)

            #expect(model.selectedAction?.id == id)
            #expect(model.selectedBuiltIn != nil)
            #expect(model.selectedDraft == nil)
            #expect(!model.canSaveSelectedDraft)
            #expect(!model.canDeleteSelection)
            #expect(!model.canMoveSelectionUp)
            #expect(!model.canMoveSelectionDown)
        }
    }

    @Test func corruptLoadCannotEnterAnyWritePathAndCanRetry() async {
        let store = FixesEditorTestStore(loadError: .malformedData)
        let model = FixesEditorModel(
            store: store,
            identifierGenerator: { "custom.never-written" }
        )

        await model.loadIfNeeded()

        #expect(model.catalog == nil)
        #expect(model.issue?.kind == .load)
        #expect(model.issue?.title == "Fixes Catalog Is Damaged")
        #expect(model.issue?.message.contains("will not replace") == true)

        model.addFix()
        await model.saveSelectedDraft()
        await model.restoreDefaults()
        await model.deleteSelection()

        var snapshot = await store.snapshot()
        #expect(snapshot.loadCount == 1)
        #expect(snapshot.saveCount == 0)
        #expect(snapshot.catalog == .defaults)

        await store.setLoadError(nil)
        await model.retryLoad()

        snapshot = await store.snapshot()
        #expect(snapshot.loadCount == 2)
        #expect(snapshot.saveCount == 0)
        #expect(model.catalog == .defaults)
        #expect(model.issue == nil)
    }

    @Test func unsupportedCatalogExplainsPreservationInsteadOfDefaults() async {
        let model = FixesEditorModel(
            store: FixesEditorTestStore(loadError: .unsupportedSchemaVersion)
        )

        await model.loadIfNeeded()

        #expect(model.catalog == nil)
        #expect(model.issue?.title == "Newer Fixes Catalog")
        #expect(model.issue?.message.contains("will not overwrite") == true)
    }
}
