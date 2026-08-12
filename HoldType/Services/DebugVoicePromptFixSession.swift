#if DEBUG
import Foundation
import HoldTypeOpenAI

@MainActor
final class DebugVoicePromptFixSession: VoicePromptFixCapturing {
    private var isRecording = false

    func start(
        settings: AppSettings,
        credential: OpenAICredential,
        automaticCompletionStarted: @escaping @MainActor () -> Void,
        automaticCompletion: @escaping @MainActor (
            Result<VoicePromptFixInstruction, Error>
        ) -> Void
    ) async throws {
        try Task.checkCancellation()
        isRecording = true
    }

    func finish() async throws -> VoicePromptFixInstruction {
        guard isRecording else {
            throw VoicePromptFixSessionError.notRecording
        }
        isRecording = false
        return VoicePromptFixInstruction(
            text: "Apply the controlled Voice Prompt instruction.",
            recoveryAttemptID: UUID()
        )
    }

    func completeApplication() {
        isRecording = false
    }

    func failApplication() {
        isRecording = false
    }

    func cancel() {
        isRecording = false
    }
}
#endif
