import Combine
import Foundation

@MainActor
final class DevVlogsPublishStore: ObservableObject {
    @Published private(set) var presentation: DevVlogsPublishPresentation = .releaseEmpty
    @Published private(set) var selectedDayID: String?
    @Published private(set) var selectedApplicationID = DevVlogsPublishApplication.all.id
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshFailureMessage: String?

    private let destinationAccessProvider: () throws -> DevVlogsCaptureDestinationAccess
    private let archiveLoader: (URL) async throws -> DevVlogsLibrarySnapshot
    private let recipeRepository: DevVlogsBuildRepository
    private let mediaBuilder: any DevVlogsMediaBuilding
    private let ownershipRegistry: DevVlogsClipOwnershipRegistry
    private let now: () -> Date
    private let buildIDProvider: () -> UUID

    private var days: [DevVlogsLibraryDay] = []
    private var recipe: DevVlogsBuildRecipe?
    private var workspace: DevVlogsBuildWorkspace?
    private var staging: DevVlogsBuildStaging?
    private var buildTask: Task<Void, Never>?

    convenience init(destinationStore: DevVlogsDestinationSetupStore) {
        let repository = DevVlogsLibraryRepository()
        self.init(
            destinationAccessProvider: { try destinationStore.acquireCaptureDestination() },
            archiveLoader: { try await repository.load(rootURL: $0) }
        )
    }

    convenience init(
        destinationAccessProvider: @escaping () throws -> DevVlogsCaptureDestinationAccess,
        archiveLoader: ((URL) async throws -> DevVlogsLibrarySnapshot)? = nil
    ) {
        let repository = DevVlogsLibraryRepository()
        self.init(
            destinationAccessProvider: destinationAccessProvider,
            archiveLoader: archiveLoader ?? { try await repository.load(rootURL: $0) },
            recipeRepository: DevVlogsBuildRepository(),
            mediaBuilder: AVFoundationDevVlogsMediaBuilder(),
            ownershipRegistry: .shared,
            now: Date.init,
            buildIDProvider: UUID.init
        )
    }

    init(
        destinationAccessProvider: @escaping () throws -> DevVlogsCaptureDestinationAccess,
        archiveLoader: @escaping (URL) async throws -> DevVlogsLibrarySnapshot,
        recipeRepository: DevVlogsBuildRepository,
        mediaBuilder: any DevVlogsMediaBuilding,
        ownershipRegistry: DevVlogsClipOwnershipRegistry,
        now: @escaping () -> Date,
        buildIDProvider: @escaping () -> UUID
    ) {
        self.destinationAccessProvider = destinationAccessProvider
        self.archiveLoader = archiveLoader
        self.recipeRepository = recipeRepository
        self.mediaBuilder = mediaBuilder
        self.ownershipRegistry = ownershipRegistry
        self.now = now
        self.buildIDProvider = buildIDProvider
    }

    var availableDays: [DevVlogsPublishDay] {
        days.map(presentationDay)
    }

