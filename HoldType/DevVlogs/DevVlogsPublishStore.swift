import Combine
import Foundation

@MainActor
final class DevVlogsPublishStore: ObservableObject {
    @Published private(set) var presentation: DevVlogsPublishPresentation = .releaseEmpty
    @Published private(set) var selectedDayID: String?

    private let destinationAccessProvider: () throws -> DevVlogsCaptureDestinationAccess
    private let recipeRepository: DevVlogsBuildRepository
    private let mediaBuilder: any DevVlogsMediaBuilding
    private let ownershipRegistry: DevVlogsClipOwnershipRegistry
    private let now: () -> Date
    private let buildIDProvider: () -> UUID

    private var days: [DevVlogsLibraryDay] = []
    private var orderedClipIDs: [UUID] = []
    private var selectedClipIDs: Set<UUID> = []
    private var recipe: DevVlogsBuildRecipe?
    private var workspace: DevVlogsBuildWorkspace?
    private var buildTask: Task<Void, Never>?

    convenience init(destinationStore: DevVlogsDestinationSetupStore) {
        self.init(
            destinationAccessProvider: { try destinationStore.acquireCaptureDestination() }
        )
    }

    convenience init(
        destinationAccessProvider: @escaping () throws -> DevVlogsCaptureDestinationAccess
    ) {
        self.init(
            destinationAccessProvider: destinationAccessProvider,
            recipeRepository: DevVlogsBuildRepository(),
            mediaBuilder: AVFoundationDevVlogsMediaBuilder(),
            ownershipRegistry: .shared,
            now: Date.init,
            buildIDProvider: UUID.init
        )
    }

    init(
        destinationAccessProvider: @escaping () throws -> DevVlogsCaptureDestinationAccess,
        recipeRepository: DevVlogsBuildRepository,
        mediaBuilder: any DevVlogsMediaBuilding,
        ownershipRegistry: DevVlogsClipOwnershipRegistry,
        now: @escaping () -> Date,
        buildIDProvider: @escaping () -> UUID
    ) {
        self.destinationAccessProvider = destinationAccessProvider
        self.recipeRepository = recipeRepository
        self.mediaBuilder = mediaBuilder
        self.ownershipRegistry = ownershipRegistry
        self.now = now
        self.buildIDProvider = buildIDProvider
    }

    var availableDays: [DevVlogsPublishDay] {
        days.map(presentationDay)
    }

    func synchronize(days newDays: [DevVlogsLibraryDay]) {
        days = newDays
        guard buildTask == nil else { return }
        guard let selectedDay = newDays.first(where: { $0.id == selectedDayID }) ?? newDays.first else {
            selectedDayID = nil
            orderedClipIDs = []
            selectedClipIDs = []
            presentation = .releaseEmpty
            return
        }
        if selectedDayID != selectedDay.id {
            selectDay(selectedDay)
        } else {
            let availableIDs = Set(selectedDay.clips.compactMap(\.clipID))
            orderedClipIDs = orderedClipIDs.filter(availableIDs.contains)
            selectedClipIDs.formIntersection(availableIDs)
            appendNewClips(from: selectedDay)
            updateReadyPresentation()
        }
    }

    func selectDay(id: String) {
        guard buildTask == nil, let day = days.first(where: { $0.id == id }) else { return }
        selectDay(day)
    }

    func setIncluded(_ isIncluded: Bool, clipID: UUID) {
        guard buildTask == nil else { return }
        if isIncluded {
            selectedClipIDs.insert(clipID)
        } else {
            selectedClipIDs.remove(clipID)
        }
        updateReadyPresentation()
    }

    func move(clipID: UUID, direction: Int) {
        guard buildTask == nil,
              let index = orderedClipIDs.firstIndex(of: clipID) else { return }
        let destination = index + direction
        guard orderedClipIDs.indices.contains(destination) else { return }
        orderedClipIDs.swapAt(index, destination)
        updateReadyPresentation()
    }

    func createVideo() {
        guard buildTask == nil else { return }
        buildTask = Task { @MainActor [weak self] in
            await self?.runNewBuild()
            self?.buildTask = nil
        }
    }

    func retry() {
        guard buildTask == nil, recipe != nil, workspace != nil else { return }
        buildTask = Task { @MainActor [weak self] in
            await self?.runRetry()
            self?.buildTask = nil
        }
    }

    func cancel() {
        buildTask?.cancel()
    }

    private func selectDay(_ day: DevVlogsLibraryDay) {
        selectedDayID = day.id
        orderedClipIDs = uniqueClipIDs(in: day)
        selectedClipIDs = Set(
            uniqueClips(in: day)
                .filter { $0.isBuildEligible && !$0.isExcluded }
                .compactMap(\.clipID)
        )
        recipe = nil
        workspace = nil
        updateReadyPresentation()
    }

