import Foundation

enum DevVlogsPublishAction: Hashable {
    case createVideo
    case cancel
    case play
    case reveal
    case share
}

enum DevVlogsPublishSection: Hashable {
    case sourceDay
    case clips
    case output
    case buildProgress
    case result
}

struct DevVlogsPublishDay: Equatable {
    let title: String
    let detail: String
}

struct DevVlogsPublishClip: Identifiable, Equatable {
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

struct DevVlogsPublishSelection: Equatable {
    let day: DevVlogsPublishDay
    let clips: [DevVlogsPublishClip]
    let outputLocation: String

    var selectedClipCount: Int {
        clips.filter(\.isSelected).count
    }
}

struct DevVlogsPublishBuildProgress: Equatable {
    let completedFraction: Double
    let detail: String

    var boundedFraction: Double {
        min(max(completedFraction, 0), 1)
    }
}

struct DevVlogsPublishArtifact: Equatable {
    let name: String
    let detail: String
    let outputLocation: String
}

enum DevVlogsPublishState: Equatable {
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
        case .completed:
            return [.play, .reveal, .share]
        case .noRecordings, .emptyDay, .selectionUnavailable, .cancelled, .failed:
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
}

struct DevVlogsPublishPresentation: Equatable {
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
