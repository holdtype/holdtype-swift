#if DEBUG
import SwiftUI
import HoldTypeDomain

struct DictationStartQAApplication: App {
    @NSApplicationDelegateAdaptor(HoldTypeAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("HoldType QA") { DictationStartQAView() }
    }
}

/// Only the explicit, provider-free QA launch installs this control surface.
struct DictationStartQAView: View {
    @ObservedObject private var runtime = DictationRuntime.shared

    var body: some View {
        Self.content(status: runtime.status) {
            Task { await runtime.performRecordingAction() }
        }
    }

    static func content(status: DictationStatus, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text("HoldType QA").font(.title2)
            Text("Local start/stop check. Provider and text output are disabled.")
            Text(String(describing: status)).accessibilityIdentifier("qa-dictation-status")
            Button(status.voiceWorkPhase == .listening ? "Stop recording" : "Start recording", action: action)
            .accessibilityIdentifier("qa-recording-action")
        }
        .padding(24)
        .frame(width: 420)
    }
}
#Preview { DictationStartQAView.content(status: .idle, action: {}) }
#endif
