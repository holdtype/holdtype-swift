import AppKit

enum QuitConfirmationDecision: Equatable {
    case cancel
    case quit
}

enum QuitConfirmationCopy {
    static let title = "Quit \(HoldTypeMenuBarIdentity.title)?"
    static let cancelButtonTitle = "Cancel"
    static let quitButtonTitle = "Quit \(HoldTypeMenuBarIdentity.title)"
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

/// A narrow system-dialog adapter for app termination confirmation.
///
/// The SwiftUI alert host used in 1.0.9 required a one-point hidden window. On macOS that
/// window can enter a recursive constraints pass while termination is being cancelled,
/// leaving the process inert or raising an AppKit layout exception. `NSAlert.runModal()`
/// keeps this existing native dialog independent of SwiftUI scene teardown; all subsequent
/// recording finalization still runs through `HoldTypeAppDelegate` after the modal returns.
@MainActor
struct NativeQuitConfirmationPresenter: QuitConfirmationPresenting {
    func requestQuitConfirmation() -> QuitConfirmationDecision {
        let shouldRestoreConfiguredPolicyAfterCancel = !hasVisibleAppWindow

        AppWindowActivation.activateForWindowPresentation()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = QuitConfirmationCopy.title
        alert.addButton(withTitle: QuitConfirmationCopy.cancelButtonTitle)
        alert.addButton(withTitle: QuitConfirmationCopy.quitButtonTitle)

        bringAlertToFront(alert)
        let decision: QuitConfirmationDecision = alert.runModal() == .alertSecondButtonReturn
            ? .quit
            : .cancel

        if decision == .cancel, shouldRestoreConfiguredPolicyAfterCancel {
            AppWindowActivation.restoreConfiguredPolicyIfNoVisibleAppWindows(
                excluding: alert.window
            )
        }

        return decision
    }

    private func bringAlertToFront(_ alert: NSAlert) {
        let alertWindow = alert.window
        alertWindow.level = .modalPanel
        alertWindow.collectionBehavior = alertWindow.collectionBehavior.union(.moveToActiveSpace)
        alertWindow.makeKeyAndOrderFront(nil)
        alertWindow.orderFrontRegardless()
    }

    private var hasVisibleAppWindow: Bool {
        NSApplication.shared.windows.contains { window in
            window.isVisible
                && !window.isMiniaturized
                && window.canBecomeKey
        }
    }
}
