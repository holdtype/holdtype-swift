import HoldTypePersistence
import SwiftUI

nonisolated enum IOSPrivacySettingsAttentionResolver {
    static func activeTarget(
        _ target: IOSSettingsAttentionTarget?,
        privacyState: IOSProviderConsentPrivacyState,
        microphoneStatus: IOSMicrophonePermissionStatus
    ) -> IOSSettingsAttentionTarget? {
        guard let target else { return nil }

        switch target.attention {
        case .privacyReview:
            guard case .ready(let snapshot) = privacyState else {
                return target
            }
            return snapshot.status == .acceptedCurrentDisclosure
                && !snapshot.requiresExplicitAcceptance
                ? nil
                : target
        case .microphonePermission:
            return microphoneStatus == .granted ? nil : target
        default:
            return target
        }
    }
}

struct IOSMicrophonePrivacyPresentation {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    static func resolve(_ status: IOSMicrophonePermissionStatus) -> Self {
        switch status {
        case .undetermined:
            Self(
                title: "Not Requested",
                detail: "Asked the first time you start dictation.",
                systemImage: "mic.badge.plus",
                color: .secondary
            )
        case .denied:
            Self(
                title: "Access Denied",
                detail:
                    "Allow microphone access in System Settings before recording.",
                systemImage: "mic.slash.fill",
                color: .orange
            )
        case .granted:
            Self(
                title: "Access Granted",
                detail: "Used only while you record.",
                systemImage: "mic.fill",
                color: .green
            )
        case .unavailable:
            Self(
                title: "Status Unavailable",
                detail: "HoldType couldn’t read microphone access.",
                systemImage: "mic.slash",
                color: .red
            )
        }
    }
}

struct IOSConsentPrivacyPresentation {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color
    let action: IOSProviderConsentPrivacyAction?

    static func resolve(
        _ snapshot: IOSProviderConsentPrivacySnapshot
    ) -> Self {
        if snapshot.requiresExplicitAcceptance {
            return Self(
                title: "Review Required",
                detail: "Review the updated disclosure before using Voice or Fixes.",
                systemImage: "hand.raised",
                color: .orange,
                action: .acceptCurrentDisclosure
            )
        }

        return switch snapshot.status {
        case .notReviewed:
            Self(
                title: "Not Reviewed",
                detail: "Review what HoldType sends before using Voice or Fixes.",
                systemImage: "hand.raised",
                color: .secondary,
                action: .acceptCurrentDisclosure
            )
        case .acceptedCurrentDisclosure:
            Self(
                title: "Accepted",
                detail: "Voice and Fixes can send chosen content to OpenAI.",
                systemImage: "checkmark.shield.fill",
                color: .green,
                action: nil
            )
        case .reviewRequired:
            Self(
                title: "Review Required",
                detail: "The processing disclosure changed and needs acceptance.",
                systemImage: "exclamationmark.shield",
                color: .orange,
                action: .acceptCurrentDisclosure
            )
        case .withdrawn:
            Self(
                title: "Withdrawn",
                detail: "Voice and Fixes will not send requests to OpenAI.",
                systemImage: "hand.raised.slash",
                color: .orange,
                action: .acceptCurrentDisclosure
            )
        case .localDataUnavailable:
            Self(
                title: "Consent Unavailable",
                detail: "HoldType couldn’t read your saved consent.",
                systemImage: "exclamationmark.triangle",
                color: .red,
                action: nil
            )
        }
    }
}
