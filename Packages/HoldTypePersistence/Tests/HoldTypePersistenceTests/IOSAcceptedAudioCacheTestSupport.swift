import Foundation
@testable import HoldTypePersistence

extension IOSAcceptedAudioCache {
    func retainedAudioFileURL(resultID: UUID) throws -> URL? {
        try playableAudioFileURL(resultID: resultID, policy: .unlimited)
    }
}
