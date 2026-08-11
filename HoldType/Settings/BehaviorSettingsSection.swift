//
//  BehaviorSettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import HoldTypeDomain
import SwiftUI

struct BehaviorSettingsSection: View {
    @Binding var settings: AppSettings
    var availableAudioInputDevices: [AudioInputDevice] = []
    let launchAtLoginStatus: LaunchAtLoginStatus
    let transcriptHistoryCount: Int
    let transcriptHistoryError: String?
    let onSetLaunchAtLogin: (Bool) -> Void
    let onOpenLoginItemsSettings: () -> Void
    let onClearTranscriptHistory: () -> Void

    var body: some View {
        Section("Audio Input") {
            Picker("Microphone", selection: audioInputSelection) {
                Text("System Default")
                    .tag(AudioInputPickerSelection.systemDefault)

                ForEach(availableAudioInputDevices) { device in
                    Text(device.name)
                        .tag(AudioInputPickerSelection.device(device.id))
                }

                if let unavailablePreference {
                    Text("\(unavailablePreference.displayName) (Disconnected)")
                        .tag(AudioInputPickerSelection.device(unavailablePreference.deviceID ?? ""))
                }
            }
            .pickerStyle(.menu)

            Text(
                settings.audioInputPreference.isSystemDefault
                    ? "Follows the audio input selected by macOS."
                    : "HoldType will use only this microphone and will not switch silently."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let unavailablePreference {
                Label(
                    "\(unavailablePreference.displayName) is disconnected. Recording is blocked until it reconnects or you choose another microphone.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.red)

                Button("Use System Default") {
                    settings.audioInputPreference = .systemDefault
                }
            }
        }

        Section("Behavior") {
            LaunchAtLoginSettingsRows(
                status: launchAtLoginStatus,
                onSetEnabled: onSetLaunchAtLogin,
                onOpenLoginItemsSettings: onOpenLoginItemsSettings
            )

            Toggle(
                "Show HoldType in Dock",
                isOn: $settings.showInDock
            )

            Text("Turn on to keep HoldType visible in the Dock while it is running.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle(
                "Insert transcripts automatically",
                isOn: $settings.automaticallyInsertTranscripts
            )

            Text("After transcription, insert accepted text into the active app at the cursor.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle(
                "Keep last result for quick paste",
                isOn: $settings.saveTranscriptsToAppClipboard
            )

            Text("Use Control+Command+V or Paste Last Result to insert the saved text in the active app.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle(
                "Play recording start and stop sounds",
                isOn: $settings.soundEnabled
            )

            Toggle(
                "Show floating recording indicator",
                isOn: $settings.showFloatingIndicator
            )

            Picker(
                "Maximum recording length",
                selection: $settings.recordingDurationLimit
            ) {
                ForEach(RecordingDurationLimit.allValues, id: \.self) { limit in
                    Text(limit.displayName).tag(limit)
                }
            }
            .pickerStyle(.menu)

            Text(
                "HoldType stops automatically at this limit. Longer recordings "
                    + "can cost more to transcribe and use more local storage. "
                    + "Changes apply to the next recording."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Picker(
                "Recording tail after release",
                selection: $settings.recordingStopTailDuration
            ) {
                ForEach(RecordingStopTailDuration.allCases, id: \.self) { duration in
                    Text(duration.displayName).tag(duration)
                }
            }
            .pickerStyle(.menu)

            Text("Keeps recording briefly after stop so final words are less likely to be cut off.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle(
                "Keep transcript recovery history",
                isOn: $settings.saveTranscriptHistory
            )

            Text("Keeps the 20 most recent accepted transcripts on this Mac until you clear or delete them. Saved recordings remain until transcription succeeds or you delete them in History.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let transcriptHistoryError {
                Text(transcriptHistoryError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("Clear Accepted Transcript History", role: .destructive, action: onClearTranscriptHistory)
                .disabled(transcriptHistoryCount == 0)
        }
    }

    private var audioInputSelection: Binding<AudioInputPickerSelection> {
        Binding(
            get: {
                settings.audioInputPreference.deviceID.map(AudioInputPickerSelection.device)
                    ?? .systemDefault
            },
            set: { selection in
                switch selection {
                case .systemDefault:
                    settings.audioInputPreference = .systemDefault
                case .device(let deviceID):
                    guard let device = availableAudioInputDevices.first(where: { $0.id == deviceID }) else {
                        return
                    }
                    settings.audioInputPreference = AudioInputPreference(
                        deviceID: device.id,
                        deviceName: device.name
                    )
                }
            }
        )
    }

    private var unavailablePreference: AudioInputPreference? {
        let preference = settings.audioInputPreference
        guard let deviceID = preference.deviceID,
              !availableAudioInputDevices.contains(where: { $0.id == deviceID }) else {
            return nil
        }
        return preference
    }
}

private enum AudioInputPickerSelection: Hashable {
    case systemDefault
    case device(String)
}

#Preview {
    Form {
        BehaviorSettingsSection(
            settings: .constant(.defaults),
            launchAtLoginStatus: .disabled,
            transcriptHistoryCount: 0,
            transcriptHistoryError: nil,
            onSetLaunchAtLogin: { _ in },
            onOpenLoginItemsSettings: {},
            onClearTranscriptHistory: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}
