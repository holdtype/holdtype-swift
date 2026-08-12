import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct FixesPaletteModelTests {
    @Test func startsWithFiveCatalogActionsAndTopActionSelected() throws {
        let disabledID = TextFixCatalog.defaults.customActions[0].id
        let catalog = try TextFixCatalog.defaults.settingCustomActionEnabled(
            id: disabledID,
            isEnabled: false
        )
        let model = makeModel(catalog: catalog)

        #expect(
            model.actions.map(\.id)
                == [FixesPaletteActionPresentation.voicePromptIdentifier]
                    + catalog.enabledActions.map(\.id)
        )
        #expect(model.actions.contains(where: { $0.id == disabledID }) == false)
        #expect(model.selectedActionID == catalog.enabledActions.first?.id)
        #expect(
            model.visibleActions.map(\.id)
                == [FixesPaletteActionPresentation.voicePromptIdentifier]
                    + Array(catalog.enabledActions.prefix(5)).map(\.id)
        )
    }

    @Test func searchIsCaseAndDiacriticInsensitive() throws {
        let resume = try TextFixAction(
            id: "custom.resume",
            kind: .customPrompt,
            title: "Résumé",
            icon: .custom,
            prompt: "Improve this résumé.",
            isEnabled: true
        )
        let catalog = try TextFixCatalog.defaults.addingCustomAction(resume)
        let model = makeModel(catalog: catalog)

        model.setSearchText("RESUME")

        #expect(
            model.visibleActions.map(\.id)
                == [FixesPaletteActionPresentation.voicePromptIdentifier, resume.id]
        )
        #expect(model.selectedActionID == resume.id)
    }

    @Test func clearingSearchRestoresRecentMenuAndClearsSelection() {
        let model = makeModel()
        model.setSearchText("Correct")
        #expect(model.visibleActions.isEmpty == false)

        model.setSearchText("")

        #expect(
            model.visibleActions.count
                == FixesPaletteModel.maximumVisibleActionCount + 1
        )
        #expect(model.selectedActionID == nil)
    }

    @Test func whitespaceOnlySearchShowsRecentMenuAndClearsSelection() {
        let model = makeModel()

        model.setSearchText("   \n")

        #expect(
            model.visibleActions.count
                == FixesPaletteModel.maximumVisibleActionCount + 1
        )
        #expect(model.selectedActionID == nil)
    }

    @Test func recentActionsLeadTheInitialMenu() {
        let model = makeModel(
            recentActionIDs: ["default.summarize", "default.make-shorter"]
        )

        #expect(
            model.visibleActions.map(\.id)
                == [
                    FixesPaletteActionPresentation.voicePromptIdentifier,
                    "default.summarize",
                    "default.make-shorter",
                    TextFixAction.translateIdentifier,
                    TextFixAction.fixIdentifier,
                    "default.improve-writing",
                ]
        )
    }

    @Test func searchUsesMatchQualityAndShowsAtMostFive() throws {
        let rewrite = try TextFixAction(
            id: "custom.rewrite",
            kind: .customPrompt,
            title: "Rewrite",
            icon: .rewrite,
            prompt: "Rewrite this text.",
            isEnabled: true
        )
        let catalog = try TextFixCatalog.defaults.addingCustomAction(rewrite)
        let model = makeModel(
            catalog: catalog,
            recentActionIDs: [rewrite.id, "default.improve-writing"]
        )

        model.setSearchText("writ")

        #expect(
            model.visibleActions.map(\.id)
                == [
                    FixesPaletteActionPresentation.voicePromptIdentifier,
                    rewrite.id,
                    "default.improve-writing",
                ]
        )
    }

    @Test func unmatchedSearchClearsSelection() {
        let model = makeModel()

        model.setSearchText("No result with this title")

        #expect(
            model.visibleActions.map(\.id)
                == [FixesPaletteActionPresentation.voicePromptIdentifier]
        )
        #expect(
            model.selectedActionID
                == FixesPaletteActionPresentation.voicePromptIdentifier
        )
        #expect(model.canActivateSelection)
    }

    @Test func arrowMovementClampsAtListEdges() {
        let model = makeModel()
        model.setSearchText("Correct")

        model.moveSelection(.up)
        #expect(model.selectedActionID == model.visibleActions.first?.id)

        for _ in 0..<(model.visibleActions.count + 2) {
            model.moveSelection(.down)
        }
        #expect(model.selectedActionID == model.visibleActions.last?.id)

        for _ in 0..<(model.visibleActions.count + 2) {
            model.moveSelection(.up)
        }
        #expect(model.selectedActionID == model.visibleActions.first?.id)
    }

    @Test func activationImmediatelyEntersProcessingAndPreventsDuplicateAction() {
        var activatedIDs: [String] = []
        let model = makeModel { activatedIDs.append($0) }
        model.setSearchText("Translate")

        model.activateSelection()
        model.activateSelection()

        #expect(activatedIDs == [TextFixAction.translateIdentifier])
        #expect(
            model.status
                == .processing(actionID: TextFixAction.translateIdentifier)
        )
        #expect(model.canActivateSelection == false)
    }

    @Test func retryableFailureAllowsAnotherActivation() {
        var activatedIDs: [String] = []
        let model = makeModel { activatedIDs.append($0) }
        model.setSearchText("Correct")
        model.updateStatus(
            .failure(message: "The service is temporarily unavailable.", allowsRetry: true)
        )
        model.moveSelection(.down)

        model.activateSelection()

        #expect(activatedIDs == [TextFixAction.fixIdentifier])
        #expect(model.status == .processing(actionID: TextFixAction.fixIdentifier))
    }

    @Test func unavailableAndStaleStatesBlockActivation() {
        var activationCount = 0
        let model = makeModel { _ in activationCount += 1 }
        model.setSearchText("Correct")

        model.updateStatus(.unavailable(message: "Select some text."))
        model.activateSelection()
        model.updateStatus(.staleTarget(message: "The text changed."))
        model.activateSelection()

        #expect(activationCount == 0)
    }

    @Test func dismissalIsIdempotentAndStopsFurtherInteraction() {
        var dismissCount = 0
        var activationCount = 0
        let model = FixesPaletteModel(
            catalog: .defaults,
            onActivate: { _ in activationCount += 1 },
            onDismiss: { dismissCount += 1 }
        )

        model.requestDismissal()
        model.requestDismissal()
        model.activateSelection()
        model.setSearchText("Correct")

        #expect(dismissCount == 1)
        #expect(activationCount == 0)
        #expect(model.searchText.isEmpty)
    }

    @Test func activeVoicePromptBlocksOutsideDismissalAndReturnStopsRecording() {
        var stopCount = 0
        let model = FixesPaletteModel(
            catalog: .defaults,
            onActivate: { _ in },
            onVoicePromptStop: { stopCount += 1 },
            onDismiss: {}
        )

        model.updateStatus(.recordingVoicePrompt)
        #expect(model.allowsOutsideDismissal == false)

        model.activateSelection()

        #expect(stopCount == 1)
        #expect(model.status == .recordingVoicePrompt)
    }

    private func makeModel(
        catalog: TextFixCatalog = .defaults,
        recentActionIDs: [String] = [],
        onActivate: @escaping FixesPaletteModel.ActionHandler = { _ in }
    ) -> FixesPaletteModel {
        FixesPaletteModel(
            catalog: catalog,
            recentActionIDs: recentActionIDs,
            onActivate: onActivate,
            onDismiss: {}
        )
    }
}
