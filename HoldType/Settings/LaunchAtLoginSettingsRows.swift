//
//  LaunchAtLoginSettingsRows.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import SwiftUI

struct LaunchAtLoginSettingsRows: View {
    let status: LaunchAtLoginStatus
    let onSetEnabled: (Bool) -> Void
    let onOpenLoginItemsSettings: () -> Void

    var body: some View {
        Toggle(
            "Start HoldType at login",
            isOn: Binding(
                get: {
                    status.toggleValue
                },
                set: onSetEnabled
            )
        )

        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(status.behaviorStatusText)

                Text(status.behaviorDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: status.behaviorSystemImage)
                .foregroundStyle(status == .enabled ? Color.green : Color.secondary)
        }

        if let actionTitle = status.loginItemsActionTitle {
            Button(actionTitle, action: onOpenLoginItemsSettings)
        }
    }
}
