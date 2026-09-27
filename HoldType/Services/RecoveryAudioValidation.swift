import Foundation
import HoldTypeOpenAI

enum RecoveryAudioValidation {
    static func validate(at url: URL) throws {
        guard TranscriptionFailureRecoveryArtifactFormat.regularNonemptyFile(
            at: url, fileManager: .default
        ) != nil, (try? TranscriptionAudioValidation.validate(url)) != nil else {
            throw TranscriptionFailureRecoveryError.audioUnavailable
        }
    }
}
