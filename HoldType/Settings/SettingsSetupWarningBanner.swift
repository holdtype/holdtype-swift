//
//  SettingsSetupWarningBanner.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct SettingsSetupWarning: Equatable {
    let title: String
    let message: String
    let detailLines: [String]

    static func permissions(from setupStatus: AppSetupStatus) -> SettingsSetupWarning? {
        let permissionItems = setupStatus.startupAttentionItems.filter {
            $0.settingsItem == .permissions
        }

        guard !permissionItems.isEmpty else {
            return nil
        }

        return SettingsSetupWarning(
            title: "Required setup is incomplete",
            message: "Complete these settings before HoldType can start dictation reliably.",
            detailLines: permissionItems.map(\.title)
        )
    }

    static func openAI(apiKeyAvailability: APIKeyAvailability) -> SettingsSetupWarning? {
        switch apiKeyAvailability {
        case .unknown, .saved:
            return nil
        case .missing:
            return SettingsSetupWarning(
                title: "OpenAI API key required",
                message: "Save an OpenAI API key before HoldType can transcribe recordings.",
                detailLines: []
            )
        case .unavailable(let message):
            return SettingsSetupWarning(
                title: "OpenAI API key unavailable",
                message: message,
                detailLines: []
            )
        }
    }
}

struct SettingsSetupWarningBanner: View {
    let warning: SettingsSetupWarning

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(warning.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text(warning.message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if !warning.detailLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(warning.detailLines, id: \.self) { detailLine in
                        Label(detailLine, systemImage: "smallcircle.filled.circle")
                            .font(.footnote)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35))
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsSetupWarningBanner(
        warning: SettingsSetupWarning(
            title: "Required setup is incomplete",
            message: "Complete these settings before HoldType can start dictation reliably.",
            detailLines: ["Microphone", "Accessibility"]
        )
    )
    .padding()
    .frame(width: 480)
}
