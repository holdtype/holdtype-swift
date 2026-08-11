import Darwin
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

    func prepareForBuild(workspace: DevVlogsBuildWorkspace) throws -> DevVlogsBuildStaging {
        _ = try validatedIdentity(for: workspace)
        guard !fileManager.fileExists(atPath: workspace.temporaryOutputURL.path),
              !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }
        return try createStaging(for: workspace)
    }

    func registerStagedOutput(
        workspace: DevVlogsBuildWorkspace,
        staging: DevVlogsBuildStaging,
        expectedIdentity: DevVlogsFileIdentity
    ) throws {
        _ = try validatedIdentity(for: workspace)
        guard validate(staging),
              let stagedIdentity = DevVlogsFileIdentity.capture(
                atDirectoryDescriptor: staging.directoryDescriptor,
                name: staging.outputURL.lastPathComponent,
                kind: .regularFile,
                requireSingleLink: true
              ),
              stagedIdentity == expectedIdentity,
              !fileManager.fileExists(atPath: workspace.finalOutputURL.path) else {
            throw DevVlogsBuildError.workspaceChanged
        }
        staging.outputIdentity = stagedIdentity
    }

    func promoteOutput(
        workspace: DevVlogsBuildWorkspace,
        staging: DevVlogsBuildStaging
    ) throws {
        let identity = try validatedIdentity(for: workspace)
        guard validate(staging),
              let stagedIdentity = DevVlogsFileIdentity.capture(
                atDirectoryDescriptor: staging.directoryDescriptor,
                name: staging.outputURL.lastPathComponent,
                kind: .regularFile,
                requireSingleLink: true
              ),
              stagedIdentity == staging.outputIdentity else {
            throw DevVlogsBuildError.workspaceChanged
        }
        let descriptor = Darwin.open(
            workspace.directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else { throw DevVlogsBuildError.workspaceChanged }
        defer { Darwin.close(descriptor) }
        guard DevVlogsFileIdentity.capture(descriptor: descriptor, kind: .directory)
            == identity.hierarchy.last else {
            throw DevVlogsBuildError.workspaceChanged
        }
        guard try entryIsAbsent(
            atDirectoryDescriptor: descriptor,
            name: workspace.finalOutputURL.lastPathComponent
        ) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }
        guard renameatx_np(
            staging.directoryDescriptor,
            staging.outputURL.lastPathComponent,
            descriptor,
            workspace.finalOutputURL.lastPathComponent,
            UInt32(RENAME_EXCL)
        ) == 0 else {
            if errno == EEXIST { throw DevVlogsBuildError.outputAlreadyExists }
            throw DevVlogsBuildError.exportFailed
        }
        guard let finalIdentity = DevVlogsFileIdentity.capture(
            atDirectoryDescriptor: descriptor,
            name: workspace.finalOutputURL.lastPathComponent,
            kind: .regularFile,
            requireSingleLink: true
        ),
            finalIdentity.device == stagedIdentity.device,
            finalIdentity.inode == stagedIdentity.inode else {
            throw DevVlogsBuildError.workspaceChanged
        }
        do {
            _ = try validatedIdentity(for: workspace, allowUnregisteredFinal: true)
        } catch {
            throw DevVlogsBuildError.workspaceChanged
        }
        identities[workspace.buildID] = replacing(identity, finalOutputIdentity: finalIdentity)
        try removeStagingDirectory(staging)
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

    func removeStagedOutput(
        workspace: DevVlogsBuildWorkspace,
        staging: DevVlogsBuildStaging?
    ) throws {
        if let staging {
            try removeStagingDirectory(staging)
        }
        _ = try validatedIdentity(for: workspace)
    }

    private func validatedIdentity(
        for workspace: DevVlogsBuildWorkspace,
        allowUnregisteredTemporary: Bool = false,
        allowUnregisteredFinal: Bool = false
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
           fileManager.fileExists(atPath: workspace.finalOutputURL.path),
           !allowUnregisteredFinal {
            throw DevVlogsBuildError.workspaceChanged
        }
        return identity
    }

    private func createStaging(for workspace: DevVlogsBuildWorkspace) throws -> DevVlogsBuildStaging {
        let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "HoldType-DevVlogs-Build-\(workspace.buildID.uuidString)-\(UUID().uuidString)",
            isDirectory: true
        )
        guard mkdir(directoryURL.path, S_IRWXU) == 0 else {
            throw DevVlogsBuildError.exportFailed
        }
        let descriptor = Darwin.open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0,
              let identity = DevVlogsFileIdentity.capture(descriptor: descriptor, kind: .directory),
              identity.matches(directoryURL) else {
            if descriptor >= 0 { Darwin.close(descriptor) }
            _ = rmdir(directoryURL.path)
            throw DevVlogsBuildError.exportFailed
        }
        return DevVlogsBuildStaging(
            directoryURL: directoryURL,
            outputURL: directoryURL.appendingPathComponent("output.mov"),
            directoryIdentity: identity,
            directoryHandle: FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        )
    }

    private func validate(_ staging: DevVlogsBuildStaging) -> Bool {
        guard staging.directoryIdentity.matches(staging.directoryURL),
              DevVlogsFileIdentity.capture(
                descriptor: staging.directoryDescriptor,
                kind: .directory
              ) == staging.directoryIdentity,
              let children = try? fileManager.contentsOfDirectory(
                at: staging.directoryURL,
                includingPropertiesForKeys: nil
              ) else {
            return false
        }
        return Set(children.map(\.lastPathComponent)).isSubset(
            of: Set([staging.outputURL.lastPathComponent])
        )
    }

    private func entryIsAbsent(
        atDirectoryDescriptor descriptor: Int32,
        name: String
    ) throws -> Bool {
        var value = stat()
        if fstatat(descriptor, name, &value, AT_SYMLINK_NOFOLLOW) == 0 {
            return false
        }
        guard errno == ENOENT else { throw DevVlogsBuildError.workspaceChanged }
        return true
    }

    private func removeStagingDirectory(_ staging: DevVlogsBuildStaging) throws {
        guard validate(staging) else { throw DevVlogsBuildError.workspaceChanged }
        if let current = DevVlogsFileIdentity.capture(
            atDirectoryDescriptor: staging.directoryDescriptor,
            name: staging.outputURL.lastPathComponent,
            kind: .regularFile,
            requireSingleLink: true
        ) {
            guard current == staging.outputIdentity else {
                throw DevVlogsBuildError.workspaceChanged
            }
            guard unlinkat(staging.directoryDescriptor, staging.outputURL.lastPathComponent, 0) == 0 else {
                throw DevVlogsBuildError.workspaceChanged
            }
        } else if errno != ENOENT {
            throw DevVlogsBuildError.workspaceChanged
        }
        guard staging.directoryIdentity.matches(staging.directoryURL),
              rmdir(staging.directoryURL.path) == 0 else {
            throw DevVlogsBuildError.workspaceChanged
        }
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
