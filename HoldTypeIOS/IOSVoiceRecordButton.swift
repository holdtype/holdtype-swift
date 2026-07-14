import SwiftUI

struct IOSVoiceRecordButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let showsProgress: Bool
    let isListening: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("VoiceRecordButtonBackground")
                    .resizable()
                    .scaledToFit()
                    .saturation(isEnabled ? 1 : 0)
                    .opacity(isEnabled ? 1 : 0.44)

                VStack(spacing: 5) {
                    if showsProgress {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.large)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 48, weight: .medium))
                    }
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 46)
            }
            .frame(width: 208, height: 208)
            .overlay {
                if isListening {
                    Circle()
                        .stroke(
                            Color.accentColor.opacity(
                                reduceTransparency ? 0.9 : 0.52
                            ),
                            lineWidth: reduceTransparency ? 4 : 3
                        )
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(
            isEnabled
                ? "Controls the current HoldType dictation."
                : "Review the status above to make dictation available."
        )
    }
}
