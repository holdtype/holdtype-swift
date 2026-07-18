@_spi(HoldTypeIOSCore) import HoldTypePersistence

struct IOSVoiceDraftClient: Sendable {
    let load: @Sendable () async throws -> IOSVoiceDraftRecord
    let accept: @Sendable (
        IOSVoiceDraftSegment,
        IOSVoiceDraftInsertionMode
    ) async throws
        -> IOSVoiceDraftAppendResult
    let replace: @Sendable (
        IOSVoiceDraftRecord,
        IOSVoiceDraftSnapshotToken
    ) async throws -> IOSVoiceDraftMutationResult

    init(repository: IOSVoiceDraftRepository) {
        load = { try await repository.load() }
        accept = { try await repository.accept($0, mode: $1) }
        replace = { try await repository.replace($0, ifCurrent: $1) }
    }

    init(
        load: @escaping @Sendable () async throws -> IOSVoiceDraftRecord,
        accept: @escaping @Sendable (
            IOSVoiceDraftSegment,
            IOSVoiceDraftInsertionMode
        ) async throws
            -> IOSVoiceDraftAppendResult,
        replace: @escaping @Sendable (
            IOSVoiceDraftRecord,
            IOSVoiceDraftSnapshotToken
        ) async throws -> IOSVoiceDraftMutationResult
    ) {
        self.load = load
        self.accept = accept
        self.replace = replace
    }
}

enum IOSVoiceDraftState: Equatable, Sendable {
    case notLoaded
    case ready(IOSVoiceDraftRecord)
    case loadFailed(lastConfirmed: IOSVoiceDraftRecord?)

    var lastConfirmed: IOSVoiceDraftRecord? {
        switch self {
        case .notLoaded:
            nil
        case .ready(let record), .loadFailed(.some(let record)):
            record
        case .loadFailed(lastConfirmed: nil):
            nil
        }
    }
}

enum IOSVoiceDraftOperation: Equatable, Sendable {
    case idle
    case refreshing
    case appending
    case savingEdit
    case clearing
    case undoing
    case redoing
    case transforming
}

enum IOSVoiceDraftContentChangeKind: Equatable, Sendable {
    case append
    case replace
    case preservePosition
}

struct IOSVoiceDraftContentChange: Equatable, Sendable {
    let revision: Int
    let kind: IOSVoiceDraftContentChangeKind

    static let initial = IOSVoiceDraftContentChange(
        revision: 0,
        kind: .replace
    )
}
