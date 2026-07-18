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
    @State private var newRuleID: UUID
    @State private var editMode = EditMode.inactive
    @State private var pendingOrder: IOSReplacementRulesPendingOrder?
    @State private var automaticCleanupIsLoading = false
    @State private var automaticCleanupIsSaving = false
    @State private var automaticCleanupSaveFailed = false
    @Binding private var hasBlockingSceneOperation: Bool

    init(
        hasBlockingSceneOperation: Binding<Bool> = .constant(false),
        initialNewRuleID: UUID = UUID()
    ) {
        _hasBlockingSceneOperation = hasBlockingSceneOperation
        _newRuleID = State(initialValue: initialNewRuleID)
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
        let rows = IOSReplacementRuleRowModel.makeRows(from: displayedRules)
        let visibleRows = IOSReplacementRuleRowModel.filter(
            rows,
            normalizedQuery: normalizedSearchQuery
        )

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
                        IOSReplacementRuleListRow(
                            row: row,
                            operationInFlight: operationInFlight,
                            allowsReordering: canOfferReorder,
                            onSetEnabled: beginToggle,
                            onRequestDelete: requestDelete,
                            onMove: beginAccessibleMove
                        )
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

    private var automaticCleanupSection: some View {
        IOSReplacementRulesAutomaticCleanupSection(
            state: settingsStateOwner.state,
            isLoading: automaticCleanupIsLoading,
            isSaving: automaticCleanupIsSaving,
            saveFailed: automaticCleanupSaveFailed,
            retryLoad: retryAutomaticCleanupLoad,
            setEnabled: beginAutomaticCleanupUpdate
        )
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

extension IOSReplacementRulesView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Replacement rules") {
    let previewRuleID = UUID(
        uuid: (0x20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
    )
    let libraryStateOwner = IOSLibraryStateOwner(
        load: { .defaults },
        commit: { $0 }
    )
    let settingsStateOwner = IOSAppSettingsStateOwner(
        load: { .defaults },
        commit: { $0 }
    )

    NavigationStack {
        IOSReplacementRulesView(initialNewRuleID: previewRuleID)
    }
    .environment(libraryStateOwner)
    .environment(settingsStateOwner)
}