    var availableApplications: [DevVlogsPublishApplication] {
        guard let day = selectedLibraryDay else { return [.all] }
        return [.all] + day.appGroups.map(presentationApplication)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshFailureMessage = nil
        defer { isRefreshing = false }
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            let snapshot = try await archiveLoader(access.url)
            synchronize(days: snapshot.days)
            lastRefreshAt = now()
        } catch is CancellationError {
            return
        } catch {
            refreshFailureMessage = "Refresh failed. Reconnect the Dev Vlogs destination and try again."
            guard buildTask == nil else { return }
            if let selection = presentation.state.selection {
                presentation = DevVlogsPublishPresentation(
                    state: .selectionUnavailable(
                        selection,
                        message: "The selected source is unavailable. Reconnect it or open it in Finder, then refresh."
                    ),
                    enabledActions: [.openInFinder, .refresh]
                )
            } else {
                presentation = .releaseEmpty
            }
        }
    }

    func synchronize(days newDays: [DevVlogsLibraryDay]) {
        days = newDays
        guard buildTask == nil else { return }
        guard let day = newDays.first(where: { $0.id == selectedDayID }) ?? newDays.first else {
            selectedDayID = nil
            selectedApplicationID = DevVlogsPublishApplication.all.id
            presentation = .releaseEmpty
            return
        }
        selectedDayID = day.id
        if selectedApplicationID != DevVlogsPublishApplication.all.id,
           !day.appGroups.contains(where: { applicationIdentifier($0) == selectedApplicationID }) {
            selectedApplicationID = DevVlogsPublishApplication.all.id
        }
        recipe = nil
        workspace = nil
        updateReadyPresentation()
    }

    func selectDay(id: String) {
        guard buildTask == nil, days.contains(where: { $0.id == id }) else { return }
        selectedDayID = id
        selectedApplicationID = DevVlogsPublishApplication.all.id
        recipe = nil
        workspace = nil
        updateReadyPresentation()
    }

    func selectApplication(id: String) {
        guard buildTask == nil,
              availableApplications.contains(where: { $0.id == id }) else { return }
        selectedApplicationID = id
        recipe = nil
        workspace = nil
        updateReadyPresentation()
    }

    func openSourceInFinder(using fileActions: any DevVlogsFileActionPerforming) {
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            guard let sourceURL = selectedSourceURL(rootURL: access.url),
                  DevVlogsFileIdentity.capture(at: sourceURL, kind: .directory) != nil else {
                throw DevVlogsLibraryError.sourceMissing
            }
            fileActions.open(sourceURL)
        } catch {
            Task { await refresh() }
        }
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

    private func runNewBuild() async {
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            let snapshot = try await archiveLoader(access.url)
            guard let day = snapshot.days.first(where: { $0.id == selectedDayID }) else {
                throw DevVlogsBuildError.sourceMissing
            }
            let clips = scopedClips(in: day)
            guard !clips.isEmpty else { throw DevVlogsBuildError.sourceMissing }
            guard clips.allSatisfy(\.isBuildEligible) else { throw DevVlogsBuildError.sourceInvalid }
            let orderedIDs = clips.compactMap(\.clipID)
            guard orderedIDs.count == clips.count, Set(orderedIDs).count == clips.count else {
                throw DevVlogsBuildError.sourceInvalid
            }
            days = snapshot.days
            let created = try await recipeRepository.createRecipe(
                rootURL: access.url,
                day: day,
                orderedClipIDs: orderedIDs,
                buildID: buildIDProvider(),
                createdAt: now()
            )
            recipe = created.recipe
            workspace = created.workspace
            try await render(recipe: created.recipe, workspace: created.workspace, day: day)
        } catch {
            await finishFailure(error)
        }
    }

    private func runRetry() async {
        guard let recipe, let workspace else { return }
        do {
            let access = try destinationAccessProvider()
            defer { access.release() }
            let snapshot = try await archiveLoader(access.url)
            guard let day = snapshot.days.first(where: { $0.id == recipe.dayKey }) else {
                throw DevVlogsBuildError.sourceMissing
            }
            days = snapshot.days
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
            try await recipeRepository.removeStagedOutput(workspace: workspace, staging: staging)
            staging = nil
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
        let clipsByID = Dictionary(uniqueKeysWithValues: day.clips.compactMap { clip in
            clip.clipID.map { ($0, clip) }
        })
        let sources = try recipe.orderedClipIDs.map { clipID -> DevVlogsBuildSource in
            guard let clip = clipsByID[clipID], clip.isBuildEligible,
                  let mediaURL = clip.mediaURL, let identity = clip.resourceIdentity else {
                throw DevVlogsBuildError.sourceMissing
            }
            return DevVlogsBuildSource(clipID: clipID, fileURL: mediaURL, resourceIdentity: identity)
        }
        guard let lease = ownershipRegistry.acquire(
            clipIDs: Set(recipe.orderedClipIDs), operation: .building
        ) else { throw DevVlogsLibraryError.clipBusy }
        defer { lease.release() }

        presentation = DevVlogsPublishPresentation(
            state: .building(selection(for: day), .init(completedFraction: 0, detail: "Preparing compatible clips…")),
            enabledActions: [.cancel]
        )
        let staging = try await recipeRepository.prepareForBuild(workspace: workspace)
        self.staging = staging
        guard sources.allSatisfy({ $0.resourceIdentity.validateSourceAndMetadata() }) else {
            throw DevVlogsBuildError.sourceInvalid
        }
        let output = try await mediaBuilder.build(
            sources: sources,
            outputURL: staging.outputURL,
            outputPrepared: { [recipeRepository] identity in
                try await recipeRepository.registerStagedOutput(
                    workspace: workspace, staging: staging, expectedIdentity: identity
                )
            }
        ) { [weak self] fraction in
            guard let self else { return }
            self.presentation = DevVlogsPublishPresentation(
                state: .building(
                    self.selection(for: day),
                    .init(completedFraction: fraction, detail: "Combining \(sources.count) clips…")
                ),
                enabledActions: [.cancel]
            )
        }
        try Task.checkCancellation()
        try await recipeRepository.promoteOutput(workspace: workspace, staging: staging)
        self.staging = nil
        try await complete(
            .init(fileURL: workspace.finalOutputURL, duration: output.duration, byteCount: output.byteCount),
            recipe: recipe,
            workspace: workspace,
            day: day
        )
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
            enabledActions: [.openInFinder, .refresh, .play, .reveal, .share]
        )
    }

    private func finishFailure(_ error: Error) async {
        guard let day = selectedLibraryDay else {
            presentation = .releaseEmpty
            return
        }
        let buildError: DevVlogsBuildError = error is CancellationError || Task.isCancelled
            ? .cancelled
            : (error as? DevVlogsBuildError) ?? .exportFailed
        var canRetry = false
        if let recipe, let workspace {
            do {
                try await recipeRepository.removeStagedOutput(workspace: workspace, staging: staging)
                staging = nil
                self.recipe = try await recipeRepository.update(
                    recipe,
                    lifecycle: buildError == .cancelled ? .cancelled : .failed,
                    failureCategory: buildError.persistenceCategory,
                    outputFileName: nil,
                    workspace: workspace
                )
                canRetry = true
            } catch {
                canRetry = false
            }
        }
        let message = buildError == .sourceMissing || buildError == .sourceInvalid
            ? "The selected source changed or is unavailable. Open it in Finder, then refresh and try again."
            : buildError.localizedDescription
        let state: DevVlogsPublishState = buildError == .cancelled
            ? .cancelled(selection(for: day), message: message)
            : .failed(selection(for: day), message: message)
        var actions: Set<DevVlogsPublishAction> = [.openInFinder, .refresh]
        if canRetry { actions.insert(.retry) }
        presentation = DevVlogsPublishPresentation(state: state, enabledActions: actions)
    }

    private func updateReadyPresentation() {
        guard let day = selectedLibraryDay else {
            presentation = .releaseEmpty
            return
        }
        let selection = selection(for: day)
        if selection.summary.clipCount == 0 {
            presentation = DevVlogsPublishPresentation(
                state: .emptyDay(selection), enabledActions: [.openInFinder, .refresh]
            )
        } else if !selection.summary.isReady {
            presentation = DevVlogsPublishPresentation(
                state: .selectionUnavailable(
                    selection,
                    message: "Some source files are missing or unavailable. Review them in Finder, then refresh."
                ),
                enabledActions: [.openInFinder, .refresh]
            )
        } else {
            presentation = DevVlogsPublishPresentation(
                state: .selectionReady(selection),
                enabledActions: [.openInFinder, .refresh, .createVideo]
            )
        }
    }

    private func selection(for day: DevVlogsLibraryDay) -> DevVlogsPublishSelection {
        let clips = scopedClips(in: day)
        return DevVlogsPublishSelection(
            day: presentationDay(day),
            application: selectedApplication(in: day),
            applications: [.all] + day.appGroups.map(presentationApplication),
            summary: .init(
                clipCount: clips.count,
                duration: clips.reduce(0) { $0 + $1.duration },
                byteCount: clips.reduce(0) { $0 + $1.byteCount },
                invalidCount: clips.filter { !$0.isBuildEligible }.count
            ),
            outputLocation: "Recorded day / Builds"
        )
    }

    private func scopedClips(in day: DevVlogsLibraryDay) -> [DevVlogsLibraryClip] {
        guard selectedApplicationID != DevVlogsPublishApplication.all.id else { return day.clips }
        return day.appGroups.first(where: { applicationIdentifier($0) == selectedApplicationID })?.clips ?? []
    }

    private func selectedApplication(in day: DevVlogsLibraryDay) -> DevVlogsPublishApplication {
        guard let group = day.appGroups.first(where: {
            applicationIdentifier($0) == selectedApplicationID
        }) else { return .all }
        return presentationApplication(group)
    }

    private func selectedSourceURL(rootURL: URL) -> URL? {
        guard let day = selectedLibraryDay else { return nil }
        let dayURL = rootURL
            .appendingPathComponent(String(day.id.prefix(4)), isDirectory: true)
            .appendingPathComponent(day.id, isDirectory: true)
        guard selectedApplicationID != DevVlogsPublishApplication.all.id else { return dayURL }
        guard let group = day.appGroups.first(where: {
            applicationIdentifier($0) == selectedApplicationID
        }) else { return nil }
        return dayURL.appendingPathComponent("apps", isDirectory: true)
            .appendingPathComponent(group.id, isDirectory: true)
    }

    private func presentationDay(_ day: DevVlogsLibraryDay) -> DevVlogsPublishDay {
        DevVlogsPublishDay(
            id: day.id,
            title: day.date.formatted(date: .long, time: .omitted),
            detail: "\(day.clipCount) clips across \(day.appGroups.count) apps"
        )
    }

    private func presentationApplication(_ group: DevVlogsLibraryAppGroup) -> DevVlogsPublishApplication {
        .init(
            id: applicationIdentifier(group),
            title: group.displayName,
            detail: "\(group.clips.count) clips"
        )
    }

    private func applicationIdentifier(_ group: DevVlogsLibraryAppGroup) -> String {
        "application:\(group.id)"
    }

    private var selectedLibraryDay: DevVlogsLibraryDay? {
        days.first { $0.id == selectedDayID }
    }
}
