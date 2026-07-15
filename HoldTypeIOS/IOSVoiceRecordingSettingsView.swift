import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSVoiceRecordingSettingsView: View {
    @Environment(IOSAppSettingsStateOwner.self) private var stateOwner

    @State private var session: IOSSettingsEditorSession<
        IOSVoiceRecordingSettingsDraft
    >
    @State private var showsCacheReconciliationFailure = false
    private let attentionTarget: IOSSettingsAttentionTarget?
    private let reconcileRecordingCache: (
        RecordingCachePolicy
    ) async -> Bool

    init(
        preferences: VoiceSessionPreferences,
        recordingCachePolicy: RecordingCachePolicy,
        attentionTarget: IOSSettingsAttentionTarget? = nil,
        reconcileRecordingCache: @escaping (
            RecordingCachePolicy
        ) async -> Bool = { _ in true }
    ) {
        _session = State(
            initialValue: IOSSettingsEditorSession(
                value: IOSVoiceRecordingSettingsDraft(
                    preferences: preferences,
                    recordingCachePolicy: recordingCachePolicy.normalized
                )
            )
        )
        self.attentionTarget = attentionTarget
        self.reconcileRecordingCache = reconcileRecordingCache
    }

    var body: some View {
        IOSSettingsForm(attentionTarget: attentionTarget) {
            IOSSettingsEditorStatusSection(
                phase: session.phase,
                retry: retryAutosave,
                useSavedValue: { session.discard() }
            )

            Section("Feedback") {
                Toggle(
                    "Play Recording Start and Stop Sounds",
                    isOn: binding(\.preferences.audioCuesEnabled)
                )
                .iosSettingsField(
                    .voiceAudioCues,
                    attentionTarget: attentionTarget
                )
            }

            Section("Recording") {
                Picker(
                    "Keep Listening After Stop",
                    selection: binding(
                        \.preferences.recordingStopTailDuration
                    )
                ) {
                    ForEach(RecordingStopTailDuration.allCases, id: \.self) {
                        duration in
                        Text(duration.iosSettingsDisplayName).tag(duration)
                    }
                }
                .iosSettingsField(
                    .voiceFinishBuffer,
                    attentionTarget: attentionTarget
                )

                Text(
                    "A short finish buffer helps keep final words from being "
                        + "cut off."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Recording Cache") {
                Toggle(
                    "Keep completed recordings",
                    isOn: recordingCacheEnabledBinding
                )
                .iosSettingsField(
                    .voiceRecordingCache,
                    attentionTarget: attentionTarget
                )

                Text(recordingCacheDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if session.draft.recordingCachePolicy.keepsRecordings {
                    Picker(
                        "Retention",
                        selection: recordingCacheRetentionModeBinding
                    ) {
                        Text("Keep Last")
                            .tag(IOSRecordingCacheRetentionMode.keepLast)
                        Text("Unlimited")
                            .tag(IOSRecordingCacheRetentionMode.unlimited)
                    }
                    .pickerStyle(.segmented)
                    .iosSettingsField(
                        .voiceRecordingRetention,
                        attentionTarget: attentionTarget
                    )

                    if case .keepLast = session.draft.recordingCachePolicy.normalized {
                        Stepper(
                            "Keep last \(recordingCacheRetainedLimit) recordings",
                            value: recordingCacheRetainedLimitBinding,
                            in: 1...RecordingCachePolicy
                                .maximumRetainedRecordingLimit
                        )
                        .iosSettingsField(
                            .voiceRecordingLimit,
                            attentionTarget: attentionTarget
                        )
                    } else {
                        Label(
                            "Unlimited cache can keep growing until it is cleared.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Voice & Recording")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.voice-recording.screen")
        .onChange(of: durableDraft, initial: true) { _, value in
            observeDurableDraft(value)
        }
        .iosSettingsAutosaveChrome(phase: session.phase)
        .alert(
            "Recording Cache Update Failed",
            isPresented: $showsCacheReconciliationFailure
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Your setting was saved. HoldType will retry the cache update after the next recording."
            )
        }
    }

    private var durableDraft: IOSVoiceRecordingSettingsDraft {
        guard let settings = stateOwner.state.durableValue else {
            return session.baseline
        }
        return IOSVoiceRecordingSettingsDraft(
            preferences: settings.voiceSessionPreferences,
            recordingCachePolicy: settings.recordingCachePolicy.normalized
        )
    }

    private func binding<Field: Equatable>(
        _ keyPath: WritableKeyPath<IOSVoiceRecordingSettingsDraft, Field>
    ) -> Binding<Field> {
        Binding(
            get: { session.draft[keyPath: keyPath] },
            set: { value in
                guard session.set(value, at: keyPath) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private func startAutosaveIfNeeded() {
        guard let candidate = session.beginSave() else { return }
        Task { await commit(candidate) }
    }

    private func retryAutosave() {
        session.retry()
        startAutosaveIfNeeded()
    }

    private var recordingCacheEnabledBinding: Binding<Bool> {
        Binding(
            get: { session.draft.recordingCachePolicy.keepsRecordings },
            set: { isEnabled in
                guard session.set(
                    IOSRecordingCachePolicyEditor
                        .policyAfterSettingEnabled(isEnabled),
                    at: \.recordingCachePolicy
                ) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private var recordingCacheRetentionModeBinding: Binding<
        IOSRecordingCacheRetentionMode
    > {
        Binding(
            get: {
                session.draft.recordingCachePolicy.iosSettingsRetentionMode
            },
            set: { mode in
                guard session.set(
                    IOSRecordingCachePolicyEditor
                        .policyAfterSelectingRetention(
                            mode,
                            currentPolicy: session.draft.recordingCachePolicy
                        ),
                    at: \.recordingCachePolicy
                ) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private var recordingCacheRetainedLimitBinding: Binding<Int> {
        Binding(
            get: { recordingCacheRetainedLimit },
            set: { count in
                guard session.set(
                    .keepLast(count),
                    at: \.recordingCachePolicy
                ) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private var recordingCacheRetainedLimit: Int {
        session.draft.recordingCachePolicy.retainedRecordingLimit
    }

    private var recordingCacheDescription: String {
        switch session.draft.recordingCachePolicy.normalized {
        case .deleteImmediately:
            "HoldType deletes each completed recording after the attempt finishes."
        case .keepLast(let count):
            "HoldType keeps the last \(count) completed recordings for playback in History."
        case .unlimited:
            "HoldType keeps completed recordings for History playback until the cache is cleared."
        }
    }

    private func observeDurableDraft(
        _ value: IOSVoiceRecordingSettingsDraft
    ) {
        let previousPhase = session.phase
        session.observeDurableValue(value)
        if session.phase == .changedElsewhere,
           previousPhase != .changedElsewhere {
            iosAnnounceSettingsStatus(
                "Settings changed elsewhere. This draft is not saved."
            )
        }
    }

    private func commit(_ candidate: IOSVoiceRecordingSettingsDraft) async {
        do {
            let state = try await stateOwner.update {
                IOSAppSettingsEditorMutation.applyVoiceAndRecording(
                    candidate,
                    to: &$0
                )
            }
            guard let settings = state.durableValue else {
                commitFailed()
                return
            }
            let returned = IOSVoiceRecordingSettingsDraft(
                preferences: settings.voiceSessionPreferences,
                recordingCachePolicy: settings.recordingCachePolicy.normalized
            )
            session.commitSucceeded(
                returnedDurableValue: returned,
                latestDurableValue: durableDraft
            )
            switch session.phase {
            case .saved:
                let policy = settings.recordingCachePolicy.normalized
                if !(await reconcileRecordingCache(policy)),
                   durableDraft.recordingCachePolicy == policy {
                    showsCacheReconciliationFailure = true
                }
            case .pending:
                startAutosaveIfNeeded()
            case .changedElsewhere:
                iosAnnounceSettingsStatus(
                    "Voice and recording settings changed elsewhere"
                )
            case .idle, .saving, .validationBlocked, .saveFailed:
                break
            }
        } catch {
            commitFailed()
        }
    }

    private func commitFailed() {
        session.commitFailed(restoring: durableDraft)
        iosAnnounceSettingsStatus("Voice and recording settings were not saved")
    }
}
