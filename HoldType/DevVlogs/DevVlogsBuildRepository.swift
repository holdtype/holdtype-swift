import Foundation

actor DevVlogsBuildRepository {
    private let fileManager: FileManager
    private var identities: [UUID: DevVlogsWorkspaceIdentity] = [:]

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
        let root = rootURL.standardizedFileURL
        guard day.id.count == 10,
              day.id.dropFirst(4).first == "-" else {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
        let yearKey = String(day.id.prefix(4))
        let yearURL = root.appendingPathComponent(yearKey, isDirectory: true)
        let dayURL = yearURL.appendingPathComponent(day.id, isDirectory: true)
        let buildsURL = dayURL.appendingPathComponent("builds", isDirectory: true)
        guard let rootIdentity = captureDirectory(root),
              let yearIdentity = captureDirectory(yearURL),
              let dayIdentity = captureDirectory(dayURL) else {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
        do {
            if fileManager.fileExists(atPath: buildsURL.path) {
                guard captureDirectory(buildsURL) != nil else {
                    throw DevVlogsBuildError.workspaceChanged
                }
            } else {
                try fileManager.createDirectory(at: buildsURL, withIntermediateDirectories: false)
            }
        } catch let error as DevVlogsBuildError {
            throw error
        } catch {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
        guard rootIdentity.matches(root),
              yearIdentity.matches(yearURL),
              dayIdentity.matches(dayURL),
              let buildsIdentity = captureDirectory(buildsURL) else {
            throw DevVlogsBuildError.workspaceChanged
        }

        let directoryURL = buildsURL.appendingPathComponent(
            buildID.uuidString.lowercased(),
            isDirectory: true
        )
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
        let workspace = DevVlogsBuildWorkspace(
            buildID: buildID,
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
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
            guard rootIdentity.matches(root),
                  yearIdentity.matches(yearURL),
                  dayIdentity.matches(dayURL),
                  buildsIdentity.matches(buildsURL) else {
                throw DevVlogsBuildError.workspaceChanged
            }
            try write(recipe, to: workspace.recipeURL)
            guard let identity = captureWorkspace(
                rootURL: root,
                hierarchyURLs: [root, yearURL, dayURL, buildsURL, directoryURL],
                workspace: workspace,
                temporaryOutputIdentity: nil,
                finalOutputIdentity: nil
            ) else {
                throw DevVlogsBuildError.workspaceChanged
            }
            guard identity.hierarchy == [
                rootIdentity,
                yearIdentity,
                dayIdentity,
                buildsIdentity,
                try requiredDirectoryIdentity(directoryURL)
            ] else {
                throw DevVlogsBuildError.workspaceChanged
            }
            identities[buildID] = identity
            recipe = try update(
                recipe,
                lifecycle: .building,
                failureCategory: nil,
                outputFileName: nil,
                workspace: workspace
            )
            return (recipe, workspace)
        } catch let error as DevVlogsBuildError {
            throw error
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
        let identity = try validatedIdentity(for: workspace)
        var updated = recipe
        updated.lifecycle = lifecycle
        updated.failureCategory = failureCategory
        updated.outputFileName = outputFileName
        do {
            try write(updated, to: workspace.recipeURL)
            guard let recipeIdentity = captureRegular(workspace.recipeURL) else {
                throw DevVlogsBuildError.workspaceChanged
            }
            identities[workspace.buildID] = replacing(
                identity,
                recipeIdentity: recipeIdentity
            )
            return updated
        } catch let error as DevVlogsBuildError {
            throw error
        } catch {
            throw DevVlogsBuildError.recipePersistenceFailed
        }
    }

    func prepareForBuild(workspace: DevVlogsBuildWorkspace) throws {
        _ = try validatedIdentity(for: workspace)
        guard !fileManager.fileExists(atPath: workspace.temporaryOutputURL.path),
              !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }
    }

    func registerTemporaryOutput(
        workspace: DevVlogsBuildWorkspace,
        expectedIdentity: DevVlogsFileIdentity
    ) throws {
        let identity = try validatedIdentity(for: workspace, allowUnregisteredTemporary: true)
        guard identity.temporaryOutputIdentity == nil,
              let temporaryIdentity = captureRegular(workspace.temporaryOutputURL),
              temporaryIdentity == expectedIdentity,
              !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        identities[workspace.buildID] = replacing(
            identity,
            temporaryOutputIdentity: temporaryIdentity
        )
    }

    func promoteOutput(workspace: DevVlogsBuildWorkspace) throws {
        let identity = try validatedIdentity(for: workspace)
        guard let temporaryIdentity = identity.temporaryOutputIdentity,
              temporaryIdentity.matches(workspace.temporaryOutputURL, requireSingleLink: true),
              !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }
        do {
            try fileManager.moveItem(at: workspace.temporaryOutputURL, to: workspace.finalOutputURL)
            guard let finalIdentity = captureRegular(workspace.finalOutputURL),
                  finalIdentity.inode == temporaryIdentity.inode,
                  finalIdentity.device == temporaryIdentity.device else {
                throw DevVlogsBuildError.workspaceChanged
            }
            identities[workspace.buildID] = replacing(
                identity,
                temporaryOutputIdentity: .some(nil),
                finalOutputIdentity: finalIdentity
            )
        } catch let error as DevVlogsBuildError {
            throw error
        } catch {
            throw DevVlogsBuildError.exportFailed
        }
    }

    func completedOutputURL(workspace: DevVlogsBuildWorkspace) throws -> URL? {
        let identity = try validatedIdentity(for: workspace)
        guard fileManager.fileExists(atPath: workspace.finalOutputURL.path) else { return nil }
        guard let finalIdentity = identity.finalOutputIdentity,
              finalIdentity.matches(workspace.finalOutputURL, requireSingleLink: true) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        return workspace.finalOutputURL
    }

    func removeTemporaryOutput(workspace: DevVlogsBuildWorkspace) throws {
        let identity = try validatedIdentity(for: workspace)
        guard fileManager.fileExists(atPath: workspace.temporaryOutputURL.path) else { return }
        guard let temporaryIdentity = identity.temporaryOutputIdentity,
              temporaryIdentity.matches(workspace.temporaryOutputURL, requireSingleLink: true) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        try fileManager.removeItem(at: workspace.temporaryOutputURL)
        identities[workspace.buildID] = replacing(
            identity,
            temporaryOutputIdentity: .some(nil)
        )
    }

    private func validatedIdentity(
        for workspace: DevVlogsBuildWorkspace,
        allowUnregisteredTemporary: Bool = false
    ) throws -> DevVlogsWorkspaceIdentity {
        guard let identity = identities[workspace.buildID],
              identity.buildID == workspace.buildID,
              identity.hierarchyURLs.last == workspace.directoryURL,
              identity.hierarchyURLs.count == identity.hierarchy.count else {
            throw DevVlogsBuildError.workspaceChanged
        }
        for (url, expected) in zip(identity.hierarchyURLs, identity.hierarchy) {
            guard expected.matches(url) else { throw DevVlogsBuildError.workspaceChanged }
        }
        guard identity.recipeIdentity.matches(workspace.recipeURL, requireSingleLink: true) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        let allowed = Set(["build.json", ".output-in-progress.mov", "output.mov"])
        guard let children = try? fileManager.contentsOfDirectory(
            at: workspace.directoryURL,
            includingPropertiesForKeys: nil
        ),
            Set(children.map(\.lastPathComponent)).isSubset(of: allowed) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        if let temporary = identity.temporaryOutputIdentity,
           !temporary.matches(workspace.temporaryOutputURL, requireSingleLink: true) {
            throw DevVlogsBuildError.workspaceChanged
        }
        if identity.temporaryOutputIdentity == nil,
           fileManager.fileExists(atPath: workspace.temporaryOutputURL.path),
           !allowUnregisteredTemporary {
            throw DevVlogsBuildError.workspaceChanged
        }
        if let final = identity.finalOutputIdentity,
           !final.matches(workspace.finalOutputURL, requireSingleLink: true) {
            throw DevVlogsBuildError.workspaceChanged
        }
        if identity.finalOutputIdentity == nil,
           fileManager.fileExists(atPath: workspace.finalOutputURL.path) {
            throw DevVlogsBuildError.workspaceChanged
        }
        return identity
    }

    private func captureWorkspace(
        rootURL: URL,
        hierarchyURLs: [URL],
        workspace: DevVlogsBuildWorkspace,
        temporaryOutputIdentity: DevVlogsFileIdentity?,
        finalOutputIdentity: DevVlogsFileIdentity?
    ) -> DevVlogsWorkspaceIdentity? {
        let hierarchy = hierarchyURLs.compactMap(captureDirectory)
        guard hierarchy.count == hierarchyURLs.count,
              let recipeIdentity = captureRegular(workspace.recipeURL) else { return nil }
        return DevVlogsWorkspaceIdentity(
            rootURL: rootURL,
            buildID: workspace.buildID,
            hierarchyURLs: hierarchyURLs,
            hierarchy: hierarchy,
            recipeIdentity: recipeIdentity,
            temporaryOutputIdentity: temporaryOutputIdentity,
            finalOutputIdentity: finalOutputIdentity
        )
    }

    private func replacing(
        _ identity: DevVlogsWorkspaceIdentity,
        recipeIdentity: DevVlogsFileIdentity? = nil,
        temporaryOutputIdentity: DevVlogsFileIdentity?? = nil,
        finalOutputIdentity: DevVlogsFileIdentity?? = nil
    ) -> DevVlogsWorkspaceIdentity {
        DevVlogsWorkspaceIdentity(
            rootURL: identity.rootURL,
            buildID: identity.buildID,
            hierarchyURLs: identity.hierarchyURLs,
            hierarchy: identity.hierarchy,
            recipeIdentity: recipeIdentity ?? identity.recipeIdentity,
            temporaryOutputIdentity: temporaryOutputIdentity ?? identity.temporaryOutputIdentity,
            finalOutputIdentity: finalOutputIdentity ?? identity.finalOutputIdentity
        )
    }

    private func captureDirectory(_ url: URL) -> DevVlogsFileIdentity? {
        DevVlogsFileIdentity.capture(at: url, kind: .directory)
    }

    private func captureRegular(_ url: URL) -> DevVlogsFileIdentity? {
        DevVlogsFileIdentity.capture(at: url, kind: .regularFile, requireSingleLink: true)
    }

    private func requiredDirectoryIdentity(_ url: URL) throws -> DevVlogsFileIdentity {
        guard let identity = captureDirectory(url) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        return identity
    }

    private func write(_ recipe: DevVlogsBuildRecipe, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recipe).write(to: url, options: .atomic)
    }
}
