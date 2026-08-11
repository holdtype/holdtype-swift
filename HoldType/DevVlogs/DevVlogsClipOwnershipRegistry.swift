import Foundation

enum DevVlogsClipOperation: Equatable {
    case active
    case finalizing
    case recovering
    case building
    case deleting
}

@MainActor
final class DevVlogsClipOwnershipLease {
    private weak var registry: DevVlogsClipOwnershipRegistry?
    private let clipIDs: Set<UUID>
    private var operation: DevVlogsClipOperation
    private var isReleased = false

    init(
        registry: DevVlogsClipOwnershipRegistry,
        clipIDs: Set<UUID>,
        operation: DevVlogsClipOperation
    ) {
        self.registry = registry
        self.clipIDs = clipIDs
        self.operation = operation
    }

    func release() {
        guard !isReleased else { return }
        isReleased = true
        registry?.release(clipIDs: clipIDs, operation: operation)
    }

    func transition(to newOperation: DevVlogsClipOperation) {
        guard !isReleased, operation != newOperation else { return }
        registry?.transition(
            clipIDs: clipIDs,
            from: operation,
            to: newOperation
        )
        operation = newOperation
    }
}

@MainActor
final class DevVlogsClipOwnershipRegistry {
    static let shared = DevVlogsClipOwnershipRegistry()

    private var operations: [UUID: DevVlogsClipOperation] = [:]

    func acquire(
        clipIDs: Set<UUID>,
        operation: DevVlogsClipOperation
    ) -> DevVlogsClipOwnershipLease? {
        guard !clipIDs.isEmpty,
              clipIDs.allSatisfy({ operations[$0] == nil }) else {
            return nil
        }
        for clipID in clipIDs {
            operations[clipID] = operation
        }
        return DevVlogsClipOwnershipLease(
            registry: self,
            clipIDs: clipIDs,
            operation: operation
        )
    }

    func operation(for clipID: UUID) -> DevVlogsClipOperation? {
        operations[clipID]
    }

    fileprivate func release(
        clipIDs: Set<UUID>,
        operation: DevVlogsClipOperation
    ) {
        for clipID in clipIDs where operations[clipID] == operation {
            operations.removeValue(forKey: clipID)
        }
    }

    fileprivate func transition(
        clipIDs: Set<UUID>,
        from oldOperation: DevVlogsClipOperation,
        to newOperation: DevVlogsClipOperation
    ) {
        for clipID in clipIDs where operations[clipID] == oldOperation {
            operations[clipID] = newOperation
        }
    }
}
