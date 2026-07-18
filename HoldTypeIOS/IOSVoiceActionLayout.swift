import SwiftUI

struct IOSVoiceActionLayout: View {
    private let actions: [IOSForegroundVoiceAction]
    private let performAtIndex: (Int) -> Void

    init(
        commands: [IOSForegroundVoiceActionCommand],
        perform: @escaping (IOSForegroundVoiceActionCommand) -> Void
    ) {
        actions = commands.map(\.action)
        performAtIndex = { index in
            perform(commands[index])
        }
    }

    #if DEBUG
    init(previewActions: [IOSForegroundVoiceAction]) {
        actions = previewActions
        performAtIndex = { _ in }
    }
    #endif

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                actionButtons
            }
            VStack {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
            actionButton(action, at: index)
        }
    }

    @ViewBuilder
    private func actionButton(
        _ action: IOSForegroundVoiceAction,
        at index: Int
    ) -> some View {
        let presentation = IOSVoiceActionPresentation.resolve(action)
        switch presentation.prominence {
        case .primary:
            Button {
                performAtIndex(index)
            } label: {
                Label(presentation.title, systemImage: presentation.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(presentation.accessibilityIdentifier)
        case .secondary:
            Button {
                performAtIndex(index)
            } label: {
                Label(presentation.title, systemImage: presentation.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier(presentation.accessibilityIdentifier)
        case .destructive:
            Button(role: .destructive) {
                performAtIndex(index)
            } label: {
                Label(presentation.title, systemImage: presentation.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier(presentation.accessibilityIdentifier)
        }
    }
}

#if DEBUG
#Preview("Voice actions - wide") {
    IOSVoiceActionLayout(
        previewActions: [
            .startStandard,
            .startTranslation,
            .discard,
        ]
    )
    .padding()
    .frame(width: 620)
}

#Preview("Voice actions - compact") {
    IOSVoiceActionLayout(
        previewActions: [
            .retryPending,
            .discard,
        ]
    )
    .padding()
    .frame(width: 260)
}
#endif
