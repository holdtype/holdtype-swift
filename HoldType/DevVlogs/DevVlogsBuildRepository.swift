import Foundation

actor DevVlogsBuildRepository {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createRecipe(
        rootURL: URL,
        day: DevVlogsLibraryDay,
        orderedClipIDs: [UUID],
        buildID: UUID,
        createdAt: Date
    ) throws -> (recipe: DevVlogsBuildRecipe, workspace: DevVlogsBuildWorkspace) {
        guard !orderedClipIDs.isEmpty else { throw DevVlogsBuildError.noSelectedClips }
        let yearKey = DevVlogsArchiveNaming.yearKey(for: day.date)
        let directoryURL = rootURL
            .appendingPathComponent(yearKey, isDirectory: true)
            .appendingPathComponent(day.id, isDirectory: true)
            .appendingPathComponent("builds", isDirectory: true)
            .appendingPathComponent(buildID.uuidString.lowercased(), isDirectory: true)
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
        let workspace = DevVlogsBuildWorkspace(
            directoryURL: directoryURL,
            recipeURL: directoryURL.appendingPathComponent("build.json"),
            temporaryOutputURL: directoryURL.appendingPathComponent(".output-in-progress.mov"),
            finalOutputURL: directoryURL.appendingPathComponent("output.mov")
        )
        var recipe = DevVlogsBuildRecipe(
            schemaVersion: 1,
            id: buildID,
            createdAt: createdAt,
            dayKey: day.id,
            orderedClipIDs: orderedClipIDs,
            policy: .original,
            lifecycle: .draft,
            failureCategory: nil,
            outputFileName: nil
        )
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try write(recipe, to: workspace.recipeURL)
            recipe.lifecycle = .building
            try write(recipe, to: workspace.recipeURL)
            return (recipe, workspace)
        } catch {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
    }

    func update(
        _ recipe: DevVlogsBuildRecipe,
        lifecycle: DevVlogsBuildLifecycle,
        failureCategory: String?,
        outputFileName: String?,
        workspace: DevVlogsBuildWorkspace
    ) throws -> DevVlogsBuildRecipe {
        var updated = recipe
        updated.lifecycle = lifecycle
        updated.failureCategory = failureCategory
        updated.outputFileName = outputFileName
        do {
            try write(updated, to: workspace.recipeURL)
            return updated
        } catch {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
    }

    func promoteOutput(workspace: DevVlogsBuildWorkspace) throws {
        guard !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }
        do {
            try fileManager.moveItem(at: workspace.temporaryOutputURL, to: workspace.finalOutputURL)
        } catch {
            throw DevVlogsBuildError.exportFailed
        }
    }

    func removeTemporaryOutput(workspace: DevVlogsBuildWorkspace) {
        guard fileManager.fileExists(atPath: workspace.temporaryOutputURL.path) else { return }
        try? fileManager.removeItem(at: workspace.temporaryOutputURL)
    }

    private func write(_ recipe: DevVlogsBuildRecipe, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recipe).write(to: url, options: .atomic)
    }
}
