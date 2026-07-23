import AppKit
import SwiftUI

@MainActor
final class FixesEditorWindowPresenter: NSObject, NSWindowDelegate {
    typealias ActivationHandler = @MainActor () -> Void
    typealias RestoreAccessoryHandler = @MainActor (NSWindow?) -> Void

    static let shared = FixesEditorWindowPresenter(
        model: FixesEditorModel(store: MacOSTextFixCatalogStore())
    )

    private var window: NSWindow?
    private let model: FixesEditorModel
    private let activationHandler: ActivationHandler
    private let restoreAccessoryHandler: RestoreAccessoryHandler

    init(
        model: FixesEditorModel,
        activationHandler: @escaping ActivationHandler = {
            AppWindowActivation.showRegularApp()
        },
        restoreAccessoryHandler: @escaping RestoreAccessoryHandler = {
            AppWindowActivation.restoreAccessoryIfNoVisibleAppWindows(excluding: $0)
        }
    ) {
        self.model = model
        self.activationHandler = activationHandler
        self.restoreAccessoryHandler = restoreAccessoryHandler
        super.init()
    }

    var presentedWindow: NSWindow? {
        window
    }

    func showAfterMenuDismissal() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            show()
        }
    }

    func show() {
        activationHandler()
        let editorWindow = window ?? makeWindow()
        window = editorWindow
        editorWindow.makeKeyAndOrderFront(nil)
        editorWindow.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        restoreAccessoryHandler(notification.object as? NSWindow)
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: FixesEditorView(model: model)
        )
        let editorWindow = NSWindow(contentViewController: hostingController)
        editorWindow.title = HoldTypeWindowTitle.titled("Edit Fixes")
        editorWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        editorWindow.minSize = NSSize(width: 760, height: 520)
        editorWindow.setContentSize(NSSize(width: 900, height: 620))
        editorWindow.center()
        editorWindow.isReleasedWhenClosed = false
        editorWindow.tabbingMode = .disallowed
        editorWindow.setFrameAutosaveName("HoldType.FixesEditor")
        editorWindow.delegate = self
        return editorWindow
    }
}
