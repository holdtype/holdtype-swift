import SwiftUI
import UIKit

struct IOSVoiceDraftPendingResultStatus: View {
    let presentation: IOSVoiceDraftPendingResultPresentation
    let hasConfirmedText: Bool

    var body: some View {
        if keepsConfirmedTextVisible {
            VStack {
                Spacer(minLength: 12)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: presentation.systemImage)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.title)
                            .font(.subheadline.weight(.semibold))
                        Text(presentation.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground)
                        .opacity(0.96),
                    in: RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.title)
            .accessibilityValue(presentation.detail)
            .accessibilityIdentifier("ios.voice.draft.pending-result")
        } else {
            VStack(spacing: 8) {
                Label(
                    presentation.title,
                    systemImage: presentation.systemImage
                )
                .font(.headline)
                Text(presentation.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.title)
            .accessibilityValue(presentation.detail)
            .accessibilityIdentifier("ios.voice.draft.pending-result")
        }
    }

    private var keepsConfirmedTextVisible: Bool {
        !presentation.hidesConfirmedText && hasConfirmedText
    }
}

#Preview("Append below Draft") {
    IOSVoiceDraftPendingResultStatus(
        presentation: IOSVoiceDraftPendingResultPresentation(
            title: "Listening",
            detail: "New text will be added below when you finish.",
            systemImage: "waveform",
            hidesConfirmedText: false
        ),
        hasConfirmedText: true
    )
    .frame(width: 390, height: 220)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Replace Draft") {
    IOSVoiceDraftPendingResultStatus(
        presentation: IOSVoiceDraftPendingResultPresentation(
            title: "Processing",
            detail: "Your result will appear here.",
            systemImage: "ellipsis.circle",
            hidesConfirmedText: true
        ),
        hasConfirmedText: true
    )
    .frame(width: 390, height: 220)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
