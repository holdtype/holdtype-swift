import Foundation
import HoldTypePersistence
import SwiftUI

struct IOSProviderConsentPrivacySection: View {
    let state: IOSProviderConsentPrivacyState
    let isBusy: Bool
    let progressTitle: String
    let failureDetail: String?
    let attentionTarget: IOSSettingsAttentionTarget?
    let onReview: () -> Void
    let onReset: () -> Void

    var body: some View {
        Section("OpenAI Processing Consent") {
            switch state {
            case .notLoaded, .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading consent status…")
                    Spacer()
                }
                .accessibilityElement(children: .combine)
            case .ready(let snapshot):
                let presentation = IOSConsentPrivacyPresentation.resolve(
                    snapshot
                )
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.title)
                        Text(presentation.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let decisionAt = snapshot.decisionAt {
                            Text(
                                decisionAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: presentation.systemImage)
                        .foregroundStyle(presentation.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ios.privacy.consent-status")
                .iosSettingsField(
                    .privacyProviderConsent,
                    attentionTarget: attentionTarget
                )

                if presentation.action == .acceptCurrentDisclosure {
                    Button("Review and Accept", action: onReview)
                        .disabled(isBusy)
                        .accessibilityIdentifier(
                            "ios.privacy.consent.accept"
                        )
                }

                if snapshot.canResetUnreadableData {
                    Button(
                        "Reset Unreadable Consent Data",
                        role: .destructive,
                        action: onReset
                    )
                    .disabled(isBusy)
                    .accessibilityIdentifier(
                        "ios.privacy.consent.reset-unreadable"
                    )
                }
            }

            if isBusy {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(progressTitle)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
            }

            if let failureDetail {
                Label {
                    Text(failureDetail)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ios.privacy.consent.failure")
            }
        }
    }
}

#if DEBUG
#Preview("Review required") {
    List {
        IOSProviderConsentPrivacySection(
            state: .ready(
                IOSProviderConsentPrivacySnapshot(
                    status: .notReviewed,
                    decisionAt: nil,
                    canResetUnreadableData: false,
                    requiresExplicitAcceptance: true
                )
            ),
            isBusy: false,
            progressTitle: "Ready",
            failureDetail: nil,
            attentionTarget: nil,
            onReview: {},
            onReset: {}
        )
    }
    .listStyle(.insetGrouped)
}

#Preview("Accepted") {
    List {
        IOSProviderConsentPrivacySection(
            state: .ready(
                IOSProviderConsentPrivacySnapshot(
                    status: .acceptedCurrentDisclosure,
                    decisionAt: Date(timeIntervalSince1970: 1_725_192_000),
                    canResetUnreadableData: false,
                    requiresExplicitAcceptance: false
                )
            ),
            isBusy: false,
            progressTitle: "Ready",
            failureDetail: nil,
            attentionTarget: nil,
            onReview: {},
            onReset: {}
        )
    }
    .listStyle(.insetGrouped)
}

#Preview("Unreadable data") {
    List {
        IOSProviderConsentPrivacySection(
            state: .ready(
                IOSProviderConsentPrivacySnapshot(
                    status: .localDataUnavailable,
                    decisionAt: nil,
                    canResetUnreadableData: true,
                    requiresExplicitAcceptance: false
                )
            ),
            isBusy: false,
            progressTitle: "Ready",
            failureDetail: "HoldType couldn’t read your saved consent.",
            attentionTarget: nil,
            onReview: {},
            onReset: {}
        )
    }
    .listStyle(.insetGrouped)
}
#endif
