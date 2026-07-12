import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSReplacementRulesView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner

    @State private var searchQuery = IOSLibrarySearchQuery()
    @State private var notice: IOSReplacementRulesNotice?
    @State private var pendingDelete: IOSReplacementRuleReference?
    @State private var showsDeleteConfirmation = false
    @State private var operationInFlight = false
    @State private var isLoading = false
    @State private var newRuleID = UUID()
    @State private var editMode = EditMode.inactive
    @State private var pendingOrder: IOSReplacementRulesPendingOrder?
    @Binding private var hasBlockingSceneOperation: Bool

    init(
        hasBlockingSceneOperation: Binding<Bool> = .constant(false)
    ) {
        _hasBlockingSceneOperation = hasBlockingSceneOperation
    }

    var body: some View {
        Group {
            switch stateOwner.state {
            case .notLoaded:
                IOSDestinationLoadingView(title: "Loading Replacement Rules")
            case .loadFailed:
                IOSDestinationLoadFailureView(
                    title: "Replacement Rules Unavailable",
                    description:
                        "HoldType couldn’t read your Library. No empty "
                        + "replacement was created.",
                    isRetrying: isLoading,
                    retry: retryLoad
                )
            case .ready(let content):
                rulesList(
                    rules: content.replacementRules,
                    showsSharedSaveFailure: false
                )
            case .saveFailed(let lastDurableValue):
                rulesList(
                    rules: lastDurableValue.replacementRules,
                    showsSharedSaveFailure: true
                )
            }
        }
        .navigationTitle("Replacement Rules")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            operationInFlight && hasBlockingSceneOperation
        )
        .toolbar {
            if canOfferReorder || editMode == .active {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        .disabled(operationInFlight)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .confirmationDialog(
            "Delete Replacement Rule?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Rule", role: .destructive) {
                guard let pendingDelete else { return }
                self.pendingDelete = nil
                beginDelete(pendingDelete)
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes one saved replacement rule.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if notice == .notSaved {
                IOSLibraryPersistentFailureStatus()
            }
        }
        .onChange(of: isFiltering, initial: true) { _, filtering in
            if filtering {
                editMode = .inactive
            }
        }
        .onChange(of: canOfferReorder, initial: true) { _, canReorder in
            if !canReorder {
                editMode = .inactive
            }
        }
        .onDisappear {
            if !operationInFlight {
                hasBlockingSceneOperation = false
            }
        }
        .accessibilityIdentifier("ios.library.replacement-rules.screen")
    }

    private func rulesList(
        rules: [TextReplacementRule],
        showsSharedSaveFailure: Bool
    ) -> some View {
        let displayedRules = pendingOrder?.orderedRules(from: rules) ?? rules
        let rows = rowModels(displayedRules)
        let visibleRows = filteredRows(rows)

        return List {
            if showsSharedSaveFailure, notice != .notSaved {
                IOSSaveFailureSection(subject: "Library")
            }

            if let notice {
                IOSReplacementRulesNoticeSection(notice: notice)
            }

            Section("Add") {
                NavigationLink(
                    value: IOSLibraryRoute.newReplacementRule(newRuleID)
                ) {
                    Label("Add Replacement Rule", systemImage: "plus")
                }
                .accessibilityIdentifier(
                    "ios.library.replacement-rules.add.row"
                )
            }

            Section("Rules") {
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No Replacement Rules",
                            systemImage: "arrow.left.arrow.right"
                        )
                    } description: {
                        Text(
                            "Add a literal rule to change recognized text "
                                + "locally."
                        )
                    }
                } else if visibleRows.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No Matching Rules",
                            systemImage: "magnifyingglass"
                        )
                    } description: {
                        Text("Clear search to show saved rules.")
                    }
                } else {
                    ForEach(visibleRows) { row in
                        replacementRuleRow(row)
                            .moveDisabled(!canOfferReorder)
                    }
                    .onMove(perform: beginReorder)
                }
            }

            if isFiltering, rules.count > 1 {
                Section {
                    Label(
                        "Clear search to reorder rules.",
                        systemImage: "line.3.horizontal"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(
                    "Rules run locally, in order, after voice emoji "
                        + "commands. Matching is literal and case-insensitive. "
                        + "Rules never enter the keyboard extension or App "
                        + "Group."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .searchable(
            text: $searchQuery.text,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search Replacement Rules"
        )
        .scrollDismissesKeyboard(.interactively)
        .disabled(operationInFlight)
        .onChange(of: rules.map(\.id), initial: true) { _, identifiers in
            if identifiers.contains(newRuleID) {
                newRuleID = UUID()
            }
        }
    }

    @ViewBuilder
    private func replacementRuleRow(
        _ row: IOSReplacementRuleRowModel
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(
                "Enable Rule",
                isOn: Binding(
                    get: { row.rule.isEnabled },
                    set: {
                        beginToggle(row.rule, requested: $0)
                    }
                )
            )
            .labelsHidden()
            .accessibilityLabel(toggleAccessibilityLabel(row.rule))
            .disabled(operationInFlight)

            NavigationLink(
                value: IOSLibraryRoute.replacementRule(row.rule.id)
            ) {
                IOSReplacementRuleRow(row: row)
            }
            .accessibilityActions {
                Button("Delete Rule") {
                    requestDelete(row.rule)
                }
                if canOfferReorder, row.position > 0 {
                    Button("Move Up") {
                        beginAccessibleMove(row.rule.id, direction: .up)
                    }
                }
                if canOfferReorder, row.position + 1 < row.totalCount {
                    Button("Move Down") {
                        beginAccessibleMove(row.rule.id, direction: .down)
                    }
                }
            }
            .accessibilityIdentifier(
                "ios.library.replacement-rules.rule."
                    + row.rule.id.uuidString.lowercased()
            )
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                requestDelete(row.rule)
            }
        }
        .contextMenu {
            Button("Delete Rule", role: .destructive) {
                requestDelete(row.rule)
            }
        }
    }

    private func rowModels(
        _ rules: [TextReplacementRule]
    ) -> [IOSReplacementRuleRowModel] {
        rules.enumerated().map { index, rule in
            IOSReplacementRuleRowModel(
                rule: rule,
                position: index,
                totalCount: rules.count
            )
        }
    }

    private func filteredRows(
        _ rows: [IOSReplacementRuleRowModel]
    ) -> [IOSReplacementRuleRowModel] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            row.rule.search.localizedStandardContains(query)
                || row.rule.replacement.localizedStandardContains(query)
        }
    }

    private var normalizedSearchQuery: String {
        searchQuery.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var currentRules: [TextReplacementRule] {
        stateOwner.state.durableValue?.replacementRules ?? []
    }

    private var canOfferReorder: Bool {
        !isFiltering && currentRules.count > 1
    }

    private func toggleAccessibilityLabel(
        _ rule: TextReplacementRule
    ) -> String {
        rule.hasSearchText
            ? "Enable rule for \(rule.search)"
            : "Enabled preference for rule with empty Search"
    }

    private func beginToggle(
        _ rule: TextReplacementRule,
        requested: Bool
    ) {
        guard rule.isEnabled != requested else { return }
        beginMutation(
            .replacementRules(
                .setEnabled(
                    id: rule.id,
                    expected: rule.isEnabled,
                    requested: requested
                )
            ),
            successNotice: .saved,
            successAnnouncement: "Replacement rule updated."
        )
    }

    private func requestDelete(_ rule: TextReplacementRule) {
        guard !operationInFlight else { return }
        pendingDelete = IOSReplacementRuleReference(expected: rule)
        showsDeleteConfirmation = true
    }

    private func beginDelete(_ reference: IOSReplacementRuleReference) {
        beginMutation(
            .replacementRules(.remove(expected: reference.expected)),
            successNotice: .deleted,
            successAnnouncement: "Replacement rule deleted.",
            blocksDestinationSwitching: true
        )
    }

    private func beginReorder(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int
    ) {
        guard !isFiltering,
              let request = IOSReplacementRulesOrderRequest(
                expected: currentRules.map(\.id),
                moving: offsets,
                to: destination
              ) else {
            return
        }
        beginReorder(request, announcement: "Rule order updated.")
    }

    private func beginAccessibleMove(
        _ id: UUID,
        direction: IOSReplacementRulesMoveDirection
    ) {
        guard !isFiltering,
              let request = IOSReplacementRulesOrderRequest(
                expected: currentRules.map(\.id),
                moving: id,
                direction: direction
              ) else {
            return
        }
        let announcement = direction == .up
            ? "Rule moved up."
            : "Rule moved down."
        beginReorder(request, announcement: announcement)
    }

    private func beginReorder(
        _ request: IOSReplacementRulesOrderRequest,
        announcement: String
    ) {
        guard request.expected != request.requested else { return }
        beginMutation(
            request.mutation,
            successNotice: .reordered,
            successAnnouncement: announcement,
            optimisticOrder: IOSReplacementRulesPendingOrder(request: request)
        )
    }

    private func beginMutation(
        _ mutation: IOSLibraryMutation,
        successNotice: IOSReplacementRulesNotice,
        successAnnouncement: String,
        blocksDestinationSwitching: Bool = false,
        optimisticOrder: IOSReplacementRulesPendingOrder? = nil
    ) {
        guard !operationInFlight else { return }
        operationInFlight = true
        editMode = .inactive
        pendingOrder = optimisticOrder
        if blocksDestinationSwitching {
            hasBlockingSceneOperation = true
        }

        Task {
            defer {
                operationInFlight = false
                pendingOrder = nil
                if blocksDestinationSwitching {
                    hasBlockingSceneOperation = false
                }
            }
            do {
                let completion = try await stateOwner.apply(mutation)
                switch completion.receipt.disposition {
                case .committed, .unchanged:
                    notice = successNotice
                    iosAnnounceSettingsStatus(successAnnouncement)
                case .targetMissing, .conflict:
                    notice = .changedElsewhere
                    iosAnnounceSettingsStatus(
                        "Saved replacement rules changed elsewhere."
                    )
                case .duplicate, .invalid:
                    notice = .invalid
                    iosAnnounceSettingsStatus(
                        "The replacement rule change was invalid."
                    )
                }
            } catch {
                notice = .notSaved
                iosAnnounceSettingsStatus(
                    "Replacement rules were not saved."
                )
            }
        }
    }

    private func retryLoad() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            _ = try? await stateOwner.load()
        }
    }
}

