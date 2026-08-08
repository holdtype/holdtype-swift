#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BCameraCaptureTests {
    @Test func steadyDisconnectCleansUpAndTerminatesExactlyOnce() async {
        await assertSteadyFailure(.disconnectedDuringCapture)
    }

    @Test func steadyRuntimeFailureCleansUpAndIgnoresLateDuplicate() async {
        await assertSteadyFailure(.runtimeFailure)
    }

    @Test func everyCameraErrorMapsToAClosedRedactedCategory() {
        let expected: [(DevVlogsPhase0BCameraCaptureError, DevVlogsPhase0BFailureCategory)] = [
            (.permissionRequired, .cameraPermissionRequired),
            (.permissionDenied, .cameraPermissionDenied),
            (.preferredDeviceDisconnected, .cameraSelectionDisconnected),
            (.preferredDeviceBusy, .cameraSelectionBusy),
            (.unsupportedCandidatePreset, .cameraConfigurationPreset),
            (.videoInputUnavailable, .cameraConfigurationVideoInput),
            (.movieOutputUnavailable, .cameraConfigurationMovieOutput),
            (.sampleOutputUnavailable, .cameraConfigurationSampleOutput),
            (.setupTimedOut, .cameraStartTimedOut),
            (.firstFrameUnavailable, .cameraFirstFrameUnavailable),
            (.recordingFailed, .cameraRecordingFailed),
            (.disconnectedDuringCapture, .cameraInterruptionDisconnected),
            (.runtimeFailure, .cameraSessionRuntimeFailure),
            (.notCapturing, .cameraSessionNotCapturing),
        ]

        for (error, category) in expected {
            #expect(error.redactedCategory == category)
        }
        #expect(Set(expected.map { $0.1.rawValue }).count == expected.count)
    }

    @Test func unknownPlatformErrorMapsWithoutPrivateErrorMaterial() {
        let privateToken = "private-device-serial-and-path"
        let error = NSError(
            domain: privateToken,
            code: 91,
            userInfo: [NSLocalizedDescriptionKey: privateToken]
        )
        let category = DevVlogsPhase0BCameraCaptureError.redactedCategory(for: error)

        #expect(category == .cameraUnknown)
        #expect(!category.rawValue.contains(privateToken))
        #expect(DevVlogsPhase0BFailureCategory.allCases.allSatisfy {
            !$0.rawValue.contains("/") && !$0.rawValue.contains(" ")
        })
    }

    private func assertSteadyFailure(
        _ failure: DevVlogsPhase0BCameraCaptureError
    ) async {
        let terminator = DevVlogsPhase0BSteadyCaptureTerminator()
        var cleanupCount = 0
        terminator.arm()

        #expect(terminator.terminate(with: failure) { cleanupCount += 1 })
        #expect(!terminator.terminate(with: failure) { cleanupCount += 1 })
        #expect(await terminator.waitForFailure() == failure)
        #expect(terminator.phase == .terminal)
        #expect(cleanupCount == 1)

        #expect(!terminator.terminate(with: failure) { cleanupCount += 1 })
        #expect(await terminator.waitForFailure() == failure)
        #expect(cleanupCount == 1)
    }
}
#endif
