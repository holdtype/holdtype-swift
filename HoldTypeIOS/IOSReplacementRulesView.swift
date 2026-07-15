import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSReplacementRulesView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner
    @Environment(IOSAppSettingsStateOwner.self) private var settingsStateOwner

    @State private var searchQuery = IOSLibrarySearchQuery()
    @State private var notice: IOSReplacementRulesNotice?
    @State private var pendingDelete: IOSReplacementRuleReference?
    @State private var showsDeleteConfirmation = false
    @State private var operationInFlight = false
    @State private var isLoading = false
    @State private var newRuleID = UUID()
    @State private var editMode = EditMode.inactive
    @State private var pendingOrder: IOSReplacementRulesPendingOrder?
    @State private var automaticCleanupIsLoading = false
    @State private var automaticCleanupIsSaving = false
    @State private var automaticCleanupSaveFailed = false
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
                IOSDestinationLoadingView(title: "Loading Replacements")
            case .loadFailed:
                IOSDestinationLoadFailureView(
                    title: "Replacements Unavailable",
                    description:
                        "HoldType couldn’t read your saved rules. No empty "
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
        .navigationTitle("Replacements")
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
        .task {
            await loadAutomaticCleanupIfNeeded()
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
                IOSSaveFailureSection(subject: "Dictation Rules")
            }

            if let notice {
                IOSReplacementRulesNoticeSection(notice: notice)
            }

            automaticCleanupSection

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
            .disabled(operationInFlight)

            Section("Custom Replacements") {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.title)
                            .foregroundStyle(.secondary)

                        Text("No Custom Replacements")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(
                            "Automatic cleanup can still run. Add a literal "
                                + "rule for your own words or phrases."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
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
            .disabled(operationInFlight)

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
                    "Automatic cleanup runs first. Emoji commands run next. "
                        + "Custom replacements then run locally, in order. "
                        + "Matching is literal and case-insensitive. Nothing "
                        + "is copied into the keyboard."
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
        .onChange(of: rules.map(\.id), initial: true) { _, identifiers in
            if identifiers.contains(newRuleID) {
                newRuleID = UUID()
            }
        }
    }

    @ViewBuilder
    private var automaticCleanupSection: some View {
        Section("Automatic Cleanup") {
            switch settingsStateOwner.state {
            case .notLoaded:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading automatic cleanup")
                        .foregroundStyle(.secondary)
                }
            case .loadFailed:
                Label(
                    "Automatic cleanup is unavailable",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)

                Button("Retry Automatic Cleanup") {
                    retryAutomaticCleanupLoad()
                }
                .disabled(automaticCleanupIsLoading)
            case .ready(let settings):
                automaticCleanupControls(settings: settings)
            case .saveFailed(let lastDurableValue):
                automaticCleanupControls(settings: lastDurableValue)
            }
        }
    }

    @ViewBuilder
    private func automaticCleanupControls(
        settings: IOSAppSettings
    ) -> some View {
        Toggle(
            "Use Plain Typography Cleanup",
            isOn: Binding(
                get: {
                    currentAutomaticCleanupEnabled
                        ?? settings.localTextCleanupEnabled
                },
                set: { beginAutomaticCleanupUpdate($0) }
            )
        )
        .disabled(automaticCleanupIsSaving)
        .accessibilityIdentifier(
            "ios.library.replacement-rules.automatic-cleanup.toggle"
        )

        if automaticCleanupIsSaving {
            HStack(spacing: 10) {
                ProgressView()
                Text("Saving automatic cleanup")
                    .foregroundStyle(.secondary)
            }
        } else if automaticCleanupSaveFailed {
            Label(
                "Automatic cleanup was not saved. The saved setting is shown.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Text("On by default. Runs locally without another OpenAI request.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        DisclosureGroup("What Automatic Cleanup Changes") {
            ForEach(
                IOSAutomaticCleanupPresentation.transformationDescriptions,
                id: \.self
            ) { description in
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(
            "ios.library.replacement-rules.automatic-cleanup.details"
        )
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

    private var currentAutomaticCleanupEnabled: Bool? {
        settingsStateOwner.state.durableValue?.localTextCleanupEnabled
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

    private func beginAutomaticCleanupUpdate(_ requested: Bool) {
        guard currentAutomaticCleanupEnabled != requested,
              !automaticCleanupIsSaving else {
            return
        }
        automaticCleanupIsSaving = true
        automaticCleanupSaveFailed = false

        Task {
            defer { automaticCleanupIsSaving = false }
            do {
                let state = try await settingsStateOwner.update {
                    IOSAppSettingsEditorMutation.setLocalTextCleanupEnabled(
                        requested,
                        in: &$0
                    )
                }
                guard state.durableValue?.localTextCleanupEnabled == requested
                else {
                    automaticCleanupUpdateFailed()
                    return
                }
                iosAnnounceSettingsStatus(
                    requested
                        ? "Automatic cleanup enabled."
                        : "Automatic cleanup disabled."
                )
            } catch {
                automaticCleanupUpdateFailed()
            }
        }
    }

    private func automaticCleanupUpdateFailed() {
        automaticCleanupSaveFailed = true
        iosAnnounceSettingsStatus("Automatic cleanup was not saved.")
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

    private func loadAutomaticCleanupIfNeeded() async {
        guard case .notLoaded = settingsStateOwner.state else { return }
        await loadAutomaticCleanup()
    }

    private func retryAutomaticCleanupLoad() {
        Task { await loadAutomaticCleanup() }
    }

    private func loadAutomaticCleanup() async {
        guard !automaticCleanupIsLoading else { return }
        automaticCleanupIsLoading = true
        defer { automaticCleanupIsLoading = false }
        _ = try? await settingsStateOwner.load()
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
