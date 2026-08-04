import Combine
import Foundation
import HoldTypeDomain

enum FixesPaletteSelectionMovement {
    case up
    case down
}

@MainActor
final class FixesPaletteModel: ObservableObject {
    typealias ActionHandler = @MainActor (String) -> Void
    typealias DismissHandler = @MainActor () -> Void
    static let maximumVisibleActionCount = 5

    @Published private(set) var actions: [FixesPaletteActionPresentation]
    @Published private(set) var searchText = ""
    @Published private(set) var selectedActionID: String?
    @Published private(set) var status: FixesPaletteStatus

    private let onActivate: ActionHandler
    private let onDismiss: DismissHandler
    private let recentActionIDs: [String]
    private var didRequestDismissal = false

    init(
        catalog: TextFixCatalog,
        recentActionIDs: [String] = [],
        status: FixesPaletteStatus = .ready,
        onActivate: @escaping ActionHandler,
        onDismiss: @escaping DismissHandler
    ) {
        let actions = catalog.enabledActions.map(FixesPaletteActionPresentation.init)
        self.actions = actions
        self.status = status
        self.onActivate = onActivate
        self.onDismiss = onDismiss
        self.recentActionIDs = recentActionIDs
        selectedActionID = actionsRankedByRecency(actions).first?.id
    }

    var visibleActions: [FixesPaletteActionPresentation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return Array(
                actionsRankedByRecency(actions)
                    .prefix(Self.maximumVisibleActionCount)
            )
        }

        return Array(
            actions
                .filter { titleMatchRank(for: $0, query: query) != nil }
                .sorted { lhs, rhs in
                    let lhsMatchRank = titleMatchRank(for: lhs, query: query) ?? .max
                    let rhsMatchRank = titleMatchRank(for: rhs, query: query) ?? .max
                    if lhsMatchRank != rhsMatchRank {
                        return lhsMatchRank < rhsMatchRank
                    }

                    let lhsRecentRank = recentRank(for: lhs)
                    let rhsRecentRank = recentRank(for: rhs)
                    if lhsRecentRank != rhsRecentRank {
                        return lhsRecentRank < rhsRecentRank
                    }

                    return catalogRank(for: lhs) < catalogRank(for: rhs)
                }
                .prefix(Self.maximumVisibleActionCount)
        )
    }

    var selectedAction: FixesPaletteActionPresentation? {
        guard let selectedActionID else {
            return nil
        }

        return visibleActions.first { $0.id == selectedActionID }
    }

    var statusPresentation: FixesPaletteStatusPresentation? {
        let processingTitle: String?
        if case .processing(let actionID) = status {
            processingTitle = actions.first { $0.id == actionID }?.title
        } else {
            processingTitle = nil
        }

        return status.presentation(actionTitle: processingTitle)
    }

    var canActivateSelection: Bool {
        !didRequestDismissal
            && status.allowsActionActivation
            && selectedAction != nil
    }

    func setSearchText(_ searchText: String) {
        guard !didRequestDismissal else {
            return
        }

        self.searchText = searchText
        reconcileSelection()
    }

    func updateActions(from catalog: TextFixCatalog) {
        actions = catalog.enabledActions.map(FixesPaletteActionPresentation.init)
        reconcileSelection()
    }

    func updateStatus(_ status: FixesPaletteStatus) {
        guard !didRequestDismissal else {
            return
        }

        self.status = status
    }

    func moveSelection(_ movement: FixesPaletteSelectionMovement) {
        guard !didRequestDismissal,
              !visibleActions.isEmpty
        else {
            return
        }

        let currentIndex = selectedActionID.flatMap { selectedActionID in
            visibleActions.firstIndex { $0.id == selectedActionID }
        }
        let nextIndex: Int
        switch movement {
        case .up:
            nextIndex = max((currentIndex ?? 0) - 1, 0)
        case .down:
            nextIndex = min((currentIndex ?? -1) + 1, visibleActions.count - 1)
        }
        selectedActionID = visibleActions[nextIndex].id
    }

    func selectAction(id: String) {
        guard !didRequestDismissal,
              visibleActions.contains(where: { $0.id == id })
        else {
            return
        }

        selectedActionID = id
    }

    func activateSelection() {
        guard canActivateSelection,
              let selectedAction
        else {
            return
        }

        status = .processing(actionID: selectedAction.id)
        onActivate(selectedAction.id)
    }

    func requestDismissal() {
        guard !didRequestDismissal else {
            return
        }

        didRequestDismissal = true
        onDismiss()
    }

    private func reconcileSelection() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            selectedActionID = nil
            return
        }

        let visibleActions = visibleActions
        guard !visibleActions.isEmpty else {
            selectedActionID = nil
            return
        }
        guard let selectedActionID,
              visibleActions.contains(where: { $0.id == selectedActionID })
        else {
            self.selectedActionID = visibleActions.first?.id
            return
        }
    }

    private func actionsRankedByRecency(
        _ actions: [FixesPaletteActionPresentation]
    ) -> [FixesPaletteActionPresentation] {
        actions.sorted { lhs, rhs in
            let lhsRecentRank = recentRank(for: lhs)
            let rhsRecentRank = recentRank(for: rhs)
            if lhsRecentRank != rhsRecentRank {
                return lhsRecentRank < rhsRecentRank
            }
            return catalogRank(for: lhs) < catalogRank(for: rhs)
        }
    }

    private func titleMatchRank(
        for action: FixesPaletteActionPresentation,
        query: String
    ) -> Int? {
        let options: String.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
        ]
        if action.title.compare(query, options: options) == .orderedSame {
            return 0
        }
        if action.title.range(
            of: query,
            options: options.union(.anchored)
        ) != nil {
            return 1
        }
        if action.title.range(of: query, options: options) != nil {
            return 2
        }
        return nil
    }

    private func recentRank(for action: FixesPaletteActionPresentation) -> Int {
        recentActionIDs.firstIndex(of: action.id) ?? .max
    }

    private func catalogRank(for action: FixesPaletteActionPresentation) -> Int {
        actions.firstIndex(where: { $0.id == action.id }) ?? .max
    }
}
