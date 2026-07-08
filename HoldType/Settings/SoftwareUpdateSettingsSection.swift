//
//  SoftwareUpdateSettingsSection.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import SwiftUI

struct SoftwareUpdateSettingsSection: View {
    @ObservedObject var softwareUpdates: SoftwareUpdateService
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(softwareUpdates: SoftwareUpdateService) {
        self.softwareUpdates = softwareUpdates
        _automaticallyChecksForUpdates = State(
            initialValue: softwareUpdates.automaticallyChecksForUpdates
        )
        _automaticallyDownloadsUpdates = State(
            initialValue: softwareUpdates.automaticallyDownloadsUpdates
        )
    }

    var body: some View {
        Section("Updates") {
            LabeledContent("Current version", value: softwareUpdates.versionAndBuildText)

            LabeledContent("Update source") {
                Text(softwareUpdates.configuration.feedDisplayText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if let projectURL {
                LabeledContent("Project") {
                    Link(destination: projectURL) {
                        Label(MenuBarPresentation.projectTitle, systemImage: "link")
                    }
                }
            }

            Toggle(
                "Automatically check for updates",
                isOn: $automaticallyChecksForUpdates
            )
            .disabled(!softwareUpdates.isConfigured)
            .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                softwareUpdates.automaticallyChecksForUpdates = newValue
            }

            Toggle(
                "Automatically download updates",
                isOn: $automaticallyDownloadsUpdates
            )
            .disabled(!softwareUpdates.isConfigured || !automaticallyChecksForUpdates)
            .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                softwareUpdates.automaticallyDownloadsUpdates = newValue
            }

            Text("Manual checks stay available from Settings and the menu bar even when automatic checks are off.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: softwareUpdates.checkForUpdates) {
                Label(MenuBarPresentation.checkForUpdatesTitle, systemImage: "arrow.down.circle")
            }
            .disabled(!softwareUpdates.canCheckForUpdates)

            if !softwareUpdates.isConfigured {
                Label(
                    "Updates are not configured for this build.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: reloadPreferences)
    }

    private func reloadPreferences() {
        automaticallyChecksForUpdates = softwareUpdates.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = softwareUpdates.automaticallyDownloadsUpdates
    }

    private var projectURL: URL? {
        URL(string: MenuBarPresentation.projectURLString)
    }
}

#Preview {
    Form {
        SoftwareUpdateSettingsSection(softwareUpdates: .shared)
    }
    .formStyle(.grouped)
    .padding()
}
