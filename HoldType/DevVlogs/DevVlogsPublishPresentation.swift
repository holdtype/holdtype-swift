import Foundation

nonisolated enum DevVlogsPublishAction: Hashable {
    case createVideo
    case retry
    case cancel
    case play
    case reveal
    case share
}

nonisolated enum DevVlogsPublishSection: Hashable {
    case sourceDay
    case clips
    case output
    case buildProgress
    case result
}

nonisolated struct DevVlogsPublishDay: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

nonisolated struct DevVlogsPublishClip: Identifiable, Equatable {
    enum Health: Equatable {
        case ready
        case missing
        case invalid
    }

    let id: String
    let title: String
    let detail: String
    let isSelected: Bool
    let health: Health
}

nonisolated struct DevVlogsPublishSelection: Equatable {
    let day: DevVlogsPublishDay
    let clips: [DevVlogsPublishClip]
    let outputLocation: String

    var selectedClipCount: Int {
        clips.filter(\.isSelected).count
    }
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
    case emptyDay(DevVlogsPublishDay)
    case selectionReady(DevVlogsPublishSelection)
    case selectionUnavailable(DevVlogsPublishSelection, message: String)
    case building(DevVlogsPublishSelection, DevVlogsPublishBuildProgress)
    case cancelled(DevVlogsPublishSelection, message: String)
    case failed(DevVlogsPublishSelection, message: String)
    case completed(DevVlogsPublishSelection, DevVlogsPublishArtifact)

    var visibleSections: [DevVlogsPublishSection] {
        switch self {
        case .noRecordings, .emptyDay, .selectionReady, .selectionUnavailable:
            return [.sourceDay, .clips, .output]
        case .building:
            return [.sourceDay, .clips, .output, .buildProgress]
        case .cancelled, .failed, .completed:
            return [.sourceDay, .clips, .output, .result]
        }
    }

    var permittedActions: Set<DevVlogsPublishAction> {
        switch self {
        case .selectionReady:
            return [.createVideo]
        case .building:
            return [.cancel]
        case .cancelled, .failed:
            return [.retry]
        case .completed:
            return [.play, .reveal, .share]
        case .noRecordings, .emptyDay, .selectionUnavailable:
            return []
        }
    }

    var selection: DevVlogsPublishSelection? {
        switch self {
        case .selectionReady(let selection),
             .selectionUnavailable(let selection, _),
             .building(let selection, _),
             .cancelled(let selection, _),
             .failed(let selection, _),
             .completed(let selection, _):
            return selection
        case .noRecordings, .emptyDay:
            return nil
        }
    }

    var day: DevVlogsPublishDay? {
        switch self {
        case .emptyDay(let day):
            return day
        case .selectionReady, .selectionUnavailable, .building, .cancelled, .failed, .completed:
            return selection?.day
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
    static let releaseEmpty = DevVlogsPublishPresentation(state: .noRecordings)

    let state: DevVlogsPublishState
    let enabledActions: Set<DevVlogsPublishAction>

    init(
        state: DevVlogsPublishState,
        enabledActions: Set<DevVlogsPublishAction> = []
    ) {
        self.state = state
        self.enabledActions = enabledActions.intersection(state.permittedActions)
    }

    func enables(_ action: DevVlogsPublishAction) -> Bool {
        enabledActions.contains(action)
    }
}
