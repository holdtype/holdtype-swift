import AppKit
import Foundation

@MainActor
protocol DevVlogsFileActionPerforming {
    func reveal(_ url: URL)
}

@MainActor
struct SystemDevVlogsFileActions: DevVlogsFileActionPerforming {
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
