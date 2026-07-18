import Foundation
import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSEmojiCommandsView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner

    @State private var searchQuery = IOSLibrarySearchQuery()
    @State private var notice: IOSEmojiCommandsNotice?
    @State private var pendingDelete: IOSCustomEmojiCommandReference?
    @State private var showsDeleteConfirmation = false
    @State private var operationInFlight = false
    @State private var isLoading = false
    @State private var newCommandID = UUID()
    @Binding private var hasBlockingSceneOperation: Bool

    init(
        hasBlockingSceneOperation: Binding<Bool> = .constant(false)
    ) {
        _hasBlockingSceneOperation = hasBlockingSceneOperation
    }

    var body: some View {
        Group {
            switch stateOwner.state {
            case .notLoaded:
                IOSDestinationLoadingView(title: "Loading Emoji Commands")
            case .loadFailed:
                IOSDestinationLoadFailureView(
                    title: "Emoji Commands Unavailable",
                    description:
                        "HoldType couldn’t read your saved rules. No empty "
                        + "replacement was created.",
                    isRetrying: isLoading,
                    retry: retryLoad
                )
            case .ready(let content):
                commandsList(
                    configuration: content.emojiCommandsConfiguration,
                    showsSharedSaveFailure: false
                )
            case .saveFailed(let lastDurableValue):
                commandsList(
                    configuration: lastDurableValue
                        .emojiCommandsConfiguration,
                    showsSharedSaveFailure: true
                )
            }
        }
        .navigationTitle("Emoji Commands")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            operationInFlight && hasBlockingSceneOperation
        )
        .confirmationDialog(
            "Delete Custom Command?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Command", role: .destructive) {
                guard let pendingDelete else { return }
                self.pendingDelete = nil
                beginDelete(pendingDelete)
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes one custom voice command.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if notice == .notSaved {
                IOSLibraryPersistentFailureStatus()
            }
        }
        .accessibilityIdentifier("ios.library.emoji-commands.screen")
    }

    private func commandsList(
        configuration: EmojiCommandsConfiguration,
        showsSharedSaveFailure: Bool
    ) -> some View {
        let selection = IOSBuiltInEmojiSetSelection(
            storedIdentifiers: configuration.enabledBuiltInSetIDs
        ) ?? .custom
        let builtInRows = filteredBuiltInRows(
            selection.commandSet?.commands ?? []
        )
        let customRows = filteredCustomRows(configuration.customCommands)

        return List {
            if showsSharedSaveFailure, notice != .notSaved {
                IOSSaveFailureSection(subject: "Dictation Rules")
            }

            if let notice {
                IOSEmojiCommandsNoticeSection(notice: notice)
            }

            Section("Voice Replacement") {
                Toggle(
                    "Replace Spoken Commands",
                    isOn: Binding(
                        get: { configuration.isEnabled },
                        set: {
                            beginGlobalToggle(
                                expected: configuration.isEnabled,
                                requested: $0
                            )
                        }
                    )
                )
                .disabled(operationInFlight)

                Text(
                    "When enabled, HoldType replaces recognized commands "
                        + "locally after transcription. Turning this off "
                        + "keeps every set and custom command."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Active Built-in Set") {
                NavigationLink(value: IOSLibraryRoute.emojiSetSelection) {
                    LabeledContent("Active Set", value: selection.iosDisplayName)
                }
                .accessibilityIdentifier(
                    "ios.library.emoji-commands.active-set.row"
                )
            }

            Section("Built-in Catalog") {
                if selection == .custom {
                    ContentUnavailableView {
                        Label("Custom Set Selected", systemImage: "person.crop.circle")
                    } description: {
                        Text(
                            "Choose a language set to browse built-in "
                                + "commands. Custom commands remain active."
                        )
                    }
                } else if builtInRows.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Commands", systemImage: "magnifyingglass")
                    } description: {
                        Text("Clear search to show the built-in catalog.")
                    }
                } else {
                    ForEach(builtInRows) { row in
                        NavigationLink(
                            value: IOSLibraryRoute.builtInEmojiCommand(
                                row.reference
                            )
                        ) {
                            IOSBuiltInEmojiCommandRow(command: row.command)
                        }
                        .accessibilityIdentifier(
                            "ios.library.emoji-commands.catalog."
                                + "\(row.reference.setID)."
                                + row.reference.commandID
                        )
                    }
                }
            }

            Section("Custom Commands") {
                NavigationLink(
                    value: IOSLibraryRoute.newCustomEmojiCommand(
                        newCommandID
                    )
                ) {
                    Label("Add Custom Command", systemImage: "plus")
                }
                .accessibilityIdentifier(
                    "ios.library.emoji-commands.add.row"
                )

                if configuration.customCommands.isEmpty {
                    ContentUnavailableView {
                        Label("No Custom Commands", systemImage: "face.smiling")
                    } description: {
                        Text("Add a spoken phrase and its output.")
                    }
                } else if customRows.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Commands", systemImage: "magnifyingglass")
                    } description: {
                        Text("Clear search to show custom commands.")
                    }
                } else {
                    ForEach(customRows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle(
                                "Enable Command",
                                isOn: Binding(
                                    get: { row.command.isEnabled },
                                    set: {
                                        beginCommandToggle(
                                            row.command,
                                            requested: $0
                                        )
                                    }
                                )
                            )
                            .labelsHidden()
                            .accessibilityLabel(
                                "Enable \(row.command.displayCommand)"
                            )
                            .disabled(operationInFlight)

                            NavigationLink(
                                value: IOSLibraryRoute.customEmojiCommand(
                                    row.command.id
                                )
                            ) {
                                IOSCustomEmojiCommandRow(
                                    command: row.command
                                )
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                requestDelete(row.command)
                            }
                        }
                        .contextMenu {
                            Button("Delete Command", role: .destructive) {
                                requestDelete(row.command)
                            }
                        }
                        .accessibilityAction(named: "Delete Command") {
                            requestDelete(row.command)
                        }
                        .accessibilityIdentifier(
                            "ios.library.emoji-commands.custom."
                                + row.command.id.uuidString.lowercased()
                        )
                    }
                }
            }

            Section {
                Text(
                    "Spoken phrases help guide transcription, then HoldType "
                        + "inserts the matching emoji locally. Commands are not "
                        + "copied into the keyboard."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .searchable(
            text: $searchQuery.text,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search Emoji Commands"
        )
        .scrollDismissesKeyboard(.interactively)
        .disabled(operationInFlight)
        .onChange(
            of: configuration.customCommands.map(\.id),
            initial: true
        ) { _, identifiers in
            if identifiers.contains(newCommandID) {
                newCommandID = UUID()
            }
        }
    }

    private func filteredBuiltInRows(
        _ commands: [EmojiCommand]
    ) -> [IOSBuiltInEmojiCommandRowModel] {
        let query = normalizedSearchQuery
        return commands.compactMap { command in
            guard let commandSet = currentConfiguration.flatMap({
                IOSBuiltInEmojiSetSelection(
                    storedIdentifiers: $0.enabledBuiltInSetIDs
                )?.commandSet
            }), let reference = IOSBuiltInEmojiCommandReference(
                setID: commandSet.id,
                commandID: command.id
            ) else { return nil }
            let row = IOSBuiltInEmojiCommandRowModel(
                command: command,
                reference: reference
            )
            guard !query.isEmpty else { return row }
            let values = [command.emoji, command.displayName]
                + command.aliases
            return values.contains {
                $0.localizedStandardContains(query)
            } ? row : nil
        }
    }

    private func filteredCustomRows(
        _ commands: [CustomEmojiCommand]
    ) -> [IOSCustomEmojiCommandRowModel] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else {
            return commands.map(IOSCustomEmojiCommandRowModel.init)
        }
        return commands.filter { command in
            ([command.normalizedEmoji] + command.normalizedSpokenPhrases)
                .contains { $0.localizedStandardContains(query) }
        }.map(IOSCustomEmojiCommandRowModel.init)
    }

    private var normalizedSearchQuery: String {
        searchQuery.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentConfiguration: EmojiCommandsConfiguration? {
        stateOwner.state.durableValue?.emojiCommandsConfiguration
    }

    private func beginGlobalToggle(expected: Bool, requested: Bool) {
        guard expected != requested else { return }
        beginMutation(
            .emojiCommands(
                .setEnabled(expected: expected, requested: requested)
            ),
            successAnnouncement: requested
                ? "Voice emoji commands enabled."
                : "Voice emoji commands disabled."
        )
    }

    private func beginCommandToggle(
        _ command: CustomEmojiCommand,
        requested: Bool
    ) {
        guard command.isEnabled != requested else { return }
        beginMutation(
            .emojiCommands(
                .setCommandEnabled(
                    id: command.id,
                    expected: command.isEnabled,
                    requested: requested
                )
            ),
            successAnnouncement: "Custom command updated."
        )
    }

    private func requestDelete(_ command: CustomEmojiCommand) {
        guard !operationInFlight else { return }
        pendingDelete = IOSCustomEmojiCommandReference(expected: command)
        showsDeleteConfirmation = true
    }

    private func beginDelete(_ reference: IOSCustomEmojiCommandReference) {
        beginMutation(
            .emojiCommands(.remove(expected: reference.expected)),
            successNotice: .deleted,
            successAnnouncement: "Custom command deleted.",
            blocksDestinationSwitching: true
        )
    }

    private func beginMutation(
        _ mutation: IOSLibraryMutation,
        successNotice: IOSEmojiCommandsNotice = .saved,
        successAnnouncement: String,
        blocksDestinationSwitching: Bool = false
    ) {
        guard !operationInFlight else { return }
        operationInFlight = true
        if blocksDestinationSwitching {
            hasBlockingSceneOperation = true
        }
        Task {
            defer {
                operationInFlight = false
                if blocksDestinationSwitching {
                    hasBlockingSceneOperation = false
                }
            }
            do {
                let completion = try await stateOwner.apply(mutation)
                switch completion.receipt.disposition {
                case .committed, .unchanged:
                    notice = successNotice
                    iosAnnounceSettingsStatus(successAnnouncement)
                case .targetMissing, .conflict:
                    notice = .changedElsewhere
                    iosAnnounceSettingsStatus(
                        "Dictation rules changed elsewhere. No change was made."
                    )
                case .duplicate, .invalid:
                    notice = .invalid
                    iosAnnounceSettingsStatus(
                        "The custom command could not be changed."
                    )
                }
            } catch {
                notice = .notSaved
                iosAnnounceSettingsStatus(
                    "Dictation rules were not saved. Saved commands are "
                        + "unchanged."
                )
            }
        }
    }

    private func retryLoad() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            _ = try? await stateOwner.load()
        }
    }
}

private nonisolated struct IOSBuiltInEmojiCommandRowModel: Identifiable,
    Sendable {
    let command: EmojiCommand
    let reference: IOSBuiltInEmojiCommandReference
    var id: IOSBuiltInEmojiCommandReference { reference }
}

private nonisolated struct IOSCustomEmojiCommandRowModel: Identifiable,
    Sendable {
    let command: CustomEmojiCommand
    var id: UUID { command.id }
}

extension IOSEmojiCommandsView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSBuiltInEmojiCommandRowModel: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSCustomEmojiCommandRowModel: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Emoji commands") {
    let stateOwner = IOSLibraryStateOwner(
        load: { .defaults },
        commit: { $0 }
    )

    NavigationStack {
        IOSEmojiCommandsView()
    }
    .environment(stateOwner)
    .task {
        _ = try? await stateOwner.load()
    }
}
