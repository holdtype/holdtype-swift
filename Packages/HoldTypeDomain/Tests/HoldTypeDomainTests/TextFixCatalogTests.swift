import Testing
import HoldTypeDomain

struct TextFixCatalogTests {
    @Test func defaultsHaveStablePinnedOrderAndSixEditableCustomFixes() {
        let catalog = TextFixCatalog.defaults

        #expect(catalog.actions.map(\.id) == [
            TextFixAction.translateIdentifier,
            TextFixAction.fixIdentifier,
            "default.improve-writing",
            "default.make-shorter",
            "default.summarize",
            "default.bullet-points",
            "default.change-to-casual",
            "default.markdown",
        ])
        #expect(catalog.actions.map(\.title) == [
            "Translate",
            "Fix",
            "Improve Writing",
            "Make Shorter",
            "Summarize",
            "Bullet Points",
            "Change to Casual",
            "Markdown",
        ])
        #expect(catalog.actions.prefix(2).map(\.kind) == [.translate, .fix])
        #expect(catalog.customActions.count == 6)
        #expect(catalog.customActions.allSatisfy { $0.kind == .customPrompt })
        #expect(catalog.customActions.allSatisfy { $0.prompt?.isEmpty == false })
        #expect(catalog.enabledActions == catalog.actions)
    }

    @Test func catalogRequiresTypedBuiltInsAtTheFirstTwoPositions() throws {
        let defaults = TextFixCatalog.defaults.actions

        #expect(throws: TextFixCatalog.ValidationError.translateMustBeFirst) {
            try TextFixCatalog(actions: Array(defaults.dropFirst()))
        }
        #expect(throws: TextFixCatalog.ValidationError.translateMustBeFirst) {
            try TextFixCatalog(actions: [defaults[1], defaults[0]] + defaults.dropFirst(2))
        }
        #expect(throws: TextFixCatalog.ValidationError.fixMustBeSecond) {
            try TextFixCatalog(actions: [defaults[0]] + defaults.dropFirst(2))
        }
        #expect(
            throws: TextFixCatalog.ValidationError.typedActionOutsidePinnedPositions(
                TextFixAction.translateIdentifier
            )
        ) {
            try TextFixCatalog(actions: defaults + [defaults[0]])
        }
    }

    @Test func catalogRejectsDuplicateCustomIdentifiers() {
        let duplicate = TextFixCatalog.defaults.actions[2]

        #expect(
            throws: TextFixCatalog.ValidationError.duplicateIdentifier(duplicate.id)
        ) {
            try TextFixCatalog(actions: TextFixCatalog.defaults.actions + [duplicate])
        }
    }

    @Test func catalogEnforcesTheHundredActionLimit() throws {
        let atLimit = try TextFixCatalog(
            actions: Array(TextFixCatalog.defaults.actions.prefix(2))
                + (0..<98).map { try makeCustom(id: "user.\($0)") }
        )

        #expect(atLimit.actions.count == TextFixCatalog.maximumActionCount)
        #expect(
            throws: TextFixCatalog.ValidationError.tooManyActions(
                maximumCount: TextFixCatalog.maximumActionCount
            )
        ) {
            try TextFixCatalog(
                actions: atLimit.actions + [makeCustom(id: "user.overflow")]
            )
        }
    }

    @Test func customActionsSupportAddReplaceEnableAndDelete() throws {
        let initial = TextFixCatalog.defaults
        let added = try initial.addingCustomAction(
            makeCustom(id: "user.new", title: "New", prompt: "First prompt")
        )
        let replacement = try makeCustom(
            id: "user.new",
            title: "Renamed",
            prompt: "  Exact replacement prompt\n",
            isEnabled: false
        )
        let replaced = try added.replacingCustomAction(replacement)
        let enabled = try replaced.settingCustomActionEnabled(id: "user.new", isEnabled: true)
        let deleted = try enabled.deletingCustomAction(id: "user.new")

        #expect(initial.action(id: "user.new") == nil)
        #expect(added.actions.last?.title == "New")
        #expect(replaced.actions.last == replacement)
        #expect(enabled.actions.last?.isEnabled == true)
        #expect(deleted == initial)
    }

    @Test func builtInsCannotBeModifiedDeletedOrMoved() throws {
        let catalog = TextFixCatalog.defaults
        let translate = try #require(catalog.actions.first)

        #expect(throws: TextFixCatalog.MutationError.actionMustBeCustom) {
            try catalog.addingCustomAction(translate)
        }
        #expect(throws: TextFixCatalog.MutationError.builtInActionCannotBeModified) {
            try catalog.replacingCustomAction(translate)
        }
        #expect(throws: TextFixCatalog.MutationError.builtInActionCannotBeModified) {
            try catalog.settingCustomActionEnabled(
                id: TextFixAction.translateIdentifier,
                isEnabled: false
            )
        }
        #expect(throws: TextFixCatalog.MutationError.builtInActionCannotBeModified) {
            try catalog.deletingCustomAction(id: TextFixAction.fixIdentifier)
        }
        #expect(throws: TextFixCatalog.MutationError.builtInActionCannotBeModified) {
            try catalog.movingCustomAction(
                id: TextFixAction.translateIdentifier,
                toCustomIndex: 0
            )
        }
    }

    @Test func reorderChangesOnlyCustomPositionsAndValidatesDestination() throws {
        let catalog = TextFixCatalog.defaults
        let markdownID = "default.markdown"
        let moved = try catalog.movingCustomAction(id: markdownID, toCustomIndex: 0)

        #expect(moved.actions.prefix(2).map(\.id) == [
            TextFixAction.translateIdentifier,
            TextFixAction.fixIdentifier,
        ])
        #expect(moved.customActions.first?.id == markdownID)
        #expect(Set(moved.customActions.map(\.id)) == Set(catalog.customActions.map(\.id)))
        #expect(throws: TextFixCatalog.MutationError.destinationIndexOutOfBounds) {
            try catalog.movingCustomAction(id: markdownID, toCustomIndex: 6)
        }
    }

    @Test func restoreDefaultsAppendsOnlyMissingRowsAndPreservesEveryExistingRow() throws {
        let customizedImprove = try makeCustom(
            id: "default.improve-writing",
            title: "My Improve",
            prompt: "My private improved-writing prompt",
            isEnabled: false
        )
        let withCustomization = try TextFixCatalog.defaults
            .replacingCustomAction(customizedImprove)
            .addingCustomAction(makeCustom(id: "user.personal", title: "Personal"))
            .deletingCustomAction(id: "default.summarize")
        let restored = try withCustomization.restoringDefaults()

        #expect(Array(restored.actions.dropLast()) == withCustomization.actions)
        #expect(restored.actions.last?.id == "default.summarize")
        #expect(restored.action(id: customizedImprove.id) == customizedImprove)
        #expect(restored.action(id: "user.personal") == withCustomization.action(id: "user.personal"))
        #expect(try restored.restoringDefaults() == restored)
    }

    @Test func restoreDefaultsFailsAtomicallyWhenTheCatalogIsFull() throws {
        let missingOneDefault = try TextFixCatalog.defaults.deletingCustomAction(
            id: "default.markdown"
        )
        let full = try (0..<93).reduce(missingOneDefault) { catalog, index in
            try catalog.addingCustomAction(makeCustom(id: "user.full.\(index)"))
        }

        #expect(full.actions.count == TextFixCatalog.maximumActionCount)
        #expect(
            throws: TextFixCatalog.MutationError.tooManyActions(
                maximumCount: TextFixCatalog.maximumActionCount
            )
        ) {
            try full.restoringDefaults()
        }
        #expect(full.action(id: "default.markdown") == nil)
    }

    @Test func runtimeCatalogIsSendableNotCodableAndRedactsNestedPrompts() {
        requireSendable(TextFixCatalog.self)
        let catalog = TextFixCatalog.defaults
        let secret = catalog.customActions.first?.prompt ?? "missing-secret"
        var dumped = ""
        dump(catalog, to: &dumped)

        #expect(((catalog as Any) is any Encodable) == false)
        #expect(((catalog as Any) is any Decodable) == false)
        for rendered in [String(describing: catalog), String(reflecting: catalog), dumped] {
            #expect(rendered.contains(secret) == false)
            #expect(rendered.contains("<redacted>"))
        }
    }

    private func makeCustom(
        id: String,
        title: String = "Custom",
        prompt: String = "Custom prompt",
        isEnabled: Bool = true
    ) throws -> TextFixAction {
        try TextFixAction(
            id: id,
            kind: .customPrompt,
            title: title,
            icon: .custom,
            prompt: prompt,
            isEnabled: isEnabled
        )
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