struct IOSReplacementRuleRowModel: Identifiable, Equatable {
    let rule: TextReplacementRule
    let position: Int
    let totalCount: Int

    var id: UUID { rule.id }
}

private struct IOSReplacementRuleRow: View {
    let row: IOSReplacementRuleRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            searchLabel
            replacementLabel
            HStack(spacing: 4) {
                Image(systemName: status.systemImage)
                    .foregroundStyle(statusColor)
                Text(status.title)
                    .foregroundStyle(.primary)
            }
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            "Position \(row.position + 1) of \(row.totalCount)"
        )
    }

    @ViewBuilder
    private var searchLabel: some View {
        if row.rule.hasSearchText {
            Text(row.rule.search)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        } else {
            Label(
                "Empty Search",
                systemImage: "text.badge.xmark"
            )
            .font(.body.weight(.medium))
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var replacementLabel: some View {
        if row.rule.replacement.isEmpty {
            Text("Removes matching text")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if replacementContainsOnlyWhitespace {
            Text("Replacement contains only whitespace")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Replace with: \(row.rule.replacement)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var status: IOSReplacementRuleRuntimeStatus {
        IOSReplacementRuleRuntimeStatus(rule: row.rule)
    }

    private var statusColor: Color {
        switch status {
        case .active: .green
        case .off: .secondary
        case .inactiveEmptySearch: .orange
        }
    }

    private var replacementContainsOnlyWhitespace: Bool {
        !row.rule.replacement.isEmpty
            && row.rule.replacement.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
    }

    private var accessibilityLabel: String {
        let search = row.rule.hasSearchText
            ? row.rule.search
            : "Empty search"
        let replacement: String
        if row.rule.replacement.isEmpty {
            replacement = "removes matching text"
        } else if replacementContainsOnlyWhitespace {
            replacement = "replacement contains only whitespace"
        } else {
            replacement = "replace with \(row.rule.replacement)"
        }
        return "\(search), \(replacement), \(status.title)"
    }
}

private struct IOSReplacementRulesNoticeSection: View {
    let notice: IOSReplacementRulesNotice

    var body: some View {
        Section {
            switch notice {
            case .saved:
                Label(
                    "Replacement Rule Updated",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            case .deleted:
                Label("Replacement Rule Deleted", systemImage: "trash")
            case .reordered:
                Label(
                    "Rule Order Updated",
                    systemImage: "line.3.horizontal"
                )
            case .changedElsewhere:
                IOSSettingsWarningLabel(
                    "Saved rules changed elsewhere. The latest order and rows are shown.",
                    color: .orange
                )
            case .invalid:
                IOSSettingsWarningLabel(
                    "The replacement rule change was invalid.",
                    color: .orange
                )
            case .notSaved:
                IOSSettingsWarningLabel(
                    "Replacement rules were not saved. Saved rules remain unchanged.",
                    color: .red
                )
            }
        }
    }
}

extension IOSReplacementRulesView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSReplacementRuleRowModel: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSReplacementRuleRow: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
