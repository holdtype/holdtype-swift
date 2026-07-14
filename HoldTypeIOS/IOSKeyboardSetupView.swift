import SwiftUI
import UIKit

struct IOSKeyboardSetupView: View {
    @Environment(IOSKeyboardDictationSessionCoordinator.self)
    private var keyboardSession
    @Binding var practiceText: String
    @FocusState private var practiceFieldIsFocused: Bool

    var body: some View {
        Form {
            statusSection
            setupSection
            practiceSection
            keyboardVoiceSection
            privacySection
        }
        .navigationTitle("Keyboard & Full Access")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.keyboard-setup")
    }

    private var statusSection: some View {
        Section("Verification") {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Not currently verified")
                    Text(
                        "Open HoldType Keyboard below after changing Settings. "
                            + "The containing app cannot read Apple’s Full "
                            + "Access switch directly."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "keyboard.badge.ellipsis")
                    .foregroundStyle(.orange)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ios.keyboard-setup.status")
        }
    }

    private var setupSection: some View {
        Section("Allow Full Access") {
            Text(
                "In iPhone Settings, open General → Keyboard → Keyboards → "
                    + "HoldType, then turn on Allow Full Access."
            )
            .fixedSize(horizontal: false, vertical: true)

            if let settingsURL = URL(
                string: UIApplication.openSettingsURLString
            ) {
                Link(destination: settingsURL) {
                    Label(
                        "Open System Settings",
                        systemImage: "arrow.up.forward.app"
                    )
                }
                .accessibilityIdentifier(
                    "ios.keyboard-setup.open-system-settings"
                )
            }
        }
    }

    private var practiceSection: some View {
        Section("Verify With HoldType Keyboard") {
            Text(
                "Tap the field, hold Globe, and choose HoldType. Ordinary "
                    + "editing remains available without Full Access; "
                    + "keyboard-controlled voice requires it."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            TextField(
                "Tap here to try HoldType Keyboard",
                text: $practiceText,
                axis: .vertical
            )
            .lineLimit(4...8)
            .textInputAutocapitalization(.sentences)
            .focused($practiceFieldIsFocused)
            .accessibilityIdentifier("ios.keyboard-setup.practice-field")

            Button("Focus Practice Field") {
                practiceFieldIsFocused = true
            }
            .accessibilityIdentifier("ios.keyboard-setup.focus-practice")
        }
    }

    @ViewBuilder
    private var keyboardVoiceSection: some View {
        Section("Keyboard Voice") {
            LabeledContent(
                "Session",
                value: keyboardSession.presentation.title
            )

            switch keyboardSession.presentation {
            case .stopped, .failed:
                Button("Start Keyboard Session") {
                    Task { await keyboardSession.startSession() }
                }
                .accessibilityIdentifier("ios.keyboard-setup.start-session")
            case .preparing:
                ProgressView("Preparing session…")
            case .ready, .listening, .processing, .resultReady:
                Button("Stop Keyboard Session", role: .destructive) {
                    keyboardSession.stopSession()
                }
                .accessibilityIdentifier("ios.keyboard-setup.stop-session")
            }
        }
    }

    private var privacySection: some View {
        Section("Why Full Access") {
            Text(
                "Full Access lets the keyboard exchange one bounded voice "
                    + "command and an expiring Latest result with HoldType. "
                    + "The extension never receives your API key, recording, "
                    + "prompts, or History."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
