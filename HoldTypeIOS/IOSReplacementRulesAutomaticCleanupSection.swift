import HoldTypePersistence
import SwiftUI

struct IOSReplacementRulesAutomaticCleanupSection: View {
    private enum Presentation {
        case loading
        case unavailable
        case available(isEnabled: Bool)
    }

    private let presentation: Presentation
    private let isLoading: Bool
    private let isSaving: Bool
    private let saveFailed: Bool
    private let retryLoad: () -> Void
    private let setEnabled: (Bool) -> Void

    init(
        state: IOSAppSettingsState,
        isLoading: Bool,
        isSaving: Bool,
        saveFailed: Bool,
        retryLoad: @escaping () -> Void,
        setEnabled: @escaping (Bool) -> Void
    ) {
        switch state {
        case .notLoaded:
            presentation = .loading
        case .loadFailed:
            presentation = .unavailable
        case .ready(let settings):
            presentation = .available(
                isEnabled: settings.localTextCleanupEnabled
            )
        case .saveFailed(let lastDurableValue):
            presentation = .available(
                isEnabled: lastDurableValue.localTextCleanupEnabled
            )
        }
        self.isLoading = isLoading
        self.isSaving = isSaving
        self.saveFailed = saveFailed
        self.retryLoad = retryLoad
        self.setEnabled = setEnabled
    }

    var body: some View {
        Section("Automatic Cleanup") {
            switch presentation {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading automatic cleanup")
                        .foregroundStyle(.secondary)
                }
            case .unavailable:
                Label(
                    "Automatic cleanup is unavailable",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)

                Button("Retry Automatic Cleanup", action: retryLoad)
                    .disabled(isLoading)
            case .available(let isEnabled):
                controls(isEnabled: isEnabled)
            }
        }
    }

    @ViewBuilder
    private func controls(isEnabled: Bool) -> some View {
        Toggle(
            "Use Plain Typography Cleanup",
            isOn: Binding(
                get: { isEnabled },
                set: setEnabled
            )
        )
        .disabled(isSaving)
        .accessibilityIdentifier(
            "ios.library.replacement-rules.automatic-cleanup.toggle"
        )

        if isSaving {
            HStack(spacing: 10) {
                ProgressView()
                Text("Saving automatic cleanup")
                    .foregroundStyle(.secondary)
            }
        } else if saveFailed {
            Label(
                "Automatic cleanup was not saved. The saved setting is shown.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Text("On by default. Runs locally without another OpenAI request.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        DisclosureGroup("What Automatic Cleanup Changes") {
            ForEach(
                IOSAutomaticCleanupPresentation.transformationDescriptions,
                id: \.self
            ) { description in
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(
            "ios.library.replacement-rules.automatic-cleanup.details"
        )
    }
}

#Preview("Replacement rules — automatic cleanup") {
    Form {
        IOSReplacementRulesAutomaticCleanupSection(
            state: .ready(.defaults),
            isLoading: false,
            isSaving: false,
            saveFailed: false,
            retryLoad: {},
            setEnabled: { _ in }
        )
    }
}
