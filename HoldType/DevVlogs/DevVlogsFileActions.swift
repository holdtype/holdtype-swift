import AppKit
import Foundation

@MainActor
protocol DevVlogsFileActionPerforming {
    func reveal(_ url: URL)
    func open(_ url: URL)
}

extension DevVlogsFileActionPerforming {
    func open(_ url: URL) {
        reveal(url)
    }
}

@MainActor
struct SystemDevVlogsFileActions: DevVlogsFileActionPerforming {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
