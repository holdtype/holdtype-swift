import Foundation
import Testing
import HoldTypeDomain

struct TextTransformationRequestTests {
    @Test func preservesExactSourcePromptAndModelWithoutTranscriptNormalization() throws {
        let source = "  First line\nSecond line  \n"
        let prompt = "  Keep this prompt exact.\n"
        let model = " custom-model "
        let request = try TextTransformationRequest(
            sourceText: source,
            prompt: prompt,
            model: model,
            reasoningEffort: .max,
            requestTimeoutSeconds: 60
        )

        #expect(request.sourceText == source)
        #expect(request.prompt == prompt)
        #expect(request.model == model)
        #expect(request.reasoningEffort == .max)
        #expect(request.requestTimeoutSeconds == 60)
    }

    @Test func rejectsBlankSourcePromptAndModel() {
        #expect(throws: TextTransformationRequest.ValidationError.emptySource) {
            try TextTransformationRequest(
                sourceText: " \n ",
                prompt: "Prompt",
                model: "model"
            )
        }
        #expect(throws: TextTransformationRequest.ValidationError.emptyPrompt) {
            try TextTransformationRequest(
                sourceText: "Source",
                prompt: "\n ",
                model: "model"
            )
        }
        #expect(throws: TextTransformationRequest.ValidationError.emptyModel) {
            try TextTransformationRequest(
                sourceText: "Source",
                prompt: "Prompt",
                model: " \n"
            )
        }
        for timeout: TimeInterval in [0, -1, .infinity, .nan] {
            #expect(throws: TextTransformationRequest.ValidationError.invalidRequestTimeout) {
                try TextTransformationRequest(
                    sourceText: "Source",
                    prompt: "Prompt",
                    model: "model",
                    requestTimeoutSeconds: timeout
                )
            }
        }
    }

    @Test func sourceAndPromptLimitsUseExactUTF8ByteCounts() throws {
        let acceptedSource = String(
            repeating: "é",
            count: TextTransformationRequest.maximumSourceUTF8ByteCount / 2
        )
        let acceptedPrompt = String(
            repeating: "é",
            count: TextTransformationRequest.maximumPromptUTF8ByteCount / 2
        )
        let request = try TextTransformationRequest(
            sourceText: acceptedSource,
            prompt: acceptedPrompt,
            model: "model"
        )

        #expect(request.sourceText.utf8.count == TextTransformationRequest.maximumSourceUTF8ByteCount)
        #expect(request.prompt.utf8.count == TextTransformationRequest.maximumPromptUTF8ByteCount)
        #expect(
            throws: TextTransformationRequest.ValidationError.sourceTooLarge(
                maximumUTF8ByteCount: TextTransformationRequest.maximumSourceUTF8ByteCount
            )
        ) {
            try TextTransformationRequest(
                sourceText: acceptedSource + "a",
                prompt: "Prompt",
                model: "model"
            )
        }
        #expect(
            throws: TextTransformationRequest.ValidationError.promptTooLarge(
                maximumUTF8ByteCount: TextTransformationRequest.maximumPromptUTF8ByteCount
            )
        ) {
            try TextTransformationRequest(
                sourceText: "Source",
                prompt: acceptedPrompt + "a",
                model: "model"
            )
        }
    }

    @Test func writingSkillRequiresARecognizedCompatibleModel() throws {
        let request = try TextTransformationRequest(
            sourceText: "Source",
            prompt: "Rewrite it.",
            model: "gpt-5.6-terra",
            usesBuiltInWritingSkill: true
        )

        #expect(request.usesBuiltInWritingSkill)
        #expect(
            throws: TextTransformationRequest.ValidationError
                .unsupportedBuiltInWritingSkillModel
        ) {
            try TextTransformationRequest(
                sourceText: "Source",
                prompt: "Rewrite it.",
                model: "custom-provider-model",
                usesBuiltInWritingSkill: true
            )
        }
    }

    @Test func runtimeRequestIsSendableNotCodableAndRedactsSensitiveText() throws {
        requireSendable(TextTransformationRequest.self)
        let sourceSecret = "PRIVATE-SOURCE-CANARY"
        let promptSecret = "PRIVATE-PROMPT-CANARY"
        let modelSecret = "PRIVATE-MODEL-CANARY"
        let request = try TextTransformationRequest(
            sourceText: sourceSecret,
            prompt: promptSecret,
            model: modelSecret
        )
        var dumped = ""
        dump(request, to: &dumped)

        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
        for rendered in [String(describing: request), String(reflecting: request), dumped] {
            #expect(rendered.contains(sourceSecret) == false)
            #expect(rendered.contains(promptSecret) == false)
            #expect(rendered.contains(modelSecret) == false)
            #expect(rendered.contains("<redacted>"))
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
