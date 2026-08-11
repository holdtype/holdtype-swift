import SwiftUI

struct DevVlogsScene: Scene {
    static let identifier = "holdtype.dev-vlogs"

    var body: some Scene {
        Window(HoldTypeWindowTitle.titled("Dev Vlogs"), id: Self.identifier) {
            DevVlogsWindowRoot()
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
enum DevVlogsWindowRequest {
    static let menuDismissalDelay: Duration = .milliseconds(100)

    static func openAfterMenuDismissal(
        dismissMenu: () -> Void,
        openDevVlogs: @escaping @MainActor () -> Void
    ) {
        openAfterMenuDismissal(
            dismissMenu: dismissMenu,
            scheduleAfterMenuDismissal: scheduleAfterMenuDismissal,
            activateApplication: AppWindowActivation.showRegularApp,
            openDevVlogs: openDevVlogs
        )
    }

    static func openAfterMenuDismissal(
        dismissMenu: () -> Void,
        scheduleAfterMenuDismissal: @escaping (@escaping @MainActor () -> Void) -> Void,
        activateApplication: @escaping @MainActor () -> Void,
        openDevVlogs: @escaping @MainActor () -> Void
    ) {
        dismissMenu()

        scheduleAfterMenuDismissal {
            activateApplication()
            openDevVlogs()
        }
    }

    private static func scheduleAfterMenuDismissal(
        _ action: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            try? await Task.sleep(for: menuDismissalDelay)
            action()
        }
    }
}
