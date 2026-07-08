//
//  PermissionsSettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct PermissionsSettingsSection: View {
    let microphonePermissionStatus: MicrophonePermissionStatus
    let accessibilityPermissionStatus: AccessibilityPermissionStatus
    let inputMonitoringPermissionStatus: InputMonitoringPermissionStatus
    var showsRemoteProcessingDisclosure = true
    var showsInputMonitoringStatus = true
    var showsCompletedRequiredPermissions = true
    var showsInputMonitoringManualFallbackWarning = false
    let launchAtLoginStatus: LaunchAtLoginStatus
    let onSetLaunchAtLogin: (Bool) -> Void
    let onOpenLoginItemsSettings: () -> Void
    let onMicrophonePermissionAction: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onInputMonitoringPermissionAction: () -> Void

    var body: some View {
        Section("System Permissions") {
            if visibility.showsCompletedState {
                Label("Required permissions are complete.", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            if visibility.showsMicrophoneStatus {
                PermissionStatusRow(
                    title: microphonePermissionStatus.settingsStatusText,
                    description: microphonePermissionStatus.settingsDescription,
                    systemImage: microphonePermissionStatus.settingsSystemImage
                )

                if let microphoneActionTitle = microphonePermissionStatus.settingsActionTitle {
                    Button(microphoneActionTitle, action: onMicrophonePermissionAction)
                }
            }

            if visibility.showsAccessibilityStatus {
                PermissionStatusRow(
                    title: accessibilityPermissionStatus.settingsStatusText,
                    description: accessibilityPermissionStatus.settingsDescription,
                    systemImage: accessibilityPermissionStatus.settingsSystemImage
                )

                if let accessibilityActionTitle = accessibilityPermissionStatus.settingsActionTitle {
                    Button(accessibilityActionTitle, action: onOpenAccessibilitySettings)

                    if let instruction = accessibilityPermissionStatus.settingsInstruction {
                        Text(instruction)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if showsInputMonitoringStatus {
                PermissionStatusRow(
                    title: inputMonitoringPermissionStatus.settingsStatusText,
                    description: inputMonitoringPermissionStatus.settingsDescription,
                    systemImage: inputMonitoringPermissionStatus.settingsSystemImage
                )

                if let inputMonitoringActionTitle = inputMonitoringPermissionStatus.settingsActionTitle {
                    Button(inputMonitoringActionTitle, action: onInputMonitoringPermissionAction)

                    if showsInputMonitoringManualFallbackWarning,
                       let warning = inputMonitoringPermissionStatus.settingsManualFallbackWarning {
                        ManualFallbackWarningText(warning)
                    } else if let instruction = inputMonitoringPermissionStatus.settingsInstruction {
                        Text(instruction)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if showsRemoteProcessingDisclosure {
                Label(
                    "Audio is sent to OpenAI for transcription. Enabled correction or translation sends transcript text in a separate OpenAI request. HoldType does not retain raw audio by default.",
                    systemImage: "lock.shield"
                )
                .foregroundStyle(.secondary)
            }
        }

        Section("Availability") {
            LaunchAtLoginSettingsRows(
                status: launchAtLoginStatus,
                onSetEnabled: onSetLaunchAtLogin,
                onOpenLoginItemsSettings: onOpenLoginItemsSettings
            )
        }
    }

    private var visibility: PermissionsSettingsSectionVisibility {
        PermissionsSettingsSectionVisibility(
            microphonePermissionStatus: microphonePermissionStatus,
            accessibilityPermissionStatus: accessibilityPermissionStatus,
            showsCompletedRequiredPermissions: showsCompletedRequiredPermissions,
            showsInputMonitoringStatus: showsInputMonitoringStatus,
            showsRemoteProcessingDisclosure: showsRemoteProcessingDisclosure
        )
    }
}

struct PermissionsSettingsSectionVisibility: Equatable {
    let showsMicrophoneStatus: Bool
    let showsAccessibilityStatus: Bool
    let showsCompletedState: Bool

    init(
        microphonePermissionStatus: MicrophonePermissionStatus,
        accessibilityPermissionStatus: AccessibilityPermissionStatus,
        showsCompletedRequiredPermissions: Bool,
        showsInputMonitoringStatus: Bool,
        showsRemoteProcessingDisclosure: Bool
    ) {
        showsMicrophoneStatus = showsCompletedRequiredPermissions
            || microphonePermissionStatus != .allowed
        showsAccessibilityStatus = showsCompletedRequiredPermissions
            || accessibilityPermissionStatus != .trusted
        showsCompletedState = !showsCompletedRequiredPermissions
            && !showsMicrophoneStatus
            && !showsAccessibilityStatus
            && !showsInputMonitoringStatus
            && !showsRemoteProcessingDisclosure
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)

            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ManualFallbackWarningText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
                .fontWeight(.semibold)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(.red)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    Form {
        PermissionsSettingsSection(
            microphonePermissionStatus: .notDetermined,
            accessibilityPermissionStatus: .notTrusted,
            inputMonitoringPermissionStatus: .notDetermined,
            showsInputMonitoringManualFallbackWarning: true,
            launchAtLoginStatus: .disabled,
            onSetLaunchAtLogin: { _ in },
            onOpenLoginItemsSettings: {},
            onMicrophonePermissionAction: {},
            onOpenAccessibilitySettings: {},
            onInputMonitoringPermissionAction: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}
