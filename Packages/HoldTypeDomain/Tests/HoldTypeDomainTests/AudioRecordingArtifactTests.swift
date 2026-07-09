import Foundation
import Testing
@testable import HoldTypeDomain

struct AudioRecordingArtifactTests {
    @Test func preservesTransientRuntimeMetadataWithoutNormalization() {
        let fileURL = URL(fileURLWithPath: "/tmp/holdtype-artifact.m4a")
        let artifact = AudioRecordingArtifact(
            fileURL: fileURL,
            duration: 12.5,
            byteCount: 4_096
        )

        #expect(artifact.fileURL == fileURL)
        #expect(artifact.duration == 12.5)
        #expect(artifact.byteCount == 4_096)
    }

    @Test func equalityIncludesEveryRuntimeMetadataField() {
        let fileURL = URL(fileURLWithPath: "/tmp/holdtype-artifact.m4a")
        let artifact = AudioRecordingArtifact(
            fileURL: fileURL,
            duration: 12.5,
            byteCount: 4_096
        )

        #expect(
            artifact == AudioRecordingArtifact(
                fileURL: fileURL,
                duration: 12.5,
                byteCount: 4_096
            )
        )
        #expect(
            artifact != AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/tmp/other.m4a"),
                duration: 12.5,
                byteCount: 4_096
            )
        )
        #expect(
            artifact != AudioRecordingArtifact(
                fileURL: fileURL,
                duration: 13,
                byteCount: 4_096
            )
        )
        #expect(
            artifact != AudioRecordingArtifact(
                fileURL: fileURL,
                duration: 12.5,
                byteCount: 8_192
            )
        )
    }

    @Test func publicValueIsSendable() {
        requireSendable(AudioRecordingArtifact.self)
    }

    @Test func doesNotExposeTheRuntimeURLAsACodableContract() {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-artifact.m4a"),
            duration: 12.5,
            byteCount: 4_096
        )

        #expect(((artifact as Any) is any Encodable) == false)
        #expect(((artifact as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
