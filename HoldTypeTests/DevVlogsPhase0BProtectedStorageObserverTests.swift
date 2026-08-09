#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BProtectedStorageObserverTests {
    private let runID = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!
    private let taskHome = URL(fileURLWithPath: "/private/tmp/holdtype-observer-fixture")

    @Test func sixMarkerWireValuesAndFiveDeletionMappingsAreClosed() {
        let markerValues = DevVlogsPhase0BProtectedStorageObserverAction.allCases
            .map(\.rawValue).filter { $0.contains("marker") }
        #expect(Set(markerValues) == Set([
            "write_saved_state_marker", "write_processing_checkpoint_marker",
            "write_provider_dispatch_marker", "delete_saved_state_marker",
            "delete_processing_checkpoint_marker", "delete_provider_dispatch_marker",
        ]))
        #expect(RecoveryArtifactDeletionKind.allCases.count == 5)
        #expect(RecoveryArtifactDeletionKind.failedAttemptEmergencyAudio.observation.action
            == .deleteRecoveryAudio)
        #expect(RecoveryArtifactDeletionKind.savedStateRepairMarker.observation.action
            == .deleteSavedStateMarker)
        #expect(RecoveryArtifactDeletionKind.processingCheckpointMarker.observation.action
            == .deleteProcessingCheckpointMarker)
        #expect(RecoveryArtifactDeletionKind.providerDispatchMarker.observation.action
            == .deleteProviderDispatchMarker)
        #expect(RecoveryArtifactDeletionKind.managedRecoveryAudio.observation.action
            == .deleteRecoveryAudio)
    }

    @Test func streamUsesFixedSchemaOrderAndValueFreeTargets() throws {
        var lines: [String] = []
        let observer = configuredObserver { lines.append($0) }
        observer.recordOwnerInitialization(
            directoryURL: taskHome.appendingPathComponent("private-name"))
        _ = try observer.observeMutation(
            action: .replaceRecoveryIndex,
            category: .recoveryIndex,
            targetURL: URL(fileURLWithPath: "/Users/redacted/Library/private-name")
        ) { 7 }
        #expect(lines.count == 4)
        #expect(lines[0].contains("\"sequence\":1,\"event\":\"observer_ready\""))
        #expect(lines[1].contains("\"target_scope\":\"private_task_home\""))
        #expect(lines[2].contains("\"result\":\"attempted\""))
        #expect(lines[3].contains("\"result\":\"succeeded\""))
        for line in lines {
            #expect(line.hasPrefix(DevVlogsPhase0BProtectedStorageObserver.prefix))
            #expect(line.utf8.count <= DevVlogsPhase0BProtectedStorageObserver.maximumLineBytes)
            for forbidden in ["private-name", "Recovery.json", "TranscriptionRecovery",
                              "/Users/", "/private/tmp/"] {
                #expect(!line.contains(forbidden))
            }
        }
    }

    @Test func failedOperationIsRethrownAndPairedWithoutProductSubstitution() {
        enum Sentinel: Error { case exact }
        var lines: [String] = []
        let observer = configuredObserver { lines.append($0) }
        #expect(throws: Sentinel.exact) {
            try observer.observeMutation(
                action: .copyRecoveryAudio, category: .recoveryAudio,
                targetURL: taskHome.appendingPathComponent("audio")) {
                    throw Sentinel.exact
                }
        }
        #expect(lines.count == 3)
        #expect(lines[1].contains("\"result\":\"attempted\""))
        #expect(lines[2].contains("\"result\":\"failed\""))
    }

    @Test func overflowInvalidatesEvidenceWithoutThrowingIntoProductFlow() throws {
        var lines: [String] = []
        let observer = configuredObserver { lines.append($0) }
        for _ in 1 ... 70 {
            _ = try observer.observeMutation(
                action: .ensureRecoveryDirectory, category: .recoveryDirectory,
                targetURL: taskHome.appendingPathComponent("directory")) { true }
        }
        #expect(observer.evidenceInvalidated)
        #expect(lines.count == DevVlogsPhase0BProtectedStorageObserver.maximumEvents)
        #expect(lines.last?.contains("\"event\":\"observer_overflow\"") == true)
    }

    private func configuredObserver(
        sink: @escaping (String) -> Void
    ) -> DevVlogsPhase0BProtectedStorageObserver {
        let observer = DevVlogsPhase0BProtectedStorageObserver()
        observer.resetForTesting(sink: sink)
        observer.install(.init(runID: runID, taskHome: taskHome))
        return observer
    }
}
#endif
