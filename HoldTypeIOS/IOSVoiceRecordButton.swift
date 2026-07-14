import SwiftUI

struct IOSVoiceRecordButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let showsProgress: Bool
    let isListening: Bool
    let inputLevel: () -> Double?
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 0.2 : 0.05,
                paused: !isListening
            )
        ) { _ in
            HStack(spacing: 10) {
                levelBars
                recordButton
                levelBars
                    .scaleEffect(x: -1, y: 1)
            }
        }
    }

    private var recordButton: some View {
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

    private var levelBars: some View {
        let level = min(1, max(0, inputLevel() ?? 0))

        return HStack(alignment: .center, spacing: 3) {
            ForEach(Array(Self.levelMultipliers.enumerated()), id: \.offset) {
                _, multiplier in
                Capsule()
                    .fill(Color.accentColor.opacity(isListening ? 0.84 : 0))
                    .frame(
                        width: 4,
                        height: 8 + (44 * level * multiplier)
                    )
            }
        }
        .frame(width: 34, height: 58)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.1),
            value: level
        )
        .accessibilityHidden(true)
    }

    private static let levelMultipliers: [Double] = [0.42, 0.68, 1, 0.72, 0.48]
}
