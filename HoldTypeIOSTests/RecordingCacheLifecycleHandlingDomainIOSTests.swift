import Foundation
import HoldTypeDomain
import Testing

struct RecordingCacheLifecycleHandlingDomainIOSTests {
    @Test func publicLifecycleContractWorksThroughANormalIOSImport() throws {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-ios-cache-lifecycle.m4a"),
            duration: 4.5,
            byteCount: 16_384
        )
        let handler = IOSRecordingCacheLifecycleSpy()
        let existential: any RecordingCacheLifecycleHandling = handler

        try existential.handleCompletedRecording(artifact, policy: .unlimited)

        #expect(handler.artifact == artifact)
        #expect(handler.policy == .unlimited)
    }
}

private final class IOSRecordingCacheLifecycleSpy: RecordingCacheLifecycleHandling {
    private(set) var artifact: AudioRecordingArtifact?
    private(set) var policy: RecordingCachePolicy?

    func handleCompletedRecording(
        _ artifact: AudioRecordingArtifact,
        policy: RecordingCachePolicy
    ) throws {
        self.artifact = artifact
        self.policy = policy
    }
}
