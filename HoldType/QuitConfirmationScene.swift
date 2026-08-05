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
            QuitConfirmationAlertHost(coordinator: .shared)
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)
    }
}

private struct QuitConfirmationAlertHost: View {
    @ObservedObject var coordinator: QuitConfirmationCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: QuitConfirmationCoordinator.Presentation?
    @State private var isAlertPresented = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .alert(
                presentation?.title ?? "Quit \(HoldTypeMenuBarIdentity.title)?",
                isPresented: alertBinding
            ) {
                Button("Cancel", role: .cancel) {
                    resolve(.cancel)
                }
                .keyboardShortcut(.cancelAction)

                Button("Quit \(HoldTypeMenuBarIdentity.title)") {
                    resolve(.quit)
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text(presentation?.informativeText ?? "")
            }
            .onAppear(perform: synchronizePresentation)
            .onChange(of: coordinator.presentation) { _, _ in
                synchronizePresentation()
            }
        .onDisappear {
            coordinator.cancelIfNeeded()
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { isAlertPresented },
            set: { isPresented in
                isAlertPresented = isPresented
                if !isPresented {
                    resolve(.cancel)
                }
            }
        )
    }

    private func synchronizePresentation() {
        presentation = coordinator.presentation
        isAlertPresented = presentation != nil
    }

    private func resolve(_ decision: QuitConfirmationDecision) {
        coordinator.resolve(decision)
        dismiss()
    }
}
