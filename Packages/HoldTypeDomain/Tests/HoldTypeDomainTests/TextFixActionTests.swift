import Testing
import HoldTypeDomain

struct TextFixActionTests {
    @Test func customActionPreservesEveryValidatedValueExactly() throws {
        let prompt = "  Preserve this prompt exactly.\n"
        let action = try TextFixAction(
            id: "user.example",
            kind: .customPrompt,
            title: "  Example Fix  ",
            icon: .rewrite,
            prompt: prompt,
            isEnabled: false
        )

        #expect(action.id == "user.example")
        #expect(action.kind == .customPrompt)
        #expect(action.title == "  Example Fix  ")
        #expect(action.icon == .rewrite)
        #expect(action.prompt == prompt)
        #expect(action.isEnabled == false)
    }

    @Test func builtInIdentityAndPayloadInvariantsAreEnforced() throws {
        #expect(throws: TextFixAction.ValidationError.invalidBuiltInIdentifier) {
            try TextFixAction(
                id: "not-translate",
                kind: .translate,
                title: "Translate",
                icon: .translate,
                prompt: nil
            )
        }
        #expect(throws: TextFixAction.ValidationError.reservedBuiltInIdentifier) {
            try TextFixAction(
                id: TextFixAction.fixIdentifier,
                kind: .customPrompt,
                title: "Custom",
                icon: .custom,
                prompt: "Custom prompt"
            )
        }
        #expect(throws: TextFixAction.ValidationError.unexpectedPrompt) {
            try TextFixAction(
                id: TextFixAction.fixIdentifier,
                kind: .fix,
                title: "Fix",
                icon: .fix,
                prompt: "Not allowed"
            )
        }
        #expect(throws: TextFixAction.ValidationError.builtInActionCannotBeDisabled) {
            try TextFixAction(
                id: TextFixAction.translateIdentifier,
                kind: .translate,
                title: "Translate",
                icon: .translate,
                prompt: nil,
                isEnabled: false
            )
        }
    }

    @Test func identifierTitleAndPromptMustContainVisibleContent() {
        #expect(throws: TextFixAction.ValidationError.emptyIdentifier) {
            try TextFixAction(
                id: " \n ",
                kind: .customPrompt,
                title: "Title",
                icon: .custom,
                prompt: "Prompt"
            )
        }
        #expect(throws: TextFixAction.ValidationError.emptyTitle) {
            try TextFixAction(
                id: "user.blank-title",
                kind: .customPrompt,
                title: "\n ",
                icon: .custom,
                prompt: "Prompt"
            )
        }
        #expect(throws: TextFixAction.ValidationError.missingPrompt) {
            try TextFixAction(
                id: "user.missing-prompt",
                kind: .customPrompt,
                title: "Title",
                icon: .custom,
                prompt: nil
            )
        }
        #expect(throws: TextFixAction.ValidationError.emptyPrompt) {
            try TextFixAction(
                id: "user.blank-prompt",
                kind: .customPrompt,
                title: "Title",
                icon: .custom,
                prompt: " \n "
            )
        }
    }

    @Test func titleLimitCountsUserPerceivedCharacters() throws {
        let familyEmoji = "👨‍👩‍👧‍👦"
        let acceptedTitle = String(repeating: familyEmoji, count: 80)
        let accepted = try TextFixAction(
            id: "user.eighty-graphemes",
            kind: .customPrompt,
            title: acceptedTitle,
            icon: .custom,
            prompt: "Prompt"
        )

        #expect(accepted.title.count == TextFixAction.maximumTitleCharacterCount)
        #expect(
            throws: TextFixAction.ValidationError.titleTooLong(
                maximumCharacterCount: TextFixAction.maximumTitleCharacterCount
            )
        ) {
            try TextFixAction(
                id: "user.eighty-one-graphemes",
                kind: .customPrompt,
                title: acceptedTitle + familyEmoji,
                icon: .custom,
                prompt: "Prompt"
            )
        }
    }

    @Test func identifierAndPromptLimitsUseUTF8Bytes() throws {
        let acceptedIdentifier = String(
            repeating: "a",
            count: TextFixAction.maximumIdentifierUTF8ByteCount
        )
        let acceptedPrompt = String(
            repeating: "é",
            count: TextFixAction.maximumPromptUTF8ByteCount / 2
        )
        let action = try TextFixAction(
            id: acceptedIdentifier,
            kind: .customPrompt,
            title: "At Limits",
            icon: .custom,
            prompt: acceptedPrompt
        )

        #expect(action.id.utf8.count == TextFixAction.maximumIdentifierUTF8ByteCount)
        #expect(action.prompt?.utf8.count == TextFixAction.maximumPromptUTF8ByteCount)
        #expect(
            throws: TextFixAction.ValidationError.identifierTooLarge(
                maximumUTF8ByteCount: TextFixAction.maximumIdentifierUTF8ByteCount
            )
        ) {
            try TextFixAction(
                id: acceptedIdentifier + "a",
                kind: .customPrompt,
                title: "Too Large",
                icon: .custom,
                prompt: "Prompt"
            )
        }
        #expect(
            throws: TextFixAction.ValidationError.promptTooLarge(
                maximumUTF8ByteCount: TextFixAction.maximumPromptUTF8ByteCount
            )
        ) {
            try TextFixAction(
                id: "user.prompt-too-large",
                kind: .customPrompt,
                title: "Too Large",
                icon: .custom,
                prompt: acceptedPrompt + "a"
            )
        }
    }

    @Test func runtimeValuesAreSendableNotWireContractsAndRedactPrompts() throws {
        requireSendable(TextFixAction.self)
        requireSendable(TextFixActionKind.self)
        requireSendable(TextFixIcon.self)
        let secret = "PRIVATE-PROMPT-CANARY"
        let action = try TextFixAction(
            id: "user.private",
            kind: .customPrompt,
            title: "Private",
            icon: .custom,
            prompt: secret
        )
        var dumped = ""
        dump(action, to: &dumped)

        #expect(((action as Any) is any Encodable) == false)
        #expect(((action as Any) is any Decodable) == false)
        for rendered in [String(describing: action), String(reflecting: action), dumped] {
            #expect(rendered.contains(secret) == false)
            #expect(rendered.contains("<redacted>"))
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
