import Foundation

enum IOSVoiceStateValidation {
    static func isCanonicalCaptureAudioIdentifier(
        _ value: String,
        attemptID: UUID
    ) -> Bool {
        isCanonicalRelativeAudioIdentifier(value, attemptID: attemptID)
    }

    static func isCanonicalRelativeAudioIdentifier(
        _ value: String,
        attemptID: UUID
    ) -> Bool {
        value == IOSVoiceStateStorageLocation.relativeAudioIdentifier(
            for: attemptID
        ) || value == IOSVoiceStateStorageLocation.relativeAudioIdentifier(
            for: attemptID,
            extension: "wav"
        )
    }

    static func isValidDate(_ date: Date) -> Bool {
        date.timeIntervalSince1970.isFinite
            && date.timeIntervalSince1970 >= 0
    }

    static func isValidModel(_ model: String) -> Bool {
        !model.isEmpty && model.utf8.count <= 256
            && model == model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidLanguageCode(_ code: String?) -> Bool {
        guard let code else { return true }
        guard code.count == 2 || code.count == 3 else { return false }
        return code.unicodeScalars.allSatisfy {
            $0.isASCII && (97...122).contains($0.value)
        }
    }

    static func isStoredText(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.count <= 1_000_000
            && text == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func milliseconds(from date: Date) throws -> Int64 {
        guard isValidDate(date) else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        let value = date.timeIntervalSince1970 * 1_000
        guard value.isFinite,
              value >= 0,
              value <= Double(Int64.max) else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        return Int64(value.rounded(.toNearestOrAwayFromZero))
    }

    static func date(from milliseconds: Int64) throws -> Date {
        guard milliseconds >= 0 else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        let date = Date(
            timeIntervalSince1970: Double(milliseconds) / 1_000
        )
        guard try self.milliseconds(from: date) == milliseconds else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        return date
    }
}
