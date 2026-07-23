import HoldTypeDomain
import SwiftUI

struct IOSVoiceFixesSurface: View {
    let catalogState: IOSVoiceFixesCatalogState
    let activeAction: TextFixAction?
    let outcome: IOSVoiceDraftTextActionOutcome?
    let onSelect: (TextFixAction) -> Void
    let onRetryCatalog: () -> Void
    let onCancelAction: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch catalogState {
                case .notLoaded, .loading:
                    ProgressView("Loading Fixes…")
                        .tint(.purple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable:
                    ContentUnavailableView {
                        Label(
                            "Fixes Unavailable",
                            systemImage: "wand.and.stars"
                        )
                    } description: {
                        Text(
                            "HoldType couldn't safely load the local Fixes catalog."
                        )
                    } actions: {
                        Button("Try Again", action: onRetryCatalog)
                    }
                case .ready(let actions):
                    actionList(actions)
                }
            }
            .navigationTitle("Fixes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if activeAction != nil {
                        Button("Cancel", action: onCancelAction)
                            .accessibilityIdentifier(
                                "ios.voice.fixes.cancel"
                            )
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .disabled(activeAction != nil)
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 360, minHeight: 300)
        .accessibilityIdentifier("ios.voice.fixes.surface")
    }

    private func actionList(
        _ actions: [TextFixAction]
    ) -> some View {
        VStack(spacing: 0) {
            if let failureDetail = outcome?.failureDetail {
                Label(failureDetail, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .accessibilityIdentifier("ios.voice.fixes.failure")
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(actions) { action in
                        actionButton(action)
                    }
                }
                .padding(12)
            }
        }
    }

    private func actionButton(
        _ action: TextFixAction
    ) -> some View {
        let presentation = IOSVoiceTextFixPresentation.resolve(action)
        let isActive = activeAction?.id == action.id

        return Button {
            onSelect(action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: presentation.systemImage)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 28)

                Text(presentation.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                if isActive {
                    ProgressView()
                        .tint(.purple)
                        .accessibilityLabel("Applying \(action.title)")
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(activeAction != nil)
        .accessibilityHint("Applies this Fix to the reserved Draft text.")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
    }
}

#Preview("Voice Fixes") {
    IOSVoiceFixesSurface(
        catalogState: .ready(TextFixCatalog.defaults.enabledActions),
        activeAction: nil,
        outcome: nil,
        onSelect: { _ in },
        onRetryCatalog: {},
        onCancelAction: {},
        onDone: {}
    )
}
