import CryptoKit
import Foundation

nonisolated enum KeyboardFixBridgeConfiguration {
    static let metadataFilename = "keyboard-fix-metadata-v1.json"
    static let requestFilename = "keyboard-fix-request-v1.json"
    static let requestClaimFilename = "keyboard-fix-request-claim-v1.json"
    static let resultFilename = "keyboard-fix-result-v1.json"
    static let resultClaimFilename = "keyboard-fix-result-claim-v1.json"
    static let cancellationFilename =
        "keyboard-fix-cancellation-v1.json"
    static let cancellationClaimFilename =
        "keyboard-fix-cancellation-claim-v1.json"
    static let requestNotification =
        "app.holdtype.keyboard-fix.request.changed.v1"
    static let resultNotification =
        "app.holdtype.keyboard-fix.result.changed.v1"
    static let cancellationNotification =
        "app.holdtype.keyboard-fix.cancellation.changed.v1"

    static let maximumMetadataBytes = 64 * 1_024
    static let maximumRequestBytes = 40 * 1_024
    static let maximumResultBytes = 72 * 1_024
    static let maximumCancellationBytes = 4 * 1_024
    static let maximumActionCount = 100
    static let maximumIdentifierUTF8Bytes = 128
    static let maximumTitleCharacterCount = 80
    static let maximumIconUTF8Bytes = 128
    static let maximumSourceUTF8Bytes = 32 * 1_024
    static let maximumFingerprintUTF8Bytes = 128
    static let maximumOutputUTF8Bytes = 64 * 1_024
    static let maximumErrorCodeUTF8Bytes = 256
    static let recordLifetime: TimeInterval = 60

    static let translateIdentifier = "builtin.translate"
    static let fixIdentifier = "builtin.fix"
}

nonisolated enum KeyboardFixSourceFingerprint {
    static func make(for sourceText: String) -> String {
        SHA256.hash(data: Data(sourceText.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func matches(_ fingerprint: String, sourceText: String) -> Bool {
        fingerprint == make(for: sourceText)
    }
}

nonisolated enum KeyboardFixActionKind: String, Codable, CaseIterable, Sendable {
    case translate
    case fix
    case customPrompt
}

nonisolated enum KeyboardFixBridgeSignal {
    static func postRequestChanged() {
        post(KeyboardFixBridgeConfiguration.requestNotification)
    }

    static func postResultChanged() {
        post(KeyboardFixBridgeConfiguration.resultNotification)
    }

    static func postCancellationChanged() {
        post(KeyboardFixBridgeConfiguration.cancellationNotification)
    }

    private static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

nonisolated enum KeyboardFixIconToken: String, Codable, CaseIterable, Sendable {
    case translate
    case fix
    case improveWriting = "improve-writing"
    case makeShorter = "make-shorter"
    case summarize
    case bulletPoints = "bullet-points"
    case casual
    case markdown
    case formal
    case expand
    case rewrite
    case custom
}

nonisolated enum KeyboardFixSourceKind: String, Codable, Sendable {
    case selection
}

nonisolated struct KeyboardFixRequestIdentity: Equatable, Sendable {
    let revision: UInt64
    let requestID: UUID
    let actionIdentifier: String
    let sourceKind: KeyboardFixSourceKind
    let documentIdentifier: String
    let sourceFingerprint: String
}

nonisolated enum KeyboardFixBridgeValidation {
    static func isValidIdentifier(_ value: String) -> Bool {
        containsVisibleContent(value)
            && value.utf8.count
                <= KeyboardFixBridgeConfiguration.maximumIdentifierUTF8Bytes
    }

    static func isValidTitle(_ value: String) -> Bool {
        containsVisibleContent(value)
            && value.count
                <= KeyboardFixBridgeConfiguration.maximumTitleCharacterCount
    }

    static func isValidDocumentIdentifier(_ value: String) -> Bool {
        isValidIdentifier(value)
    }

    static func isValidFingerprint(_ value: String) -> Bool {
        containsVisibleContent(value)
            && value.utf8.count
                <= KeyboardFixBridgeConfiguration.maximumFingerprintUTF8Bytes
    }

    static func containsVisibleContent(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }
    }

    static func hasValidLifetime(
        issuedAt: Date,
        publishedAt: Date? = nil,
        expiresAt: Date
    ) -> Bool {
        guard issuedAt.timeIntervalSinceReferenceDate.isFinite,
              expiresAt.timeIntervalSinceReferenceDate.isFinite,
              expiresAt > issuedAt,
              expiresAt.timeIntervalSince(issuedAt)
                <= KeyboardFixBridgeConfiguration.recordLifetime
        else {
            return false
        }
        guard let publishedAt else {
            return true
        }
        return publishedAt.timeIntervalSinceReferenceDate.isFinite
            && publishedAt >= issuedAt
            && publishedAt < expiresAt
    }
}

nonisolated enum KeyboardFixBridgeStrictDecoding {
    static func requireExactKeys(
        _ expectedKeys: Set<String>,
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: KeyboardFixBridgeDynamicCodingKey.self
        )
        let actualKeys = Set(container.allKeys.map(\.stringValue))
        guard actualKeys == expectedKeys else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Keyboard Fix record has an invalid closed schema."
                )
            )
        }
    }

    static func invalidRecord(from decoder: Decoder) -> DecodingError {
        DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Keyboard Fix record failed validation."
            )
        )
    }
}

private struct KeyboardFixBridgeDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
