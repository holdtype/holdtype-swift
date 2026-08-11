import Foundation

nonisolated enum DevVlogsPublishAction: Hashable {
    case openInFinder
    case refresh
    case createVideo
    case retry
    case cancel
    case play
    case reveal
    case share
}

nonisolated enum DevVlogsPublishSection: Hashable {
    case source
    case buildProgress
    case result
}

nonisolated struct DevVlogsPublishDay: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

nonisolated struct DevVlogsPublishApplication: Identifiable, Equatable {
    static let all = DevVlogsPublishApplication(
        id: "all-applications",
        title: "All Applications",
        detail: "Every application recorded that day"
    )

    let id: String
    let title: String
    let detail: String
}

nonisolated struct DevVlogsPublishSourceSummary: Equatable {
    let clipCount: Int
    let duration: TimeInterval
    let byteCount: Int64
    let invalidCount: Int

    var isReady: Bool {
        clipCount > 0 && invalidCount == 0
    }
}

nonisolated struct DevVlogsPublishSelection: Equatable {
    let day: DevVlogsPublishDay
    let application: DevVlogsPublishApplication
    let applications: [DevVlogsPublishApplication]
    let summary: DevVlogsPublishSourceSummary
    let outputLocation: String
}

nonisolated struct DevVlogsPublishBuildProgress: Equatable {
    let completedFraction: Double
    let detail: String

    var boundedFraction: Double {
        min(max(completedFraction, 0), 1)
    }
}

nonisolated struct DevVlogsPublishArtifact: Equatable {
    let buildID: UUID
    let name: String
    let detail: String
    let outputLocation: String
    let fileURL: URL
}

nonisolated enum DevVlogsPublishState: Equatable {
    case noRecordings
    case emptyDay(DevVlogsPublishSelection)
    case selectionReady(DevVlogsPublishSelection)
    case selectionUnavailable(DevVlogsPublishSelection, message: String)
    case building(DevVlogsPublishSelection, DevVlogsPublishBuildProgress)
    case cancelled(DevVlogsPublishSelection, message: String)
    case failed(DevVlogsPublishSelection, message: String)
    case completed(DevVlogsPublishSelection, DevVlogsPublishArtifact)

    var visibleSections: [DevVlogsPublishSection] {
        switch self {
        case .noRecordings, .emptyDay, .selectionReady, .selectionUnavailable:
            return [.source]
        case .building:
            return [.source, .buildProgress]
        case .cancelled, .failed, .completed:
            return [.source, .result]
        }
    }

    var permittedActions: Set<DevVlogsPublishAction> {
        switch self {
        case .noRecordings:
            return [.refresh]
        case .emptyDay, .selectionUnavailable:
            return [.openInFinder, .refresh]
        case .selectionReady:
            return [.openInFinder, .refresh, .createVideo]
        case .building:
            return [.cancel]
        case .cancelled, .failed:
            return [.openInFinder, .refresh, .retry]
        case .completed:
            return [.openInFinder, .refresh, .play, .reveal, .share]
        }
    }

    var selection: DevVlogsPublishSelection? {
        switch self {
        case .emptyDay(let selection),
             .selectionReady(let selection),
             .selectionUnavailable(let selection, _),
             .building(let selection, _),
             .cancelled(let selection, _),
             .failed(let selection, _),
             .completed(let selection, _):
            return selection
        case .noRecordings:
            return nil
        }
    }

    var isBuilding: Bool {
        if case .building = self { return true }
        return false
    }
}

nonisolated struct DevVlogsPublishPresentation: Equatable {
    static let releaseEmpty = DevVlogsPublishPresentation(
        state: .noRecordings,
        enabledActions: [.refresh]
    )

    let state: DevVlogsPublishState
    let enabledActions: Set<DevVlogsPublishAction>

    init(state: DevVlogsPublishState, enabledActions: Set<DevVlogsPublishAction> = []) {
        self.state = state
        self.enabledActions = enabledActions.intersection(state.permittedActions)
    }

    func enables(_ action: DevVlogsPublishAction) -> Bool {
        enabledActions.contains(action)
    }
}
