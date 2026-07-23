import AppKit
import HoldTypeDomain
import SwiftUI
import Testing
@testable import HoldType

@MainActor
@Suite(.serialized)
struct FixesEditorWindowPresenterTests {
    @Test func presenterCreatesNormalResizablePersistentWindow() throws {
        var activationCount = 0
        var restoredWindows: [NSWindow?] = []
        let presenter = makePresenter(
            activationHandler: { activationCount += 1 },
            restoreAccessoryHandler: { restoredWindows.append($0) }
        )

        presenter.show()
        let window = try #require(presenter.presentedWindow)
        defer { window.close() }

        #expect(window.title == "HoldType: Edit Fixes")
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(window.styleMask.contains(.miniaturizable))
        #expect(window.styleMask.contains(.resizable))
        #expect(window.minSize.width >= 760)
        #expect(window.minSize.height >= 520)
        #expect(!window.isReleasedWhenClosed)
        #expect(window.tabbingMode == .disallowed)
        #expect(window.contentViewController is NSHostingController<FixesEditorView>)
        #expect(activationCount == 1)
        #expect(restoredWindows.isEmpty)
    }

    @Test func hostedNavigationTitleDoesNotReplaceEditorWindowTitle() throws {
        let presenter = makePresenter(
            activationHandler: {},
            restoreAccessoryHandler: { _ in }
        )

        presenter.show()
        let window = try #require(presenter.presentedWindow)
        defer { window.close() }

        window.contentViewController?.title = "Translate"

        #expect(window.title == "HoldType: Edit Fixes")
    }

    @Test func repeatedShowReusesWindowAndCloseRestoresAccessoryState() throws {
        var activationCount = 0
        var restoreCount = 0
        let presenter = makePresenter(
            activationHandler: { activationCount += 1 },
            restoreAccessoryHandler: { _ in restoreCount += 1 }
        )

        presenter.show()
        let firstWindow = try #require(presenter.presentedWindow)
        presenter.show()
        let secondWindow = try #require(presenter.presentedWindow)

        #expect(firstWindow === secondWindow)
        #expect(activationCount == 2)

        firstWindow.close()
        #expect(restoreCount == 1)

        presenter.show()
        #expect(presenter.presentedWindow === firstWindow)
        #expect(activationCount == 3)
        presenter.presentedWindow?.close()
    }

    private func makePresenter(
        activationHandler: @escaping FixesEditorWindowPresenter.ActivationHandler,
        restoreAccessoryHandler:
            @escaping FixesEditorWindowPresenter.RestoreAccessoryHandler
    ) -> FixesEditorWindowPresenter {
        let catalog = TextFixCatalog.defaults
        let model = FixesEditorModel(
            store: FixesEditorTestStore(catalog: catalog),
            preloadedCatalog: catalog
        )
        return FixesEditorWindowPresenter(
            model: model,
            activationHandler: activationHandler,
            restoreAccessoryHandler: restoreAccessoryHandler
        )
    }
}
