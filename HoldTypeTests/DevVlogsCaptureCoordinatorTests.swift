import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct DevVlogsCaptureCoordinatorTests {
    private let audioArtifact = AudioRecordingArtifact(
        fileURL: URL(fileURLWithPath: "/tmp/finalized-dictation.m4a"),
        duration: 3,
        byteCount: 2_048
    )

    @Test func cameraOperationGateReturnsAtItsBoundAndCancelsPendingWork() async {
        let gate = DevVlogsCameraStartOperationGate()
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: DevVlogsCameraCaptureError.startFailed) {
            try await gate.wait(
                timeout: .milliseconds(20),
                operation: {
                    try await Task.sleep(for: .seconds(10))
                },
                onLateSuccess: {}
            )
        }

        #expect(clock.now - start < .seconds(1))
    }

    @Test func disabledAndIneligibleAttemptsSkipBeforeCameraOrDestination() async throws {
        let disabled = try DevVlogsCaptureFixture(enabled: false)
        await disabled.coordinator.beginAttempt()

        #expect(disabled.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
        #expect(disabled.camera.startCameraIDs.isEmpty)
        #expect(disabled.archive.prepareCount == 0)

        let ineligible = try DevVlogsCaptureFixture(policy: .defaultPolicy)
        await ineligible.coordinator.beginAttempt()

        #expect(ineligible.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .triggerApplicationIneligible
        ))
        #expect(ineligible.camera.startCameraIDs.isEmpty)
        #expect(ineligible.archive.prepareCount == 0)
    }

    @Test func unavailableDestinationSkipsWithoutStartingOrFallingBack() async throws {
        let fixture = try DevVlogsCaptureFixture(destinationAvailable: false)

        await fixture.coordinator.beginAttempt()

        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .destinationUnavailable
        ))
        #expect(fixture.camera.startCameraIDs.isEmpty)
        #expect(fixture.archive.prepareCount == 0)
    }

    @Test func preferredCameraFailureSkipsWithoutTryingAnotherCamera() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.camera.startError = DevVlogsCameraCaptureError.cameraBusy

        await fixture.coordinator.beginAttempt()

        #expect(fixture.camera.startCameraIDs == [DevVlogsCaptureFixture.preferredCamera.id])
        #expect(fixture.archive.abandonCount == 1)
        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .preferredCameraUnavailable
        ))
    }

    @Test func frozenSnapshotPublishesOnceAndReleasesTheAudioLeaseOnce() async throws {
        let fixture = try DevVlogsCaptureFixture()
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        fixture.settings.setPreferredCamera(.init(id: "later-camera", label: "Later"))
        fixture.trigger.application = .init(bundleIdentifier: "com.example.later", displayName: "Later")

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(fixture.camera.stopIDs == [fixture.camera.captureID])
        #expect(fixture.leases.acquireCount == 1)
        #expect(fixture.leases.releaseCount == 1)
        #expect(fixture.archive.stageCount == 1)
        #expect(fixture.finalizer.callCount == 1)
        #expect(fixture.archive.publishSnapshots.count == 1)
        #expect(fixture.archive.publishSnapshots.first?.preferredCamera == DevVlogsCaptureFixture.preferredCamera)
        #expect(fixture.archive.publishSnapshots.first?.triggerApplication == DevVlogsCaptureFixture.triggerApplication)
        #expect(fixture.coordinator.state == .saved(clipID: DevVlogsCaptureFixture.attemptID))
    }

    @Test func finalizerFailureIsTerminalWithoutPublicationAndKeepsFragmentsOwnedByArchive() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.finalizer.error = DevVlogsMediaFinalizerError.passthroughUnavailable
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(fixture.leases.releaseCount == 1)
        #expect(fixture.archive.stageCount == 1)
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.archive.abandonCount == 0)
        #expect(fixture.coordinator.state == .failed(
            attemptID: DevVlogsCaptureFixture.attemptID,
            message: "The captured video could not be finalized without re-encoding."
        ))
    }

    @Test func audioLeaseReleasesWhenStagingFails() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.archive.stageError = DevVlogsCaptureTestError.expectedFailure
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)

        #expect(fixture.leases.acquireCount == 1)
        #expect(fixture.leases.releaseCount == 1)
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.coordinator.state == .failed(
            attemptID: DevVlogsCaptureFixture.attemptID,
            message: "The vlog clip could not be saved."
        ))
    }

    @Test func endingWithoutAudioCancelsOnceAndNeverAcquiresTheLease() async throws {
        let fixture = try DevVlogsCaptureFixture()
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        await Task.yield()

        #expect(fixture.camera.cancelIDs == [fixture.camera.captureID])
        #expect(fixture.leases.acquireCount == 0)
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.archive.publishSnapshots.isEmpty)
    }

    @Test func customDestinationAccessReleasesOnSkippedTerminal() async throws {
        let fixture = try DevVlogsCaptureFixture(usesCustomDestination: true)
        let initialStartCount = fixture.bookmarks.startCount
        let initialStopCount = fixture.bookmarks.stopCount
        await fixture.coordinator.beginAttempt()

        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        await Task.yield()

        #expect(fixture.bookmarks.startCount == initialStartCount + 1)
        #expect(fixture.bookmarks.stopCount == initialStopCount + 1)
    }
}
