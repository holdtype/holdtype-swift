import Foundation
import HoldTypeDomain
import Testing

struct AudioRecordingArtifactDomainIOSTests {
    @Test func publicArtifactContractWorksThroughANormalIOSImport() {
        let fileURL = URL(fileURLWithPath: "/tmp/holdtype-ios-artifact.m4a")
        let artifact = AudioRecordingArtifact(
            fileURL: fileURL,
            duration: 2.75,
            byteCount: 2_048
        )

        #expect(artifact.fileURL == fileURL)
        #expect(artifact.duration == 2.75)
        #expect(artifact.byteCount == 2_048)
        #expect(
            artifact == AudioRecordingArtifact(
                fileURL: fileURL,
                duration: 2.75,
                byteCount: 2_048
            )
        )
        requireSendable(AudioRecordingArtifact.self)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
