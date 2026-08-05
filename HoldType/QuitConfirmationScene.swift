import Combine
import SwiftUI

enum QuitConfirmationDecision: Equatable {
    case cancel
    case quit
}

enum QuitConfirmationCopy {
    static func informativeText(launchAtLoginStatus: LaunchAtLoginStatus) -> String {
        var text = """
        \(HoldTypeMenuBarIdentity.title) will stop listening for dictation shortcuts and menu bar actions until you reopen it.
        """

        if !launchAtLoginStatus.isEnabled {
            text += "\n\nRight Command dictation will not be available after restart until \(HoldTypeMenuBarIdentity.title) is opened again."
        }

        return text
    }
}

@MainActor
protocol QuitConfirmationRequesting: AnyObject {
    func requestQuitConfirmation(
        completion: @escaping @MainActor (QuitConfirmationDecision) -> Void
    )
}

@MainActor
protocol QuitConfirmationPresenting {
    func requestQuitConfirmation() -> QuitConfirmationDecision
}

@MainActor
final class LegacyQuitConfirmationRequester: QuitConfirmationRequesting {
    private let presenter: any QuitConfirmationPresenting

    init(presenter: any QuitConfirmationPresenting) {
        self.presenter = presenter
    }

    func requestQuitConfirmation(
        completion: @escaping @MainActor (QuitConfirmationDecision) -> Void
    ) {
        completion(presenter.requestQuitConfirmation())
    }
}

@MainActor
final class QuitConfirmationCoordinator: ObservableObject, QuitConfirmationRequesting {
    static let shared = QuitConfirmationCoordinator()

    @Published private(set) var presentation: Presentation?

    private var openConfirmationWindow: (() -> Void)?
    private var completion: (@MainActor (QuitConfirmationDecision) -> Void)?
    private let launchAtLoginStatusProvider: @MainActor () -> LaunchAtLoginStatus

    init(
        launchAtLoginStatusProvider: @escaping @MainActor () -> LaunchAtLoginStatus = {
            LaunchAtLoginService().currentStatus()
        }
    ) {
        self.launchAtLoginStatusProvider = launchAtLoginStatusProvider
    }

    func install(openConfirmationWindow: @escaping () -> Void) {
        self.openConfirmationWindow = openConfirmationWindow
    }

    func requestQuitConfirmation(
        completion: @escaping @MainActor (QuitConfirmationDecision) -> Void
    ) {
        guard presentation == nil else {
            return
        }
        guard let openConfirmationWindow else {
            completion(.cancel)
            return
        }

        self.completion = completion
        presentation = Presentation(
            informativeText: QuitConfirmationCopy.informativeText(
                launchAtLoginStatus: launchAtLoginStatusProvider()
            )
        )
        openConfirmationWindow()
    }

    func resolve(_ decision: QuitConfirmationDecision) {
        guard presentation != nil else {
            return
        }

        presentation = nil
        let completion = self.completion
        self.completion = nil
        completion?(decision)
    }

    func cancelIfNeeded() {
        resolve(.cancel)
    }
}

extension QuitConfirmationCoordinator {
    struct Presentation: Equatable, Identifiable {
        let id = UUID()
        let title = "Quit \(HoldTypeMenuBarIdentity.title)?"
        let informativeText: String
    }
}

struct QuitConfirmationScene: Scene {
    static let identifier = "holdtype.quit-confirmation"

    var body: some Scene {
        Window("Quit \(HoldTypeMenuBarIdentity.title)?", id: Self.identifier) {
            QuitConfirmationWindowContent(coordinator: .shared)
        }
        .defaultSize(width: 440, height: 190)
        .windowResizability(.contentSize)
    }
}

private struct QuitConfirmationWindowContent: View {
    @ObservedObject var coordinator: QuitConfirmationCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let presentation = coordinator.presentation {
                QuitConfirmationDialog(
                    presentation: presentation,
                    onCancel: { resolve(.cancel) },
                    onQuit: { resolve(.quit) }
                )
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
        .onDisappear {
            coordinator.cancelIfNeeded()
        }
    }

    private func resolve(_ decision: QuitConfirmationDecision) {
        coordinator.resolve(decision)
        dismiss()
    }
}

private struct QuitConfirmationDialog: View {
    let presentation: QuitConfirmationCoordinator.Presentation
    let onCancel: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(presentation.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text(presentation.informativeText)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Quit \(HoldTypeMenuBarIdentity.title)", role: .destructive, action: onQuit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

#Preview("Quit confirmation") {
    QuitConfirmationDialog(
        presentation: .init(
            informativeText: "HoldType will stop listening for dictation shortcuts and menu bar actions until you reopen it."
        ),
        onCancel: {},
        onQuit: {}
    )
}
