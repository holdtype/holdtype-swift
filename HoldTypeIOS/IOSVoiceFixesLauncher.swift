import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import SwiftUI

struct IOSVoiceFixesLauncher: View {
    @Binding var draftEditorIsFocused: Bool

    let isEnabled: Bool
    let visibleText: String
    let draftIsEditing: Bool
    let latestTargetSnapshot: IOSVoiceDraftTextTargetSnapshot?
    let catalogOwner: IOSVoiceFixesCatalogOwner
    let actionOwner: IOSVoiceDraftTextActionOwner

    @State private var capturedTarget: IOSVoiceDraftTextTargetSnapshot?
    @State private var showsFixes = false

    var body: some View {
        Button(action: presentFixes) {
            Label("Fixes", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .frame(minHeight: 36)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(!isEnabled)
        .accessibilityHint(
            "Choose a Fix for the selected Draft text or the complete Draft."
        )
        .accessibilityIdentifier("ios.voice.fixes.launcher")
        .popover(
            isPresented: fixesPresentationBinding,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            IOSVoiceFixesSurface(
                catalogState: catalogOwner.state,
                activeAction: actionOwner.activeAction,
                outcome: actionOwner.outcome,
                onSelect: submit,
                onRetryCatalog: {
                    Task { await catalogOwner.refresh() }
                },
                onCancelAction: actionOwner.cancelActiveAction,
                onDone: { showsFixes = false }
            )
            .presentationCompactAdaptation(.popover)
        }
        .task {
            if case .notLoaded = catalogOwner.state {
                await catalogOwner.refresh()
            }
        }
        .onChange(of: actionOwner.outcome) { _, outcome in
            guard case .completed = outcome else { return }
            showsFixes = false
        }
    }

    private var fixesPresentationBinding: Binding<Bool> {
        Binding(
            get: { showsFixes },
            set: { isPresented in
                showsFixes = isPresented
                guard !isPresented else { return }
                capturedTarget = nil
                actionOwner.cancelActiveAction()
            }
        )
    }

    private func presentFixes() {
        guard isEnabled else { return }
        let snapshot: IOSVoiceDraftTextTargetSnapshot?
        if draftIsEditing {
            snapshot = latestTargetSnapshot.flatMap {
                $0.text == visibleText ? $0 : nil
            }
        } else {
            snapshot = IOSVoiceDraftTextTargetSnapshot(
                text: visibleText,
                selectedRange: NSRange(location: 0, length: 0)
            )
        }
        guard let snapshot else { return }

        capturedTarget = snapshot
        actionOwner.dismissOutcome()
        draftEditorIsFocused = false
        showsFixes = true
    }

    private func submit(_ action: TextFixAction) {
        guard let capturedTarget else { return }
        actionOwner.dismissOutcome()
        Task {
            _ = await actionOwner.submit(
                action,
                capturing: capturedTarget
            )
        }
    }
}

#Preview("Fixes launcher") {
    let draftOwner = IOSVoiceDraftOwner(
        client: IOSVoiceDraftClient(
            load: { .empty },
            accept: { _, _ in throw CancellationError() },
            replace: { _, _ in throw CancellationError() }
        )
    )
    let actionOwner = IOSVoiceDraftTextActionOwner(
        draftOwner: draftOwner,
        client: IOSVoiceDraftTextActionClient { _, _ in
            .failure(.providerUnavailable)
        }
    )
    IOSVoiceFixesLauncher(
        draftEditorIsFocused: .constant(false),
        isEnabled: true,
        visibleText: "A Draft ready for a Fix.",
        draftIsEditing: false,
        latestTargetSnapshot: nil,
        catalogOwner: IOSVoiceFixesCatalogOwner(
            client: .init(load: { .defaults })
        ),
        actionOwner: actionOwner
    )
    .padding()
}
