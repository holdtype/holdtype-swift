import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct FixesEditorModelMutationTests {
    @Test func automaticSaveDebouncesTheLatestCustomFixEdit() async throws {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let original = try #require(TextFixCatalog.defaults.customActions.first)

        model.selectAction(id: original.id)
        model.setSelectedTitle("Improve This Writing")
        model.setSelectedPrompt("Rewrite clearly and return only the result.")

        try await Task.sleep(for: .milliseconds(250))
        let earlySnapshot = await store.snapshot()
        #expect(earlySnapshot.saveCount == 0)

        try await Task.sleep(for: .milliseconds(350))
        let snapshot = await store.snapshot()
        let saved = try #require(snapshot.catalog.action(id: original.id))
        #expect(saved.title == "Improve This Writing")
        #expect(saved.prompt == "Rewrite clearly and return only the result.")
        #expect(snapshot.saveCount == 1)
        #expect(!model.selectedDraftHasChanges)
    }

    @Test func changingSelectionFlushesPendingCustomFixEdit() async throws {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let original = try #require(TextFixCatalog.defaults.customActions.first)
        let next = try #require(TextFixCatalog.defaults.customActions.dropFirst().first)

        model.selectAction(id: original.id)
        model.setSelectedTitle("Improve This Writing")
        model.selectAction(id: next.id)

        try await Task.sleep(for: .milliseconds(100))
        let snapshot = await store.snapshot()
        #expect(snapshot.catalog.action(id: original.id)?.title == "Improve This Writing")
        #expect(snapshot.saveCount == 1)
        #expect(model.selectedActionID == next.id)
    }

    @Test func addValidatesThenSavesStableCustomAction() async throws {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(
            store: store,
            identifierGenerator: { "custom.test-polish" }
        )
        await model.loadIfNeeded()

        model.addFix()

        #expect(model.selectedDraft?.id == "custom.test-polish")
        #expect(model.selectedDraft?.isNew == true)
        #expect(model.selectedDraftValidation?.titleMessage == "Enter a title.")
        #expect(model.selectedDraftValidation?.promptMessage == "Enter a prompt.")

        model.setSelectedTitle("Polish")
        model.setSelectedPrompt("Polish the text without changing its meaning.")
        model.setSelectedIcon(.rewrite)
        model.setSelectedEnabled(false)

        await model.saveSelectedDraft()

        let snapshot = await store.snapshot()
        let saved = try #require(snapshot.catalog.action(id: "custom.test-polish"))
        #expect(saved.title == "Polish")
        #expect(saved.prompt == "Polish the text without changing its meaning.")
        #expect(saved.icon == .rewrite)
        #expect(!saved.isEnabled)
        #expect(snapshot.saveCount == 1)
        #expect(model.selectedDraft?.isNew == false)
        #expect(!model.selectedDraftHasChanges)
    }

    @Test func editingExistingFixReplacesWithoutChangingIdentifier() async throws {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let original = try #require(TextFixCatalog.defaults.customActions.first)

        model.selectAction(id: original.id)
        model.setSelectedTitle("Improve This Writing")
        model.setSelectedPrompt("Rewrite clearly and return only the result.")
        model.setSelectedIcon(.formal)
        await model.saveSelectedDraft()

        let snapshot = await store.snapshot()
        let updated = try #require(snapshot.catalog.action(id: original.id))
        #expect(updated.id == original.id)
        #expect(updated.title == "Improve This Writing")
        #expect(updated.icon == .formal)
        #expect(snapshot.catalog.actions.count == TextFixCatalog.defaults.actions.count)
    }

    @Test func reorderAndDeleteUseCatalogMutationsWithoutMovingBuiltIns() async throws {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let movedID = TextFixCatalog.defaults.customActions[1].id

        await model.moveCustomActions(from: IndexSet(integer: 1), toOffset: 0)

        var snapshot = await store.snapshot()
        #expect(snapshot.catalog.customActions.first?.id == movedID)
        #expect(
            snapshot.catalog.actions.prefix(2).map(\.id) == [
                TextFixAction.translateIdentifier,
                TextFixAction.fixIdentifier,
            ]
        )

        model.selectAction(id: movedID)
        await model.deleteSelection()

        snapshot = await store.snapshot()
        #expect(snapshot.catalog.action(id: movedID) == nil)
        #expect(snapshot.saveCount == 2)
        #expect(
            snapshot.catalog.actions.prefix(2).map(\.id) == [
                TextFixAction.translateIdentifier,
                TextFixAction.fixIdentifier,
            ]
        )
    }

    @Test func dragReorderUsesFinalCustomIndexAndIsDisabledWhileFiltering() async {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let movedID = TextFixCatalog.defaults.customActions[0].id

        await model.moveCustomActions(from: IndexSet(integer: 0), toOffset: 3)

        var snapshot = await store.snapshot()
        #expect(snapshot.catalog.customActions[2].id == movedID)

        model.setSearchText("shorter")
        #expect(!model.canReorderCustomActions)
        await model.moveCustomActions(from: IndexSet(integer: 0), toOffset: 2)

        snapshot = await store.snapshot()
        #expect(snapshot.catalog.customActions[2].id == movedID)
    }

    @Test func saveFailureKeepsCanonicalCatalogAndEditableDraft() async throws {
        let store = FixesEditorTestStore(saveFails: true)
        let model = FixesEditorModel(store: store)
        await model.loadIfNeeded()
        let original = try #require(TextFixCatalog.defaults.customActions.first)

        model.selectAction(id: original.id)
        model.setSelectedTitle("Unsaved Replacement")
        await model.saveSelectedDraft()

        let snapshot = await store.snapshot()
        #expect(snapshot.catalog == .defaults)
        #expect(model.catalog == .defaults)
        #expect(model.selectedDraft?.title == "Unsaved Replacement")
        #expect(model.selectedDraftHasChanges)
        #expect(model.issue?.kind == .save)
        #expect(model.issue?.title == "Fixes Weren’t Saved")
        #expect(snapshot.saveCount == 1)
    }

    @Test func generatedIdentifierCollisionDoesNotCreateOrSaveDraft() async {
        let store = FixesEditorTestStore()
        let model = FixesEditorModel(
            store: store,
            identifierGenerator: { TextFixAction.translateIdentifier }
        )
        await model.loadIfNeeded()

        model.addFix()

        let snapshot = await store.snapshot()
        #expect(model.selectedDraft == nil)
        #expect(model.issue?.kind == .validation)
        #expect(snapshot.saveCount == 0)
    }
}
