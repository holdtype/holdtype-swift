//
//  IOSVoiceRuntimeUnavailableView.swift
//  HoldTypeIOS
//
//  Created by Codex on 7/18/26.
//

import SwiftUI

struct IOSVoiceRuntimeUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Voice Unavailable", systemImage: "mic.slash")
        } description: {
            Text(
                "Foreground Voice could not be composed safely. Settings, "
                    + "Dictation Rules, and ordinary keyboard typing remain available."
            )
        }
        .navigationTitle("Voice")
        .accessibilityIdentifier("ios.voice.runtime-unavailable")
    }
}

#Preview("Voice unavailable") {
    NavigationStack {
        IOSVoiceRuntimeUnavailableView()
    }
}
