import Foundation
import Testing
@testable import HoldTypeDomain

struct RecordingCacheLifecycleHandlingTests {
    @Test func existentialReceivesTheExactArtifactAndRawPolicy() throws {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-cache-lifecycle.m4a"),
            duration: 3.25,
            byteCount: 8_192
        )
        let handler = RecordingCacheLifecycleSpy()

        try invoke(handler, artifact: artifact, policy: .keepLast(0))

        #expect(handler.calls == [
            .init(artifact: artifact, policy: .keepLast(0))
        ])
    }

    @Test func existentialPreservesAdapterFailures() {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-cache-failure.m4a"),
            duration: 1,
            byteCount: 1
        )
        let handler = RecordingCacheLifecycleSpy(error: .sampleFailure)

        #expect(throws: RecordingCacheLifecycleTestError.sampleFailure) {
            try invoke(handler, artifact: artifact, policy: .deleteImmediately)
        }
    }

    private func invoke(
        _ handler: any RecordingCacheLifecycleHandling,
        artifact: AudioRecordingArtifact,
        policy: RecordingCachePolicy
    ) throws {
        try handler.handleCompletedRecording(artifact, policy: policy)
    }
}

private enum RecordingCacheLifecycleTestError: Error {
    case sampleFailure
}

private final class RecordingCacheLifecycleSpy: RecordingCacheLifecycleHandling {
    struct Call: Equatable {
        let artifact: AudioRecordingArtifact
        let policy: RecordingCachePolicy
    }

    private(set) var calls: [Call] = []
    private let error: RecordingCacheLifecycleTestError?

    init(error: RecordingCacheLifecycleTestError? = nil) {
        self.error = error
    }

    func handleCompletedRecording(
        _ artifact: AudioRecordingArtifact,
        policy: RecordingCachePolicy
    ) throws {
        if let error {
            throw error
        }

        calls.append(.init(artifact: artifact, policy: policy))
    }
}
