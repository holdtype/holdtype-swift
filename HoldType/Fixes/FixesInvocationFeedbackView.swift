import SwiftUI

struct FixesInvocationFeedbackPresentation: Equatable {
    let title: String
    let message: String

    init(message: String) {
        title = "Fixes Unavailable"
        self.message = message
    }
}

struct FixesInvocationFeedbackView: View {
    static let contentWidth: CGFloat = 380

    let presentation: FixesInvocationFeedbackPresentation
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title)
                        .font(.system(size: 15, weight: .semibold))

                    Text(presentation.message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()

                Button("OK", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: Self.contentWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.message)
    }
}

#Preview {
    FixesInvocationFeedbackView(
        presentation: FixesInvocationFeedbackPresentation(
            message: "This text field does not support Fixes. Try another field."
        ),
        onDismiss: {}
    )
    .padding(30)
}
