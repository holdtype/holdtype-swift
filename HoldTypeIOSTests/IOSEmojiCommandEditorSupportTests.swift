import Foundation
import HoldTypeDomain
import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSEmojiCommandEditorSupportTests {
    @Test func presentationAndRoutesUseOnlyContentFreeIdentity() throws {
        let commandID = UUID()
        let configuration = EmojiCommandsConfiguration(
            isEnabled: true,
            enabledBuiltInSetIDs: ["ru"],
            customCommands: [
                CustomEmojiCommand(
                    id: commandID,
                    emoji: "PRIVATE-OUTPUT",
                    command: "PRIVATE-PHRASE"
                ),
            ]
        )

        #expect(
            IOSEmojiCommandsPresentation.summary(configuration)
                == "On · Russian · 1 custom"
        )
        #expect(
            IOSEmojiCommandsPresentation.summary(
                EmojiCommandsConfiguration(
                    isEnabled: false,
                    enabledBuiltInSetIDs: []
                )
            ) == "Off · Custom · 0 custom"
        )

        let reference = try #require(
            IOSBuiltInEmojiCommandReference(
                setID: "en",
                commandID: "smile"
            )
        )
        #expect(reference.command.emoji == "🙂")
        #expect(
            IOSBuiltInEmojiCommandReference(
                setID: "PRIVATE-PHRASE",
                commandID: "smile"
            ) == nil
        )

        let routes: [IOSLibraryRoute] = [
            .emojiCommands,
            .emojiSetSelection,
            .builtInEmojiCommand(reference),
            .newCustomEmojiCommand(commandID),
            .customEmojiCommand(commandID),
        ]
        for route in routes {
            #expect(!String(describing: route).contains("PRIVATE"))
            #expect(!String(reflecting: route).contains("PRIVATE"))
        }
        #expect(!String(describing: reference).contains("smile"))
        #expect(Mirror(reflecting: reference).children.isEmpty)
    }

    @Test func draftKeepsRawFieldsAndParsesOneAliasPerLine() {
        let id = UUID()
        var draft = IOSEmojiCommandEditorDraft(id: id)
        draft.output = "  🚀  "
        draft.primaryPhrase = "  launch   now  "
        draft.aliasesText = " first alias \n\n second   alias \n first alias "

        let candidate = draft.candidate(isEnabled: false)

        #expect(candidate.id == id)
        #expect(candidate.emoji == "  🚀  ")
        #expect(candidate.command == "  launch   now  ")
        #expect(
            candidate.aliases
                == ["first alias", "second   alias", "first alias"]
        )
        #expect(!candidate.isEnabled)
        #expect(
            candidate.normalizedForStorage
                == CustomEmojiCommand(
                    id: id,
                    emoji: "🚀",
                    command: "launch now",
                    aliases: ["first alias", "second alias"],
                    isEnabled: false
                )
        )
    }

    @Test func validationRequiresPrimaryAndRejectsEveryCustomPhraseCollision() {
        let existing = CustomEmojiCommand(
            id: UUID(),
            emoji: "🙂",
            command: "ÉMOJI smile",
            aliases: ["happy face"]
        )

        #expect(
            IOSEmojiCommandDraftValidation.resolve(
                candidate: CustomEmojiCommand(
                    emoji: " ",
                    command: "valid phrase"
                ),
                excluding: nil,
                customCommands: [existing]
            ) == .missingOutput
        )
        #expect(
            IOSEmojiCommandDraftValidation.resolve(
                candidate: CustomEmojiCommand(
                    emoji: "🔥",
                    command: " ",
                    aliases: ["alias cannot become primary"]
                ),
                excluding: nil,
                customCommands: [existing]
            ) == .missingPrimaryPhrase
        )
        #expect(
            IOSEmojiCommandDraftValidation.resolve(
                candidate: CustomEmojiCommand(
                    emoji: "🔥",
                    command: "emoji, smíle"
                ),
                excluding: nil,
                customCommands: [existing]
            ) == .customPhraseCollision
        )
        #expect(
            IOSEmojiCommandDraftValidation.resolve(
                candidate: CustomEmojiCommand(
                    emoji: "🔥",
                    command: "different",
                    aliases: ["HAPPY. FACE"]
                ),
                excluding: nil,
                customCommands: [existing]
            ) == .customPhraseCollision
        )

        let builtInOverlap = CustomEmojiCommand(
            emoji: "🆕",
            command: "emoji smile"
        )
        #expect(
            IOSEmojiCommandDraftValidation.resolve(
                candidate: builtInOverlap,
                excluding: nil,
                customCommands: []
            ) == .valid
        )
    }

    @Test func newSessionRetainsUUIDAndDraftAcrossFailureAndRetry() throws {
        let id = UUID()
        var session = IOSEmojiCommandEditorSession(newCommandID: id)
        session.set("🚀", at: \.output)
        session.set("launch now", at: \.primaryPhrase)

        let firstResult = session.beginSave(customCommands: [])
        let first = try #require(firstResult)
        #expect(first.commandID == id)
        assertAddMutation(first.mutation, id: id)

        session.commitFailed(currentCommand: nil)
        #expect(session.phase == .saveFailed)
        #expect(session.isDirty)
        #expect(session.draft.id == id)
        #expect(session.draft.output == "🚀")

        let retryResult = session.beginSave(customCommands: [])
        let retry = try #require(retryResult)
        #expect(retry.commandID == id)
        assertAddMutation(retry.mutation, id: id)
    }

    @Test func cleanEditorAdoptsButDirtyEditorRequiresReloadOrReplace()
        throws {
        let id = UUID()
        let original = CustomEmojiCommand(
            id: id,
            emoji: "🙂",
            command: "smile",
            isEnabled: true
        )
        var session = IOSEmojiCommandEditorSession(command: original)
        var changed = original
        changed.command = "new durable phrase"

        session.observeDurableCommand(changed)
        #expect(session.phase == .idle)
        #expect(session.draft.primaryPhrase == "new durable phrase")
        #expect(!session.isDirty)

        session.set("local draft", at: \.primaryPhrase)
        var changedAgain = changed
        changedAgain.emoji = "✅"
        changedAgain.isEnabled = false
        session.observeDurableCommand(changedAgain)

        #expect(session.phase == .changedElsewhere)
        #expect(session.draft.primaryPhrase == "local draft")
        #expect(session.canReloadLatest)
        #expect(session.canReplaceLatest)
        let blockedSave = session.beginSave(
            customCommands: [changedAgain]
        )
        #expect(blockedSave == nil)

        let replaceResult = session.beginSave(
            customCommands: [changedAgain],
            replacingLatest: true
        )
        let replace = try #require(replaceResult)
        guard case .emojiCommands(
            .update(let expected, let requested)
        ) = replace.mutation else {
            Issue.record("Expected emoji update mutation")
            return
        }
        #expect(expected == changedAgain)
        #expect(requested.command == "local draft")
        #expect(requested.emoji == "🙂")
        #expect(!requested.isEnabled)
    }

    @Test func reloadDeletedAndRepeatedReplaceRaceFailClosed() throws {
        let id = UUID()
        let original = CustomEmojiCommand(
            id: id,
            emoji: "🙂",
            command: "smile"
        )
        var session = IOSEmojiCommandEditorSession(command: original)
        session.set("local", at: \.primaryPhrase)

        var latest = original
        latest.emoji = "🔥"
        session.observeDurableCommand(latest)
        #expect(session.phase == .changedElsewhere)

        session.reloadLatest()
        #expect(session.phase == .idle)
        #expect(session.draft.output == "🔥")
        #expect(!session.isDirty)

        session.set("local again", at: \.primaryPhrase)
        var secondLatest = latest
        secondLatest.command = "second latest"
        session.observeDurableCommand(secondLatest)
        let replaceResult = session.beginSave(
            customCommands: [secondLatest],
            replacingLatest: true
        )
        _ = try #require(replaceResult)

        var thirdLatest = secondLatest
        thirdLatest.aliases = ["another scene"]
        session.completeWithoutCommit(
            disposition: .conflict,
            returnedCommand: thirdLatest,
            currentCommand: thirdLatest
        )
        #expect(session.phase == .changedElsewhere)
        #expect(session.draft.primaryPhrase == "local again")

        let retryResult = session.beginSave(
            customCommands: [thirdLatest],
            replacingLatest: true
        )
        let retry = try #require(retryResult)
        guard case .emojiCommands(.update(let expected, _)) = retry.mutation
        else {
            Issue.record("Expected retry update mutation")
            return
        }
        #expect(expected == thirdLatest)

        session.completeWithoutCommit(
            disposition: .targetMissing,
            returnedCommand: nil,
            currentCommand: nil
        )
        #expect(session.phase == .deletedElsewhere)
        let deletedSave = session.beginSave(
            customCommands: [],
            replacingLatest: true
        )
        #expect(deletedSave == nil)
    }

    @Test func failedSaveDoesNotHideAConcurrentDurableChange() {
        let original = CustomEmojiCommand(
            id: UUID(),
            emoji: "🙂",
            command: "smile"
        )
        var session = IOSEmojiCommandEditorSession(command: original)
        session.set("local draft", at: \.primaryPhrase)
        _ = session.beginSave(customCommands: [original])

        var changed = original
        changed.command = "changed elsewhere"
        session.commitFailed(currentCommand: changed)

        #expect(session.phase == .changedElsewhere)
        #expect(session.draft.primaryPhrase == "local draft")
        #expect(session.latest == changed)
    }

    @Test func newerPublicationPreservesDraftAsChangedElsewhere() throws {
        let original = CustomEmojiCommand(
            id: UUID(),
            emoji: "🙂",
            command: "smile"
        )
        var session = IOSEmojiCommandEditorSession(command: original)
        session.set("saved draft", at: \.primaryPhrase)
        let request = session.beginSave(customCommands: [original])
        _ = try #require(request)

        var transactionResult = original
        transactionResult.command = "saved draft"
        session.observeDurableCommand(transactionResult)

        var newer = transactionResult
        newer.aliases = ["newer publication"]
        session.observeDurableCommand(newer)
        session.commitSucceeded(
            returnedCommand: transactionResult,
            currentCommand: newer
        )

        #expect(session.phase == .changedElsewhere)
        #expect(session.baseline == newer)
        #expect(session.latest == newer)
        #expect(session.draft.primaryPhrase == "saved draft")
        #expect(session.draft.aliasesText.isEmpty)
        #expect(session.isDirty)

        session.observeDurableCommand(newer)
        #expect(session.phase == .changedElsewhere)
        #expect(session.canReplaceLatest)
        #expect(session.beginSave(customCommands: [newer]) == nil)

        session.set("smile", at: \.primaryPhrase)
        #expect(session.phase == .changedElsewhere)
        #expect(session.isDirty)
    }

    @Test func newerEnabledPublicationCanMergeAfterSuccessfulSave() throws {
        let original = CustomEmojiCommand(
            id: UUID(),
            emoji: "🙂",
            command: "smile",
            isEnabled: true
        )
        var session = IOSEmojiCommandEditorSession(command: original)
        session.set("  saved   draft  ", at: \.primaryPhrase)
        let request = session.beginSave(customCommands: [original])
        _ = try #require(request)

        var returned = original
        returned.command = "saved draft"
        var current = returned
        current.isEnabled = false
        session.commitSucceeded(
            returnedCommand: returned,
            currentCommand: current
        )

        #expect(session.phase == .saved)
        #expect(session.baseline == current)
        #expect(session.latest == current)
        #expect(session.draft.primaryPhrase == "saved draft")
        #expect(!session.isDirty)
    }

    @Test func failedCleanDeleteKeepsAVisibleNotSavedState() {
        let command = CustomEmojiCommand(
            id: UUID(),
            emoji: "🙂",
            command: "smile"
        )
        var session = IOSEmojiCommandEditorSession(command: command)

        session.commitFailed(
            currentCommand: command,
            forceNotSaved: true
        )

        #expect(session.phase == .saveFailed)
        #expect(!session.isDirty)
        #expect(session.baseline == command)
    }

    @Test func editorSupportSurfacesAreRedacted() throws {
        let canary = "EMOJI-EDITOR-PRIVATE-CANARY"
        let command = CustomEmojiCommand(
            id: UUID(),
            emoji: canary,
            command: canary,
            aliases: [canary]
        )
        var session = IOSEmojiCommandEditorSession(command: command)
        session.set(canary + "-draft", at: \.primaryPhrase)
        let requestResult = session.beginSave(customCommands: [command])
        let request = try #require(requestResult)
        let values: [Any] = [
            IOSEmojiCommandEditorDraft(command: command),
            session,
            request,
            IOSCustomEmojiCommandReference(expected: command),
            IOSEmojiCommandsNotice.notSaved,
            IOSEmojiCommandDraftValidation.customPhraseCollision,
        ]

        for value in values {
            #expect(!String(describing: value).contains(canary))
            #expect(!String(reflecting: value).contains(canary))
            #expect(Mirror(reflecting: value).children.isEmpty)
        }

        let summary = IOSLibrarySummaryList(
            content: IOSLibraryContent(
                emojiCommandsConfiguration: EmojiCommandsConfiguration(
                    customCommands: [command]
                )
            ),
            showsSaveFailure: false
        )
        #expect(!String(reflecting: summary).contains(canary))
        #expect(Mirror(reflecting: summary).children.isEmpty)
    }

    private func assertAddMutation(
        _ mutation: IOSLibraryMutation,
        id: UUID,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard case .emojiCommands(.add(let command)) = mutation else {
            Issue.record(
                "Expected emoji add mutation",
                sourceLocation: sourceLocation
            )
            return
        }
        #expect(command.id == id, sourceLocation: sourceLocation)
        #expect(command.emoji == "🚀", sourceLocation: sourceLocation)
        #expect(
            command.command == "launch now",
            sourceLocation: sourceLocation
        )
    }
}
