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
                IOSDestinationLoadingView(title: "Loading Dictation Rules")
            case .loadFailed:
                IOSDestinationLoadFailureView(
                    title: "Dictation Rules Unavailable",
                    description:
                        "HoldType couldn’t read your saved rules. No empty "
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
        .navigationTitle("Dictation Rules")
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
    static let introduction =
        "Teach HoldType the words you use and choose how the final text "
        + "should look. These rules apply automatically to new dictations."

    let content: IOSLibraryContent
    let showsSaveFailure: Bool

    var body: some View {
        List {
            if showsSaveFailure {
                IOSSaveFailureSection(subject: "Dictation Rules")
            }

            Section {
                NavigationLink(value: IOSLibraryRoute.dictionary) {
                    IOSLibraryDestinationLabel(
                        destination: .dictionary,
                        summary: summary(
                            for: .dictionary,
                            status: countLabel(
                                content.customDictionary.entries.count,
                                singular: "entry",
                                plural: "entries"
                            )
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
                        summary: summary(
                            for: .emojiCommands,
                            status: IOSEmojiCommandsPresentation.summary(
                                content.emojiCommandsConfiguration
                            )
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
                        summary: summary(
                            for: .replacementRules,
                            status: IOSReplacementRulesPresentation.summary(
                                content.replacementRules
                            )
                        )
                    )
                }
                .accessibilityIdentifier(
                    IOSLibraryDestination.replacementRules
                        .rowAccessibilityIdentifier
                )
            } header: {
                Text(Self.introduction)
                    .textCase(nil)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summary(
        for destination: IOSLibraryDestination,
        status: String
    ) -> String {
        "\(destination.detail) · \(status)"
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
