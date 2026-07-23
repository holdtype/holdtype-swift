import HoldTypeDomain
import HoldTypePersistence
import Testing
@testable import HoldType

@MainActor
struct FixesEditorPresentationTests {
    @Test func finiteIconOptionsCoverEverySupportedToken() {
        #expect(FixesEditorIconOption.all.count == TextFixIcon.allCases.count)
        #expect(
            FixesEditorIconOption.all.map(\.icon.rawValue).sorted()
                == TextFixIcon.allCases.map(\.rawValue).sorted()
        )
        #expect(FixesEditorIconOption.all.allSatisfy { !$0.title.isEmpty })
        #expect(FixesEditorIconOption.all.allSatisfy { !$0.systemImageName.isEmpty })
    }

    @Test func actionPresentationMarksBuiltInPendingAndDisabledStates() {
        let builtIn = FixesEditorActionPresentation(
            action: TextFixCatalog.defaults.actions[0]
        )
        let pending = FixesEditorActionPresentation(
            draft: FixesEditorDraft(
                id: "custom.pending",
                title: "Pending",
                prompt: "A prompt",
                icon: .custom,
                isEnabled: false
            )
        )

        #expect(builtIn.isBuiltIn)
        #expect(builtIn.subtitle == "Built-in")
        #expect(!builtIn.isPending)
        #expect(!pending.isBuiltIn)
        #expect(pending.isPending)
        #expect(!pending.isEnabled)
        #expect(pending.subtitle == "Not saved")
    }

    @Test func draftValidationUsesCharacterAndUTF8Limits() {
        let accepted = FixesEditorDraftValidation(
            title: String(
                repeating: "🙂",
                count: TextFixAction.maximumTitleCharacterCount
            ),
            prompt: String(
                repeating: "é",
                count: TextFixAction.maximumPromptUTF8ByteCount / 2
            )
        )
        let rejected = FixesEditorDraftValidation(
            title: String(
                repeating: "a",
                count: TextFixAction.maximumTitleCharacterCount + 1
            ),
            prompt: String(
                repeating: "é",
                count: TextFixAction.maximumPromptUTF8ByteCount / 2 + 1
            )
        )

        #expect(accepted.isValid)
        #expect(rejected.titleMessage?.contains("80") == true)
        #expect(rejected.promptMessage?.contains("8192") == true)
    }

    @Test func corruptAndUnsupportedIssuesPromisePreservation() {
        let corrupt = FixesEditorIssue.loading(
            TextFixCatalogRepositoryError.malformedData
        )
        let unsupported = FixesEditorIssue.loading(
            TextFixCatalogRepositoryError.unsupportedSchemaVersion
        )

        #expect(corrupt.kind == .load)
        #expect(corrupt.message.contains("preserved"))
        #expect(corrupt.message.contains("will not replace"))
        #expect(unsupported.message.contains("preserved"))
        #expect(unsupported.message.contains("will not overwrite"))
        #expect(corrupt.allowsRetry)
    }
}
