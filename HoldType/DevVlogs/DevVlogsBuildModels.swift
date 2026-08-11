import Foundation

nonisolated enum DevVlogsBuildLifecycle: String, Codable, Equatable {
    case draft
    case building
    case ready
    case failed
    case cancelled
}

nonisolated enum DevVlogsBuildPolicy: String, Codable, Equatable {
    case original
}

nonisolated struct DevVlogsBuildRecipe: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    let id: UUID
    let createdAt: Date
    let dayKey: String
    let orderedClipIDs: [UUID]
    let policy: DevVlogsBuildPolicy
    var lifecycle: DevVlogsBuildLifecycle
    var failureCategory: String?
    var outputFileName: String?
}

nonisolated struct DevVlogsBuildSource: Equatable {
    let clipID: UUID
    let fileURL: URL
    let resourceIdentity: DevVlogsClipResourceIdentity
}

nonisolated struct DevVlogsBuildOutput: Equatable {
    let fileURL: URL
    let duration: TimeInterval
    let byteCount: Int64
}

nonisolated struct DevVlogsBuildWorkspace: Equatable {
    let buildID: UUID
    let directoryURL: URL
    let recipeURL: URL
    let temporaryOutputURL: URL
    let finalOutputURL: URL
}

nonisolated final class DevVlogsBuildStaging: @unchecked Sendable {
    let directoryURL: URL
    let outputURL: URL
    let directoryIdentity: DevVlogsFileIdentity
    let directoryHandle: FileHandle
    var outputIdentity: DevVlogsFileIdentity?

    init(
        directoryURL: URL,
        outputURL: URL,
        directoryIdentity: DevVlogsFileIdentity,
        directoryHandle: FileHandle
    ) {
        self.directoryURL = directoryURL
        self.outputURL = outputURL
        self.directoryIdentity = directoryIdentity
        self.directoryHandle = directoryHandle
        outputIdentity = nil
    }

    var directoryDescriptor: Int32 {
        directoryHandle.fileDescriptor
    }
}

nonisolated enum DevVlogsBuildError: Error, Equatable, LocalizedError {
    case noSelectedClips
    case recipePersistenceFailed
    case sourceMissing
    case sourceInvalid
    case incompatibleSources
    case outputAlreadyExists
    case workspaceChanged
    case cancelled
    case timedOut
    case exportFailed
    case outputInvalid

    var errorDescription: String? {
        switch self {
        case .noSelectedClips:
            return "Select at least one ready clip."
        case .recipePersistenceFailed:
            return "The video recipe could not be saved."
        case .sourceMissing:
            return "One or more selected clips are missing."
        case .sourceInvalid:
            return "One or more selected clips cannot be opened."
        case .incompatibleSources:
            return "The selected clips cannot be combined without changing the source video. No output was created."
        case .outputAlreadyExists:
            return "This recipe already owns an output and it was not overwritten."
        case .workspaceChanged:
            return "The build folder changed, so HoldType left it and every source unchanged."
        case .cancelled:
            return "Video creation was cancelled. Sources and the recipe are unchanged."
        case .timedOut:
            return "Video creation timed out. Sources and the recipe are unchanged."
        case .exportFailed:
            return "The video could not be created. Sources and the recipe are unchanged."
        case .outputInvalid:
            return "The completed video could not be validated, so result actions remain unavailable."
        }
    }

    var persistenceCategory: String {
        switch self {
        case .noSelectedClips: return "no_selected_clips"
        case .recipePersistenceFailed: return "recipe_persistence_failed"
        case .sourceMissing: return "source_missing"
        case .sourceInvalid: return "source_invalid"
        case .incompatibleSources: return "incompatible_sources"
        case .outputAlreadyExists: return "output_exists"
        case .workspaceChanged: return "workspace_changed"
        case .cancelled: return "cancelled"
        case .timedOut: return "timed_out"
        case .exportFailed: return "export_failed"
        case .outputInvalid: return "output_invalid"
        }
    }
}
