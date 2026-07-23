import Combine
import Foundation
import HoldTypeDomain

@MainActor
final class FixesEditorModel: ObservableObject {
    typealias IdentifierGenerator = @MainActor () -> String

    @Published private(set) var catalog: TextFixCatalog?
    @Published private(set) var activity: FixesEditorActivity = .idle
    @Published private(set) var issue: FixesEditorIssue?
    @Published private(set) var selectedActionID: String?
    @Published private(set) var searchText = ""
    @Published private var drafts: [String: FixesEditorDraft] = [:]
    @Published private var pendingActionIDs: [String] = []

    private let store: any MacOSTextFixCatalogStoring
    private let identifierGenerator: IdentifierGenerator

    init(
        store: any MacOSTextFixCatalogStoring,
        identifierGenerator: @escaping IdentifierGenerator = {
            "custom.\(UUID().uuidString.lowercased())"
        },
        preloadedCatalog: TextFixCatalog? = nil
    ) {
        self.store = store
        self.identifierGenerator = identifierGenerator
        catalog = preloadedCatalog
        selectedActionID = preloadedCatalog?.actions.first?.id
    }

    var visibleActions: [FixesEditorActionPresentation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return allActionPresentations
        }

        return allActionPresentations.filter { presentation in
            guard let searchableText = searchableText(for: presentation.id) else {
                return false
            }
            return searchableText.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    var selectedAction: TextFixAction? {
        guard let selectedActionID else {
            return nil
        }
        return catalog?.action(id: selectedActionID)
    }

    var selectedDraft: FixesEditorDraft? {
        guard let selectedActionID else {
            return nil
        }
        return drafts[selectedActionID]
    }

    var selectedBuiltIn: FixesEditorBuiltInPresentation? {
        guard let selectedAction else {
            return nil
        }
        return FixesEditorBuiltInPresentation(action: selectedAction)
    }

    var selectedDraftValidation: FixesEditorDraftValidation? {
        selectedDraft?.validation
    }

    var selectedDraftHasChanges: Bool {
        guard let draft = selectedDraft else {
            return false
        }
        return draft.differs(from: catalog?.action(id: draft.id))
    }

    var canAddFix: Bool {
        guard let catalog, !activity.isBusy else {
            return false
        }
        return catalog.actions.count + pendingActionIDs.count
            < TextFixCatalog.maximumActionCount
    }

    var canSaveSelectedDraft: Bool {
        guard !activity.isBusy,
              catalog != nil,
              let draft = selectedDraft,
              draft.validation.isValid
        else {
            return false
        }
        return draft.differs(from: catalog?.action(id: draft.id))
    }

    var canDeleteSelection: Bool {
        guard !activity.isBusy,
              let selectedActionID
        else {
            return false
        }
        if pendingActionIDs.contains(selectedActionID) {
            return true
        }
        return catalog?.action(id: selectedActionID)?.kind == .customPrompt
    }

    var canMoveSelectionUp: Bool {
        selectedCustomIndex.map { $0 > 0 } == true && !activity.isBusy
    }

    var canMoveSelectionDown: Bool {
        guard let catalog,
              let selectedCustomIndex
        else {
            return false
        }
        return selectedCustomIndex < catalog.customActions.count - 1
            && !activity.isBusy
    }

    var canRestoreDefaults: Bool {
        guard let catalog, !activity.isBusy else {
            return false
        }
        let existingIDs = Set(catalog.actions.map(\.id))
        return TextFixCatalog.defaults.customActions.contains {
            !existingIDs.contains($0.id)
        }
    }

    func loadIfNeeded() async {
        guard catalog == nil, activity == .idle else {
            return
        }
        await load()
    }

    func retryLoad() async {
        guard activity == .idle else {
            return
        }
        await load()
    }

    func setSearchText(_ searchText: String) {
        self.searchText = searchText
        reconcileSelectionWithVisibleActions()
    }

    func selectAction(id: String?) {
        guard let id else {
            selectedActionID = nil
            return
        }
        guard allActionPresentations.contains(where: { $0.id == id }) else {
            return
        }

        selectedActionID = id
        if let action = catalog?.action(id: id),
           action.kind == .customPrompt,
           drafts[id] == nil {
            drafts[id] = FixesEditorDraft(action: action)
        }
    }

    func addFix() {
        guard canAddFix,
              let id = makeAvailableIdentifier()
        else {
            if canAddFix {
                issue = .validation(
                    "HoldType couldn’t create a unique identifier for the new Fix."
                )
            }
            return
        }

        drafts[id] = FixesEditorDraft(id: id)
        pendingActionIDs.append(id)
        searchText = ""
        selectedActionID = id
        issue = nil
    }

    func setSelectedTitle(_ title: String) {
        mutateSelectedDraft { $0.title = title }
    }

    func setSelectedPrompt(_ prompt: String) {
        mutateSelectedDraft { $0.prompt = prompt }
    }

    func setSelectedIcon(_ icon: TextFixIcon) {
        mutateSelectedDraft { $0.icon = icon }
    }

    func setSelectedEnabled(_ isEnabled: Bool) {
        mutateSelectedDraft { $0.isEnabled = isEnabled }
    }

    func dismissIssue() {
        issue = nil
    }

    func saveSelectedDraft() async {
        guard let catalog,
              let draft = selectedDraft
        else {
            return
        }
        guard draft.validation.isValid else {
            issue = .validation(
                draft.validation.titleMessage
                    ?? draft.validation.promptMessage
                    ?? "Review the Fix fields and try again."
            )
            return
        }

        do {
            let action = try draft.makeAction()
            let candidate: TextFixCatalog
            if catalog.action(id: action.id) == nil {
                candidate = try catalog.addingCustomAction(action)
            } else {
                candidate = try catalog.replacingCustomAction(action)
            }
            guard let saved = await persist(candidate, activity: .saving),
                  let savedAction = saved.action(id: action.id)
            else {
                return
            }

            drafts[action.id] = FixesEditorDraft(action: savedAction)
            pendingActionIDs.removeAll { $0 == action.id }
            selectedActionID = action.id
        } catch {
            issue = .validation("Review the title and prompt, then try again.")
        }
    }

    func deleteSelection() async {
        guard let selectedActionID,
              canDeleteSelection
        else {
            return
        }
        if pendingActionIDs.contains(selectedActionID) {
            pendingActionIDs.removeAll { $0 == selectedActionID }
            drafts[selectedActionID] = nil
            selectFirstAvailableAction()
            return
        }
        guard let catalog else {
            return
        }

        do {
            let candidate = try catalog.deletingCustomAction(id: selectedActionID)
            guard let saved = await persist(candidate, activity: .deleting) else {
                return
            }
            drafts[selectedActionID] = nil
            self.selectedActionID = saved.actions.first?.id
        } catch {
            issue = .validation("This Fix cannot be deleted.")
        }
    }

    func moveSelectionUp() async {
        guard let selectedCustomIndex else {
            return
        }
        await moveSelection(toCustomIndex: selectedCustomIndex - 1)
    }

    func moveSelectionDown() async {
        guard let selectedCustomIndex else {
            return
        }
        await moveSelection(toCustomIndex: selectedCustomIndex + 1)
    }

    func restoreDefaults() async {
        guard let catalog, canRestoreDefaults else {
            return
        }
        do {
            let candidate = try catalog.restoringDefaults()
            _ = await persist(candidate, activity: .restoringDefaults)
        } catch {
            issue = .validation("There is no room to restore the missing default Fixes.")
        }
    }

    private var allActionPresentations: [FixesEditorActionPresentation] {
        let saved = (catalog?.actions ?? []).map { action in
            if let draft = drafts[action.id] {
                return FixesEditorActionPresentation(draft: draft)
            }
            return FixesEditorActionPresentation(action: action)
        }
        let pending = pendingActionIDs.compactMap { drafts[$0] }
            .map(FixesEditorActionPresentation.init)
        return saved + pending
    }

    private var selectedCustomIndex: Int? {
        guard let selectedActionID else {
            return nil
        }
        return catalog?.customActions.firstIndex { $0.id == selectedActionID }
    }

    private func load() async {
        activity = .loading
        issue = nil
        do {
            let loaded = try await store.load()
            catalog = loaded
            drafts = [:]
            pendingActionIDs = []
            selectedActionID = loaded.actions.first?.id
        } catch {
            catalog = nil
            drafts = [:]
            pendingActionIDs = []
            selectedActionID = nil
            issue = .loading(error)
        }
        activity = .idle
    }

    private func persist(
        _ candidate: TextFixCatalog,
        activity: FixesEditorActivity
    ) async -> TextFixCatalog? {
        guard catalog != nil, self.activity == .idle else {
            return nil
        }

        self.activity = activity
        issue = nil
        defer { self.activity = .idle }
        do {
            let saved = try await store.save(candidate)
            catalog = saved
            return saved
        } catch {
            issue = .saving(error)
            return nil
        }
    }

    private func moveSelection(toCustomIndex destinationIndex: Int) async {
        guard let catalog,
              let selectedActionID,
              !activity.isBusy
        else {
            return
        }
        do {
            let candidate = try catalog.movingCustomAction(
                id: selectedActionID,
                toCustomIndex: destinationIndex
            )
            _ = await persist(candidate, activity: .reordering)
        } catch {
            issue = .validation("This Fix cannot be moved there.")
        }
    }

    private func mutateSelectedDraft(_ mutation: (inout FixesEditorDraft) -> Void) {
        guard let selectedActionID,
              var draft = drafts[selectedActionID],
              !activity.isBusy
        else {
            return
        }
        mutation(&draft)
        drafts[selectedActionID] = draft
    }

    private func makeAvailableIdentifier() -> String? {
        let existingIDs = Set(
            (catalog?.actions.map(\.id) ?? []) + pendingActionIDs
        )
        for _ in 0..<8 {
            let candidate = identifierGenerator()
            guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  candidate.utf8.count <= TextFixAction.maximumIdentifierUTF8ByteCount,
                  candidate != TextFixAction.translateIdentifier,
                  candidate != TextFixAction.fixIdentifier
            else {
                continue
            }
            if !existingIDs.contains(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func searchableText(for id: String) -> String? {
        if let draft = drafts[id] {
            return "\(draft.title)\n\(draft.prompt)"
        }
        guard let action = catalog?.action(id: id) else {
            return nil
        }
        return "\(action.title)\n\(action.prompt ?? "")"
    }

    private func reconcileSelectionWithVisibleActions() {
        guard !visibleActions.isEmpty else {
            selectedActionID = nil
            return
        }
        guard let selectedActionID,
              visibleActions.contains(where: { $0.id == selectedActionID })
        else {
            selectAction(id: visibleActions.first?.id)
            return
        }
    }

    private func selectFirstAvailableAction() {
        selectedActionID = allActionPresentations.first?.id
    }
}
