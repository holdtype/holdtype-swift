//
//  FloatingIndicatorView.swift
//  HoldType
//
//  Created by Codex on 6/21/26.
//

import SwiftUI
import HoldTypeDomain

struct FloatingIndicatorView: View {
    let presentation: FloatingIndicatorPresentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false
    @State private var isRotating = false

    var body: some View {
        ZStack {
            indicator

            if let countdown = presentation.countdown {
                countdownBadge(countdown)
            }
        }
            .frame(width: 72, height: 72)
            .onAppear {
                guard !reduceMotion else {
                    return
                }

                withAnimation(
                    .easeInOut(duration: presentation.phase.pulseDuration)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsing.toggle()
                }
                withAnimation(
                    .linear(duration: presentation.phase.rotationDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    isRotating.toggle()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
    }

    @ViewBuilder
    private var indicator: some View {
        if reduceMotion {
            ZStack {
                Image(presentation.phase.fullAssetName)
                    .resizable()
                    .scaledToFit()

                if presentation.showsWarningOrbit {
                    recordingOrbit
                }
            }
        } else {
            ZStack {
                animatedOrbit

                Image(presentation.phase.coreAssetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(isPulsing ? presentation.phase.corePulseScale : 1)
            }
            .scaleEffect(isPulsing ? presentation.phase.containerPulseScale : 1)
        }
    }

    @ViewBuilder
    private var animatedOrbit: some View {
        switch presentation.phase {
        case .recording:
            recordingOrbit
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        case .transcribing:
            transcribingOrbit
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
    }

    private var recordingOrbit: some View {
        ZStack {
            Circle()
                .stroke(
                    orbitAccent.opacity(0.82),
                    lineWidth: 1.35
                )
                .frame(width: 66, height: 66)

            Circle()
                .stroke(
                    orbitAccent.opacity(0.58),
                    lineWidth: 1.15
                )
                .frame(width: 58, height: 58)

            Circle()
                .fill(orbitAccent)
                .frame(width: 7, height: 7)
                .shadow(color: orbitAccent.opacity(0.8), radius: 4)
                .offset(y: -33)
        }
    }

    private var transcribingOrbit: some View {
        ZStack {
            Circle()
                .stroke(
                    orbitAccent.opacity(0.68),
                    lineWidth: 1.15
                )
                .frame(width: 62, height: 62)

            ForEach(0..<24, id: \.self) { index in
                Circle()
                    .fill(
                        orbitAccent.opacity(
                            index.isMultiple(of: 3) ? 0.9 : 0.48
                        )
                    )
                    .frame(
                        width: index.isMultiple(of: 4) ? 4.8 : 3.2,
                        height: index.isMultiple(of: 4) ? 4.8 : 3.2
                    )
                    .offset(y: -33)
                    .rotationEffect(.degrees(Double(index) * 15))
            }
        }
    }

    private func countdownBadge(_ countdown: VoiceSessionCountdown) -> some View {
        Text("\(countdown.remainingWholeSeconds)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(.black.opacity(0.78))
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var orbitAccent: Color {
        if presentation.showsWarningOrbit {
            return Color(red: 1, green: 0.7, blue: 0.08)
        }

        return presentation.phase.accent
    }
}

private extension FloatingIndicatorPresentation.Phase {
    var fullAssetName: String {
        switch self {
        case .recording:
            return "ActivityRecordingIndicatorLight"
        case .transcribing:
            return "ActivityTranscribingIndicatorLight"
        }
    }

    var coreAssetName: String {
        switch self {
        case .recording:
            return "ActivityRecordingCoreLight"
        case .transcribing:
            return "ActivityTranscribingCoreLight"
        }
    }

    var accent: Color {
        switch self {
        case .recording:
            return Color(red: 0.031, green: 0.545, blue: 0.941)
        case .transcribing:
            return Color(red: 0.388, green: 0.078, blue: 0.894)
        }
    }

    var pulseDuration: Double {
        switch self {
        case .recording:
            return 0.78
        case .transcribing:
            return 1.05
        }
    }

    var rotationDuration: Double {
        switch self {
        case .recording:
            return 1.8
        case .transcribing:
            return 2.4
        }
    }

    var corePulseScale: CGFloat {
        switch self {
        case .recording:
            return 1.035
        case .transcribing:
            return 1.02
        }
    }

    var containerPulseScale: CGFloat {
        switch self {
        case .recording:
            return 1.025
        case .transcribing:
            return 1.015
        }
    }
}

#Preview("Recording") {
    FloatingIndicatorView(
        presentation: FloatingIndicatorPresentation(
            phase: .recording,
            title: "Recording"
        )
    )
    .padding()
}

#Preview("Transcribing") {
    FloatingIndicatorView(
        presentation: FloatingIndicatorPresentation(
            phase: .transcribing,
            title: "Transcribing"
        )
    )
    .padding()
}
