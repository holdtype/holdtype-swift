import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSLibraryHomeView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner
    @State private var isLoading = false
    @Binding var hasUnsavedLibraryEditor: Bool
    @Binding var hasBlockingLibraryOperation: Bool

    var body: some View {
        Group {
            switch stateOwner.state {
            case .notLoaded:
                IOSDestinationLoadingView(title: "Loading Library")
            case .loadFailed:
                IOSDestinationLoadFailureView(
                    title: "Library Unavailable",
                    description:
                        "HoldType couldn’t read your Library. No empty "
                        + "replacement was created.",
                    isRetrying: isLoading,
                    retry: retryLoad
                )
            case .ready(let content):
                IOSLibrarySummaryList(
                    content: content,
                    showsSaveFailure: false
                )
            case .saveFailed(let lastDurableValue):
                IOSLibrarySummaryList(
                    content: lastDurableValue,
                    showsSaveFailure: true
                )
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: IOSLibraryRoute.self) { route in
            switch route {
            case .dictionary:
                IOSDictionaryView(
                    hasUnsavedSceneEditor: $hasUnsavedLibraryEditor,
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .emojiCommands:
                IOSEmojiCommandsView(
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .emojiSetSelection:
                IOSEmojiSetSelectionView()
            case .builtInEmojiCommand(let reference):
                IOSBuiltInEmojiCommandDetailView(reference: reference)
            case .newCustomEmojiCommand(let id):
                IOSCustomEmojiCommandEditorView(
                    mode: .add(id),
                    hasUnsavedSceneEditor: $hasUnsavedLibraryEditor,
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .customEmojiCommand(let id):
                IOSCustomEmojiCommandEditorView(
                    mode: .edit(id),
                    hasUnsavedSceneEditor: $hasUnsavedLibraryEditor,
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .replacementRules:
                IOSReplacementRulesView(
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .newReplacementRule(let id):
                IOSReplacementRuleEditorView(
                    mode: .add(id),
                    hasUnsavedSceneEditor: $hasUnsavedLibraryEditor,
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            case .replacementRule(let id):
                IOSReplacementRuleEditorView(
                    mode: .edit(id),
                    hasUnsavedSceneEditor: $hasUnsavedLibraryEditor,
                    hasBlockingSceneOperation:
                        $hasBlockingLibraryOperation
                )
            }
        }
        .accessibilityIdentifier(
            IOSContainingAppDestination.library.accessibilityIdentifier
        )
        .task {
            guard case .notLoaded = stateOwner.state else { return }
            await load()
        }
    }

    private func retryLoad() {
        Task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        _ = try? await stateOwner.load()
    }
}

struct IOSLibrarySummaryList: View {
    let content: IOSLibraryContent
    let showsSaveFailure: Bool

    var body: some View {
        List {
            if showsSaveFailure {
                IOSSaveFailureSection(subject: "Library")
            }

            Section("Saved Content") {
                NavigationLink(value: IOSLibraryRoute.dictionary) {
                    IOSLibraryDestinationLabel(
                        destination: .dictionary,
                        summary: countLabel(
                            content.customDictionary.entries.count,
                            singular: "entry",
                            plural: "entries"
                        )
                    )
                }
                .accessibilityIdentifier(
                    IOSLibraryDestination.dictionary
                        .rowAccessibilityIdentifier
                )

                NavigationLink(value: IOSLibraryRoute.emojiCommands) {
                    IOSLibraryDestinationLabel(
                        destination: .emojiCommands,
                        summary: IOSEmojiCommandsPresentation.summary(
                            content.emojiCommandsConfiguration
                        )
                    )
                }
                .accessibilityIdentifier(
                    IOSLibraryDestination.emojiCommands
                        .rowAccessibilityIdentifier
                )

                NavigationLink(value: IOSLibraryRoute.replacementRules) {
                    IOSLibraryDestinationLabel(
                        destination: .replacementRules,
                        summary: IOSReplacementRulesPresentation.summary(
                            content.replacementRules
                        )
                    )
                }
                .accessibilityIdentifier(
                    IOSLibraryDestination.replacementRules
                        .rowAccessibilityIdentifier
                )
            }

            Section {
                Text(
                    "Library content stays in HoldType’s private storage. It "
                    + "is not copied into the keyboard extension or App Group."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func countLabel(
        _ count: Int,
        singular: String,
        plural: String
    ) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

}

extension IOSLibrarySummaryList: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

private struct IOSLibraryDestinationLabel: View {
    let destination: IOSLibraryDestination
    let summary: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: destination.systemImage)
        }
    }
}