    private func appendNewClips(from day: DevVlogsLibraryDay) {
        let existing = Set(orderedClipIDs)
        for clip in uniqueClips(in: day)
        where clip.clipID.map({ !existing.contains($0) }) == true {
            guard let clipID = clip.clipID else { continue }
            orderedClipIDs.append(clipID)
            if clip.isBuildEligible && !clip.isExcluded {
                selectedClipIDs.insert(clipID)
            }
        }
    }

    private func runNewBuild() async {
        guard let day = selectedLibraryDay else { return }
        let selectedIDs = orderedClipIDs.filter(selectedClipIDs.contains)
        guard !selectedIDs.isEmpty else {
            updateReadyPresentation()
            return
        }

        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            let created = try await recipeRepository.createRecipe(
                rootURL: access.url,
                day: day,
                orderedClipIDs: selectedIDs,
                buildID: buildIDProvider(),
                createdAt: now()
            )
            recipe = created.recipe
            workspace = created.workspace
            try await render(
                recipe: created.recipe,
                workspace: created.workspace,
                day: day
            )
        } catch {
            await finishFailure(error)
        }
    }

    private func runRetry() async {
        guard let recipe, let workspace, let day = days.first(where: { $0.id == recipe.dayKey }) else {
            return
        }
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            if let outputURL = try await recipeRepository.completedOutputURL(workspace: workspace) {
                let existing = try await mediaBuilder.validateOutput(at: outputURL)
                try await complete(existing, recipe: recipe, workspace: workspace, day: day)
                return
            }
            self.recipe = try await recipeRepository.update(
                recipe,
                lifecycle: .building,
                failureCategory: nil,
                outputFileName: nil,
                workspace: workspace
            )
            try await recipeRepository.removeTemporaryOutput(workspace: workspace)
            try await render(recipe: self.recipe ?? recipe, workspace: workspace, day: day)
        } catch {
            await finishFailure(error)
        }
    }

    private func render(
        recipe: DevVlogsBuildRecipe,
        workspace: DevVlogsBuildWorkspace,
        day: DevVlogsLibraryDay
    ) async throws {
        let clipsByID = Dictionary(uniqueKeysWithValues: uniqueClips(in: day).compactMap { clip in
            clip.clipID.map { ($0, clip) }
        })
        let sources = try recipe.orderedClipIDs.map { clipID -> DevVlogsBuildSource in
            guard let clip = clipsByID[clipID],
                  clip.health == .ready,
                  let mediaURL = clip.mediaURL,
                  let resourceIdentity = clip.resourceIdentity else {
                throw DevVlogsBuildError.sourceMissing
            }
            return DevVlogsBuildSource(
                clipID: clipID,
                fileURL: mediaURL,
                resourceIdentity: resourceIdentity
            )
        }
        guard let lease = ownershipRegistry.acquire(
            clipIDs: Set(recipe.orderedClipIDs),
            operation: .building
        ) else {
            throw DevVlogsLibraryError.clipBusy
        }
        defer { lease.release() }

        presentation = DevVlogsPublishPresentation(
            state: .building(
                selection(for: day),
                DevVlogsPublishBuildProgress(completedFraction: 0, detail: "Preparing compatible clips…")
            ),
            enabledActions: [.cancel]
        )
        try await recipeRepository.prepareForBuild(workspace: workspace)
        guard sources.allSatisfy({ $0.resourceIdentity.validateSourceAndMetadata() }) else {
            throw DevVlogsBuildError.sourceInvalid
        }
        let output = try await mediaBuilder.build(
            sources: sources,
            outputURL: workspace.temporaryOutputURL,
            outputPrepared: { [recipeRepository] identity in
                try await recipeRepository.registerTemporaryOutput(
                    workspace: workspace,
                    expectedIdentity: identity
                )
            }
        ) { [weak self] fraction in
            guard let self else { return }
            self.presentation = DevVlogsPublishPresentation(
                state: .building(
                    self.selection(for: day),
                    DevVlogsPublishBuildProgress(
                        completedFraction: fraction,
                        detail: "Combining \(sources.count) clips…"
                    )
                ),
                enabledActions: [.cancel]
            )
        }
        try Task.checkCancellation()
        try await recipeRepository.promoteOutput(workspace: workspace)
        let promoted = DevVlogsBuildOutput(
            fileURL: workspace.finalOutputURL,
            duration: output.duration,
            byteCount: output.byteCount
        )
        try await complete(promoted, recipe: recipe, workspace: workspace, day: day)
    }

    private func complete(
        _ output: DevVlogsBuildOutput,
        recipe: DevVlogsBuildRecipe,
        workspace: DevVlogsBuildWorkspace,
        day: DevVlogsLibraryDay
    ) async throws {
        let validated = try await mediaBuilder.validateOutput(at: output.fileURL)
        self.recipe = try await recipeRepository.update(
            recipe,
            lifecycle: .ready,
            failureCategory: nil,
            outputFileName: workspace.finalOutputURL.lastPathComponent,
            workspace: workspace
        )
        let artifact = DevVlogsPublishArtifact(
            buildID: recipe.id,
            name: "Dev Vlog — \(day.date.formatted(date: .abbreviated, time: .omitted)).mov",
            detail: "\(DevVlogsFormatting.duration(validated.duration)) · \(DevVlogsFormatting.byteCount(validated.byteCount)) · Original",
            outputLocation: "Recorded day / Builds",
            fileURL: validated.fileURL
        )
        presentation = DevVlogsPublishPresentation(
            state: .completed(selection(for: day), artifact),
            enabledActions: [.play, .reveal, .share]
        )
    }

    private func finishFailure(_ error: Error) async {
        guard let day = selectedLibraryDay else { return }
        let buildError: DevVlogsBuildError
        if error is CancellationError || Task.isCancelled {
            buildError = .cancelled
        } else {
            buildError = (error as? DevVlogsBuildError) ?? .exportFailed
        }
        var canRetry = false
        if let recipe, let workspace {
            do {
                try await recipeRepository.removeTemporaryOutput(workspace: workspace)
            } catch {
                canRetry = false
            }
            let lifecycle: DevVlogsBuildLifecycle = buildError == .cancelled ? .cancelled : .failed
            do {
                self.recipe = try await recipeRepository.update(
                    recipe,
                    lifecycle: lifecycle,
                    failureCategory: buildError.persistenceCategory,
                    outputFileName: nil,
                    workspace: workspace
                )
                canRetry = true
            } catch {
                canRetry = false
            }
        }
        let state: DevVlogsPublishState = buildError == .cancelled
            ? .cancelled(selection(for: day), message: buildError.localizedDescription)
            : .failed(selection(for: day), message: buildError.localizedDescription)
        presentation = DevVlogsPublishPresentation(
            state: state,
            enabledActions: canRetry ? [.retry] : []
        )
    }

    private func updateReadyPresentation() {
        guard let day = selectedLibraryDay else {
            presentation = .releaseEmpty
            return
        }
        guard !day.clips.isEmpty else {
            presentation = DevVlogsPublishPresentation(state: .emptyDay(presentationDay(day)))
            return
        }
        let selection = selection(for: day)
        let selected = orderedClips(in: day).filter { clip in
            guard let clipID = clip.clipID else { return false }
            return selectedClipIDs.contains(clipID)
        }
        if selected.isEmpty || selected.contains(where: { !$0.isBuildEligible }) {
            presentation = DevVlogsPublishPresentation(
                state: .selectionUnavailable(
                    selection,
                    message: selected.isEmpty
                        ? "Include at least one Ready clip before creating a video."
                        : "Exclude missing or unavailable clips before creating a video."
                )
            )
        } else {
            presentation = DevVlogsPublishPresentation(
                state: .selectionReady(selection),
                enabledActions: [.createVideo]
            )
        }
    }

    private func selection(for day: DevVlogsLibraryDay) -> DevVlogsPublishSelection {
        DevVlogsPublishSelection(
            day: presentationDay(day),
            clips: orderedClips(in: day).map { clip in
                DevVlogsPublishClip(
                    id: clip.id,
                    title: "\(clip.createdAt?.formatted(date: .omitted, time: .shortened) ?? "Unknown time") · \(clip.triggerApplicationName)",
                    detail: "\(DevVlogsFormatting.duration(clip.duration)) · \(clip.health.title)",
                    isSelected: clip.clipID.map(selectedClipIDs.contains) ?? false,
                    health: publishHealth(clip.health)
                )
            },
            outputLocation: "Recorded day / Builds"
        )
    }

    private func orderedClips(in day: DevVlogsLibraryDay) -> [DevVlogsLibraryClip] {
        let unique = uniqueClips(in: day)
        let ordered = orderedClipIDs.compactMap { clipID in
            unique.first { $0.clipID == clipID }
        }
        let orderedIDs = Set(ordered.map(\.id))
        let remaining = day.clips.filter { !orderedIDs.contains($0.id) }
        return ordered + remaining
    }

    private func uniqueClips(in day: DevVlogsLibraryDay) -> [DevVlogsLibraryClip] {
        let counts = Dictionary(grouping: day.clips.compactMap(\.clipID), by: { $0 })
            .mapValues(\.count)
        return day.clips.filter { clip in
            guard let clipID = clip.clipID else { return false }
            return counts[clipID] == 1
        }
    }

    private func uniqueClipIDs(in day: DevVlogsLibraryDay) -> [UUID] {
        uniqueClips(in: day).compactMap(\.clipID)
    }

    private func presentationDay(_ day: DevVlogsLibraryDay) -> DevVlogsPublishDay {
        DevVlogsPublishDay(
            id: day.id,
            title: day.date.formatted(date: .long, time: .omitted),
            detail: "\(day.clipCount) clips across \(day.appGroups.count) apps · \(DevVlogsFormatting.duration(day.duration))"
        )
    }

    private func publishHealth(_ health: DevVlogsLibraryHealth) -> DevVlogsPublishClip.Health {
        switch health {
        case .ready: return .ready
        case .missing: return .missing
        case .invalid: return .invalid
        }
    }

    private var selectedLibraryDay: DevVlogsLibraryDay? {
        days.first { $0.id == selectedDayID }
    }
}
