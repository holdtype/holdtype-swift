import SwiftUI

struct TranscriptHistoryScene: Scene {
    static let identifier = "holdtype.transcript-history"

    var body: some Scene {
        Window(HoldTypeWindowTitle.history, id: Self.identifier) {
            TranscriptHistoryView()
        }
        .defaultSize(width: 760, height: 560)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
enum TranscriptHistoryWindowRequest {
    static let menuDismissalDelay: Duration = .milliseconds(150)

    static func openAfterMenuDismissal(
        dismissMenu: () -> Void,
        openHistory: @escaping @MainActor () -> Void
    ) {
        dismissMenu()

        Task { @MainActor in
            try? await Task.sleep(for: menuDismissalDelay)
            openHistory()
        }
    }
}
