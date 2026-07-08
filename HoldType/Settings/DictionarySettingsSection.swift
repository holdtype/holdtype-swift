//
//  DictionarySettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct DictionarySettingsSection: View {
    @Binding var settings: AppSettings
    @State private var newDictionaryEntry = ""
    @FocusState private var isNewDictionaryEntryFocused: Bool

    var body: some View {
        Section("Custom words") {
            customWordsEditor
        }

        EmojiCommandsSettingsSection(settings: $settings)
    }

    @ViewBuilder
    private var customWordsEditor: some View {
        HStack {
            TextField("Add word or phrase", text: $newDictionaryEntry)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isNewDictionaryEntryFocused)
                .onSubmit(addDictionaryEntries)

            Button(action: addDictionaryEntries) {
                Label("Add", systemImage: "plus")
            }
            .disabled(!canAddDictionaryEntry)
        }

        if dictionaryEntries.isEmpty {
            Label("No custom words yet", systemImage: "book.closed")
                .foregroundStyle(.secondary)
        } else {
            ForEach(dictionaryEntries, id: \.self) { entry in
                HStack {
                    Text(entry)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Button {
                        removeDictionaryEntry(entry)
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Remove \(entry)")
                }
            }
        }
    }

    private var dictionaryEntries: [String] {
        settings.resolvedCustomDictionaryEntries
    }

    private var canAddDictionaryEntry: Bool {
        !AppSettings.parseCustomDictionaryEntries(from: newDictionaryEntry).isEmpty
    }

    private func addDictionaryEntries() {
        let currentEntries = settings.resolvedCustomDictionaryEntries
        let updatedEntries = AppSettings.appendingCustomDictionaryEntries(
            from: newDictionaryEntry,
            to: currentEntries
        )

        guard updatedEntries != currentEntries else {
            return
        }

        settings.customDictionary = updatedEntries
        newDictionaryEntry = ""
        isNewDictionaryEntryFocused = true
    }

    private func removeDictionaryEntry(_ entry: String) {
        settings.customDictionary = settings.resolvedCustomDictionaryEntries.filter { $0 != entry }
    }

}

#Preview {
    Form {
        DictionarySettingsSection(
            settings: .constant(
                AppSettings(
                    transcriptionModel: "",
                    language: .custom,
                    customLanguageCode: "ru",
                    prompt: "Prefer product vocabulary.",
                    customDictionary: ["OpenWhispr", "Synty", "The word is HoldType"],
                    automaticallyInsertTranscripts: true,
                    saveTranscriptsToAppClipboard: true,
                    soundEnabled: true,
                    showFloatingIndicator: true,
                    saveTranscriptHistory: false
                )
            )
        )
    }
    .formStyle(.grouped)
    .padding()
}
