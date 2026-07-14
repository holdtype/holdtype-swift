import HoldTypeDomain
import SwiftUI

enum IOSVoiceActivityPhase: Equatable {
    case idle
    case listening
    case recognizing

    static func resolve(_ workPhase: VoiceWorkPhase) -> Self {
        switch workPhase {
        case .inactive, .arming, .ready:
            .idle
        case .listening:
            .listening
        case .finalizing, .processing:
            .recognizing
        }
    }
}

struct IOSVoiceRecordButton: View {
    let accessibilityLabel: String
    let isEnabled: Bool
    let workPhase: VoiceWorkPhase
    let action: () -> Void

    var body: some View {
        let activityPhase = IOSVoiceActivityPhase.resolve(workPhase)

        Button(action: action) {
            IOSVoiceActivityIndicator(phase: activityPhase)
                .id(activityPhase)
                .saturation(isEnabled || activityPhase != .idle ? 1 : 0)
                .opacity(isEnabled || activityPhase != .idle ? 1 : 0.44)
                .frame(width: 208, height: 208)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(activityPhase.accessibilityValue)
        .accessibilityHint(
            accessibilityHint(for: activityPhase)
        )
    }

    private func accessibilityHint(
        for activityPhase: IOSVoiceActivityPhase
    ) -> String {
        if isEnabled {
            return "Controls the current HoldType dictation."
        }
        if activityPhase == .recognizing {
            return "HoldType is recognizing the current dictation."
        }
        return "Review the status above to make dictation available."
    }
}

private struct IOSVoiceActivityIndicator: View {
    let phase: IOSVoiceActivityPhase

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var isPulsing = false
    @State private var isRotating = false

    var body: some View {
        indicator
            .frame(width: Self.visualSize, height: Self.visualSize)
            .onAppear {
                guard !reduceMotion, phase != .idle else { return }

                withAnimation(
                    .easeInOut(duration: phase.pulseDuration)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsing.toggle()
                }
                withAnimation(
                    .linear(duration: phase.rotationDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    isRotating.toggle()
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var indicator: some View {
        if reduceMotion || phase == .idle {
            fullArtwork
        } else {
            ZStack {
                animatedOrbit

                Image(phase.coreAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(isPulsing ? phase.corePulseScale : 1)
            }
            .scaleEffect(isPulsing ? phase.containerPulseScale : 1)
        }
    }

    private var fullArtwork: some View {
        Image(phase.fullAssetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    @ViewBuilder
    private var animatedOrbit: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .listening:
            listeningOrbit
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        case .recognizing:
            recognizingOrbit
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
    }

    private var listeningOrbit: some View {
        ZStack {
            Circle()
                .stroke(
                    phase.accent.opacity(0.82),
                    lineWidth: Self.scaled(1.35)
                )
                .frame(
                    width: Self.scaled(66),
                    height: Self.scaled(66)
                )

            Circle()
                .stroke(
                    phase.accent.opacity(0.58),
                    lineWidth: Self.scaled(1.15)
                )
                .frame(
                    width: Self.scaled(58),
                    height: Self.scaled(58)
                )

            Circle()
                .fill(phase.accent)
                .frame(
                    width: Self.scaled(7),
                    height: Self.scaled(7)
                )
                .shadow(
                    color: phase.accent.opacity(0.8),
                    radius: Self.scaled(4)
                )
                .offset(y: -Self.scaled(33))
        }
    }

    private var recognizingOrbit: some View {
        ZStack {
            Circle()
                .stroke(
                    phase.accent.opacity(0.68),
                    lineWidth: Self.scaled(1.15)
                )
                .frame(
                    width: Self.scaled(62),
                    height: Self.scaled(62)
                )

            ForEach(0..<24, id: \.self) { index in
                Circle()
                    .fill(
                        phase.accent.opacity(
                            index.isMultiple(of: 3) ? 0.9 : 0.48
                        )
                    )
                    .frame(
                        width: Self.scaled(
                            index.isMultiple(of: 4) ? 4.8 : 3.2
                        ),
                        height: Self.scaled(
                            index.isMultiple(of: 4) ? 4.8 : 3.2
                        )
                    )
                    .offset(y: -Self.scaled(33))
                    .rotationEffect(.degrees(Double(index) * 15))
            }
        }
    }

    private static let visualSize: CGFloat = 196
    private static let macOSIndicatorSize: CGFloat = 72

    private static func scaled(_ value: CGFloat) -> CGFloat {
        value * visualSize / macOSIndicatorSize
    }
}

private extension IOSVoiceActivityPhase {
    var fullAssetName: String {
        switch self {
        case .idle:
            "ActivityIdleIndicatorLight"
        case .listening:
            "ActivityRecordingIndicatorLight"
        case .recognizing:
            "ActivityTranscribingIndicatorLight"
        }
    }

    var coreAssetName: String {
        switch self {
        case .idle:
            "ActivityIdleIndicatorLight"
        case .listening:
            "ActivityRecordingCoreLight"
        case .recognizing:
            "ActivityTranscribingCoreLight"
        }
    }

    var accessibilityValue: String {
        switch self {
        case .idle:
            "Ready"
        case .listening:
            "Listening"
        case .recognizing:
            "Recognizing"
        }
    }

    var accent: Color {
        switch self {
        case .idle:
            .secondary
        case .listening:
            Color(red: 0.031, green: 0.545, blue: 0.941)
        case .recognizing:
            Color(red: 0.388, green: 0.078, blue: 0.894)
        }
    }

    var pulseDuration: Double {
        switch self {
        case .idle:
            0
        case .listening:
            0.78
        case .recognizing:
            1.05
        }
    }

    var rotationDuration: Double {
        switch self {
        case .idle:
            0
        case .listening:
            1.8
        case .recognizing:
            2.4
        }
    }

    var corePulseScale: CGFloat {
        switch self {
        case .idle:
            1
        case .listening:
            1.035
        case .recognizing:
            1.02
        }
    }

    var containerPulseScale: CGFloat {
        switch self {
        case .idle:
            1
        case .listening:
            1.025
        case .recognizing:
            1.015
        }
    }
}
