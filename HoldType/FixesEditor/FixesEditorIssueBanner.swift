import SwiftUI

struct FixesEditorIssueBanner: View {
    let issue: FixesEditorIssue
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImageName)
                .foregroundStyle(accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.callout)
                    .fontWeight(.semibold)

                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if issue.allowsRetry {
                Button("Try Again", action: onRetry)
            } else {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .contain)
    }

    private var accentColor: Color {
        switch issue.kind {
        case .load:
            return .orange
        case .save, .validation:
            return .red
        }
    }

    private var systemImageName: String {
        switch issue.kind {
        case .load:
            return "exclamationmark.triangle"
        case .save:
            return "externaldrive.badge.exclamationmark"
        case .validation:
            return "exclamationmark.circle"
        }
    }
}

#Preview("Load Error") {
    FixesEditorIssueBanner(
        issue: .loadingFallbackForPreview,
        onRetry: {},
        onDismiss: {}
    )
    .frame(width: 620)
}

private extension FixesEditorIssue {
    static let loadingFallbackForPreview = FixesEditorIssue(
        kind: .load,
        title: "Fixes Catalog Is Damaged",
        message:
            "HoldType preserved the damaged catalog and will not replace it with defaults."
    )
}
