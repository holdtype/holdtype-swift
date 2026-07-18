import Foundation
import SwiftUI
import UIKit

struct IOSPrivacyPermissionsView: View {
    @Environment(IOSProviderConsentPresentationOwner.self)
    private var consentOwner
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingConfirmation:
        IOSPrivacyConsentConfirmation?
    @State private var disclosureReview:
        IOSPrivacyConsentConfirmation?
    @State private var accessibilityAnnouncementTask: Task<Void, Never>?
    @State private var accessibilityAnnouncementCandidate:
        IOSAccessibilityAnnouncementCandidate?
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(attentionTarget: IOSSettingsAttentionTarget? = nil) {
        self.attentionTarget = attentionTarget
    }

    var body: some View {
        IOSSettingsAttentionScrollView(attentionTarget: activeAttentionTarget) {
            List {
                microphoneSection
                providerConsentSection
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Privacy & Permissions")
        .accessibilityIdentifier("ios.privacy-permissions")
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await consentOwner.activatePrivacy() }
        }
        .onChange(of: consentOwner.confirmationRevision) { _, _ in
            if let pendingConfirmation,
               !consentOwner.isPrivacyConfirmationCurrent(
                   pendingConfirmation.token
               ) {
                self.pendingConfirmation = nil
            }
            if let disclosureReview,
               !consentOwner.isPrivacyConfirmationCurrent(
                   disclosureReview.token
               ) {
                self.disclosureReview = nil
            }
        }
        .onChange(of: consentOwner.privacyState) { _, state in
            guard case .ready(let snapshot) = state else { return }
            let presentation = IOSConsentPrivacyPresentation.resolve(snapshot)
            scheduleAccessibilityAnnouncement(
                IOSAccessibilityAnnouncement.message(
                    title: presentation.title,
                    detail: presentation.detail
                ),
                priority: .status
            )
        }
        .onChange(of: consentOwner.failure) { _, failure in
            guard let failure else { return }
            scheduleAccessibilityAnnouncement(
                IOSAccessibilityAnnouncement.message(
                    title: "Consent action failed",
                    detail: failure.detail
                ),
                priority: .content
            )
        }
        .onChange(of: consentOwner.notice) { _, notice in
            guard let notice else { return }
            scheduleAccessibilityAnnouncement(
                notice.title,
                priority: .content
            )
        }
        .onDisappear {
            accessibilityAnnouncementTask?.cancel()
            accessibilityAnnouncementTask = nil
            accessibilityAnnouncementCandidate = nil
        }
        .sheet(item: $disclosureReview) { confirmation in
            IOSProviderConsentPrivacyReviewSheet(
                confirmation: confirmation,
                consentOwner: consentOwner
            )
        }
        .confirmationDialog(
            "Reset Unreadable Consent Data?",
            isPresented: Binding(
                get: { pendingConfirmationIsCurrent },
                set: { if !$0 { pendingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingConfirmation {
                Button(
                    "Reset Consent Data",
                    role: .destructive
                ) {
                    _ = consentOwner.confirmPrivacyAction(
                        pendingConfirmation.token
                    )
                    self.pendingConfirmation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            Text(
                "This removes only the unreadable consent decision. Your API "
                    + "key, settings, History, and results stay unchanged."
            )
        }
    }

    private var activeAttentionTarget: IOSSettingsAttentionTarget? {
        IOSPrivacySettingsAttentionResolver.activeTarget(
            attentionTarget,
            privacyState: consentOwner.privacyState,
            microphoneStatus: consentOwner.microphoneStatus
        )
    }

    private var microphoneSection: some View {
        let presentation = IOSMicrophonePrivacyPresentation.resolve(
            consentOwner.microphoneStatus
        )

        return Section("Microphone") {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                    Text(presentation.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(presentation.color)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ios.privacy.microphone-status")
            .iosSettingsField(
                .privacyMicrophone,
                attentionTarget: activeAttentionTarget
            )

            if consentOwner.microphoneStatus == .denied,
               let settingsURL = URL(
                   string: UIApplication.openSettingsURLString
               ) {
                Link(destination: settingsURL) {
                    Label(
                        "Open System Settings",
                        systemImage: "arrow.up.forward.app"
                    )
                }
                .accessibilityIdentifier(
                    "ios.privacy.microphone-open-settings"
                )
            }
        }
    }

    private var providerConsentSection: some View {
        IOSProviderConsentPrivacySection(
            state: consentOwner.privacyState,
            isBusy: consentOwner.isBusy,
            progressTitle: consentOwner.operation.progressTitle,
            failureDetail: consentOwner.failure?.detail,
            attentionTarget: activeAttentionTarget,
            onReview: beginDisclosureReview,
            onReset: beginResetConfirmation
        )
    }

    private var pendingConfirmationIsCurrent: Bool {
        guard let pendingConfirmation else { return false }
        return consentOwner.isPrivacyConfirmationCurrent(
            pendingConfirmation.token
        )
    }

    private func beginResetConfirmation() {
        guard let token = consentOwner.makePrivacyConfirmation(
            for: .resetUnreadableData
        ) else {
            return
        }
        pendingConfirmation = IOSPrivacyConsentConfirmation(
            token: token
        )
    }

    private func beginDisclosureReview() {
        guard let token = consentOwner.makePrivacyConfirmation(
            for: .acceptCurrentDisclosure
        ) else {
            return
        }
        disclosureReview = IOSPrivacyConsentConfirmation(
            token: token
        )
    }

    private func scheduleAccessibilityAnnouncement(
        _ message: String,
        priority: IOSAccessibilityAnnouncementCandidate.Priority
    ) {
        let incoming = IOSAccessibilityAnnouncementCandidate(
            message: message,
            priority: priority
        )
        let preferred = IOSAccessibilityAnnouncementCandidate.preferred(
            current: accessibilityAnnouncementCandidate,
            incoming: incoming
        )
        guard preferred != accessibilityAnnouncementCandidate else { return }

        accessibilityAnnouncementCandidate = preferred
        accessibilityAnnouncementTask?.cancel()
        accessibilityAnnouncementTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled,
                  accessibilityAnnouncementCandidate == preferred else {
                return
            }
            accessibilityAnnouncementCandidate = nil
            accessibilityAnnouncementTask = nil
            IOSAccessibilityAnnouncement.post(preferred.message)
        }
    }
}

private struct IOSPrivacyConsentConfirmation: Identifiable {
    let id = UUID()
    let token: IOSProviderConsentConfirmationToken
}

private struct IOSProviderConsentPrivacyReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let confirmation: IOSPrivacyConsentConfirmation
    let consentOwner: IOSProviderConsentPresentationOwner

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        Text(
                            "See what HoldType sends to OpenAI and what stays "
                                + "on this iPhone."
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.tint)
                    }
                }

                IOSProviderConsentDisclosureSections()

                Section {
                    Button {
                        if consentOwner.confirmPrivacyAction(
                            confirmation.token
                        ) == .accepted {
                            dismiss()
                        }
                    } label: {
                        Label(
                            "Accept Current Disclosure",
                            systemImage: "checkmark"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(
                        consentOwner.isBusy
                            || !consentOwner.isPrivacyConfirmationCurrent(
                                confirmation.token
                            )
                    )
                    .accessibilityIdentifier(
                        "ios.privacy.consent.review-accept"
                    )
                } footer: {
                    Text(
                        "A request already received by OpenAI cannot be "
                            + "recalled."
                    )
                }
            }
            .navigationTitle("OpenAI Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: consentOwner.confirmationRevision) { _, _ in
            guard !consentOwner.isPrivacyConfirmationCurrent(
                confirmation.token
            ) else {
                return
            }
            dismiss()
        }
        .accessibilityIdentifier("ios.privacy.consent.review-sheet")
    }
}

private extension IOSProviderConsentPresentationOperation {
    var progressTitle: String {
        switch self {
        case .idle:
            "Ready"
        case .acceptingVoice, .acceptingPrivacy:
            "Saving acceptance…"
        case .decliningVoice:
            "Saving withdrawal…"
        case .resettingUnreadableData:
            "Resetting consent data…"
        }
    }
}

private extension IOSProviderConsentPresentationNotice {
    var title: String {
        switch self {
        case .accepted:
            "Consent accepted"
        case .withdrawn:
            "Consent withdrawn"
        case .unreadableDataReset:
            "Unreadable consent data reset"
        }
    }
}

private extension IOSProviderConsentPresentationFailure {
    var detail: String {
        switch self {
        case .statusChanged:
            "Consent changed elsewhere. Review the current status."
        case .localDataUnavailable:
            "HoldType couldn’t read your saved consent."
        case .decisionNotSaved:
            "The decision wasn’t saved. Try again."
        case .operationFailed:
            "The consent change failed. Try again."
        }
    }
}
