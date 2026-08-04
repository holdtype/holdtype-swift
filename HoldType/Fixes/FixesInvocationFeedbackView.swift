import SwiftUI

struct FixesInvocationFeedbackView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.separator.opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fixes")
    }
}

#Preview {
    FixesInvocationFeedbackView(
        message: "Fixes is not available in this field."
    )
    .frame(width: 300)
    .padding(30)
}
