import HoldTypeDomain
import SwiftUI

struct FixesPaletteView: View {
    @ObservedObject var model: FixesPaletteModel

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if !model.visibleActions.isEmpty || !model.searchText.isEmpty {
                Divider()
            }

            actionList

            if let status = model.statusPresentation {
                Divider()

                FixesPaletteStatusBanner(presentation: status)
            }
        }
        .padding(5)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .onAppear {
            isSearchFocused = true
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("HoldType Fixes")
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "Search Fixes",
                text: Binding(
                    get: { model.searchText },
                    set: model.setSearchText
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($isSearchFocused)

            if !model.searchText.isEmpty {
                Button {
                    model.setSearchText("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var actionList: some View {
        if model.visibleActions.isEmpty {
            if !model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No matching Fixes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
            }
        } else {
            VStack(spacing: 1) {
                ForEach(model.visibleActions) { action in
                    FixesPaletteActionRow(
                        action: action,
                        isSelected: action.id == model.selectedActionID,
                        isProcessing: isProcessing(action.id),
                        isEnabled: model.status.allowsActionActivation
                    ) {
                        model.selectAction(id: action.id)
                        model.activateSelection()
                    }
                    .id(action.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func isProcessing(_ actionID: String) -> Bool {
        if case .processing(let processingActionID) = model.status {
            return processingActionID == actionID
        }

        return false
    }
}

private struct FixesPaletteActionRow: View {
    let action: FixesPaletteActionPresentation
    let isSelected: Bool
    let isProcessing: Bool
    let isEnabled: Bool
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 8) {
                Image(systemName: action.systemImageName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 16)

                Text(action.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled || isProcessing ? 1 : 0.52)
        .accessibilityLabel(action.title)
        .accessibilityHint(isEnabled ? "Applies this Fix" : "Unavailable")
    }
}

private struct FixesPaletteStatusBanner: View {
    let presentation: FixesPaletteStatusPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if presentation.showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 1)
            } else if let systemImageName = presentation.systemImageName {
                Image(systemName: systemImageName)
                    .foregroundStyle(accentColor)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.caption)
                    .fontWeight(.medium)

                if let message = presentation.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var accentColor: Color {
        switch presentation.tone {
        case .neutral:
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct FixesPalettePreviewContainer: View {
    @StateObject private var model: FixesPaletteModel

    @MainActor
    init(status: FixesPaletteStatus) {
        _model = StateObject(
            wrappedValue: FixesPaletteModel(
                catalog: .defaults,
                recentActionIDs: ["default.make-shorter", "default.improve-writing"],
                status: status,
                onActivate: { _ in },
                onDismiss: {}
            )
        )
    }

    var body: some View {
        FixesPaletteView(model: model)
            .frame(width: 360)
            .padding(30)
    }
}

#Preview("Ready") {
    FixesPalettePreviewContainer(status: .ready)
}

#Preview("Failure") {
    FixesPalettePreviewContainer(
        status: .failure(
            message: "The request could not be completed. Choose a Fix to retry.",
            allowsRetry: true
        )
    )
}

#Preview("Stale Target") {
    FixesPalettePreviewContainer(
        status: .staleTarget(
            message: "The original text changed, so HoldType left it unchanged."
        )
    )
}
