import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSEmojiSetSelectionView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner

    @State private var operationInFlight = false
    @State private var notice: IOSEmojiCommandsNotice?

    var body: some View {
        Group {
            if let configuration = stateOwner.state.durableValue?
                .emojiCommandsConfiguration {
                selectionList(configuration)
            } else {
                ContentUnavailableView {
                    Label(
                        "Active Set Unavailable",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text("HoldType couldn’t read the saved dictation rules.")
                }
            }
        }
        .navigationTitle("Active Set")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if notice == .notSaved {
                IOSLibraryPersistentFailureStatus()
            }
        }
        .accessibilityIdentifier(
            "ios.library.emoji-commands.active-set.screen"
        )
    }

    private func selectionList(
        _ configuration: EmojiCommandsConfiguration
    ) -> some View {
        let current = IOSBuiltInEmojiSetSelection(
            storedIdentifiers: configuration.enabledBuiltInSetIDs
        ) ?? .custom

        return List {
            if case .saveFailed = stateOwner.state, notice != .notSaved {
                IOSSaveFailureSection(subject: "Dictation Rules")
            }
            if let notice {
                IOSEmojiCommandsNoticeSection(notice: notice)
            }

            Section("Built-in Languages") {
                ForEach(
                    IOSBuiltInEmojiSetSelection.iosOptions,
                    id: \.self
                ) { option in
                    Button {
                        beginSelection(
                            expected: current,
                            requested: option
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.iosDisplayName)
                                    .foregroundStyle(.primary)
                                Text(optionDetail(option))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if option == current {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .disabled(operationInFlight || option == current)
                    .accessibilityAddTraits(
                        option == current ? .isSelected : []
                    )
                    .accessibilityIdentifier(
                        "ios.library.emoji-commands.active-set."
                            + optionAccessibilityID(option)
                    )
                }
            }

            Section {
                Text(
                    "Custom commands stay available with every language. "
                        + "Choosing Custom turns off only built-in hints and "
                        + "replacement commands."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .disabled(operationInFlight)
    }

    private func optionDetail(
        _ option: IOSBuiltInEmojiSetSelection
    ) -> String {
        if let count = option.commandSet?.commands.count {
            return count == 1
                ? "1 built-in command"
                : "\(count) built-in commands"
        }
        return "No built-in commands"
    }

    private func optionAccessibilityID(
        _ option: IOSBuiltInEmojiSetSelection
    ) -> String {
        switch option {
        case .custom: "custom"
        case .builtIn(let identifier): identifier
        }
    }

    private func beginSelection(
        expected: IOSBuiltInEmojiSetSelection,
        requested: IOSBuiltInEmojiSetSelection
    ) {
        guard expected != requested, !operationInFlight else { return }
        operationInFlight = true
        Task {
            defer { operationInFlight = false }
            do {
                let completion = try await stateOwner.apply(
                    .emojiCommands(
                        .selectBuiltInSet(
                            expected: expected,
                            requested: requested
                        )
                    )
                )
                switch completion.receipt.disposition {
                case .committed, .unchanged:
                    notice = .saved
                    iosAnnounceSettingsStatus("Active command set updated.")
                case .targetMissing, .conflict:
                    notice = .changedElsewhere
                    iosAnnounceSettingsStatus(
                        "Dictation rules changed elsewhere."
                    )
                case .duplicate, .invalid:
                    notice = .invalid
                }
            } catch {
                notice = .notSaved
                iosAnnounceSettingsStatus("Active set was not saved.")
            }
        }
    }
}

extension IOSEmojiSetSelectionView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Emoji command active set") {
    let stateOwner = IOSLibraryStateOwner(
        load: { .defaults },
        commit: { $0 }
    )

    NavigationStack {
        IOSEmojiSetSelectionView()
    }
    .environment(stateOwner)
    .task {
        _ = try? await stateOwner.load()
    }
}
