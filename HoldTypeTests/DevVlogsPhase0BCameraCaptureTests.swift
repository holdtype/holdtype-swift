#if DEBUG
@preconcurrency import AVFoundation
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
            (.deviceUnavailableDuringStart, .cameraStartDeviceUnavailable),
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
            (.unknownPlatformFailure, .cameraUnknown),
            (.notCapturing, .cameraSessionNotCapturing),
        ]

        for (error, category) in expected {
            #expect(error.redactedCategory == category)
        }
        #expect(Set(expected.map { $0.1.rawValue }).count == expected.count)
    }

    @Test func rawAVFoundationAuthorizationAndBusyCodesMapByDomainAndCode() {
        let expected: [(Int, DevVlogsPhase0BCameraCaptureError)] = [
            (AVError.applicationIsNotAuthorized.rawValue, .permissionDenied),
            (AVError.applicationIsNotAuthorizedToUseDevice.rawValue, .permissionDenied),
            (AVError.deviceInUseByAnotherApplication.rawValue, .preferredDeviceBusy),
            (AVError.deviceAlreadyUsedByAnotherSession.rawValue, .preferredDeviceBusy),
            (AVError.deviceLockedForConfigurationByAnotherProcess.rawValue, .preferredDeviceBusy),
        ]

        for (code, classification) in expected {
            let error = NSError(domain: AVFoundationErrorDomain, code: code)
            #expect(
                DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                    error,
                    context: .starting
                ) == classification
            )
        }
    }

    @Test func rawDisconnectCodesUseStartAndSteadyCaptureContext() {
        let disconnectCodes = [
            AVError.deviceWasDisconnected.rawValue,
            AVError.deviceNotConnected.rawValue,
        ]

        for code in disconnectCodes {
            let error = NSError(domain: AVFoundationErrorDomain, code: code)
            #expect(
                DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                    error,
                    context: .starting
                ) == .deviceUnavailableDuringStart
            )
            #expect(
                DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                    error,
                    context: .steadyCapture
                ) == .disconnectedDuringCapture
            )
        }
    }

    @Test func observerFailuresBeforeRecordingCallbacksRemainFirstAndTerminal() {
        let disconnect = DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
            NSError(domain: AVFoundationErrorDomain, code: AVError.deviceNotConnected.rawValue),
            context: .starting
        )
        let runtime = DevVlogsPhase0BCameraCapture.classifyRuntimeNotification(
            Notification(name: AVCaptureSession.runtimeErrorNotification),
            context: .starting
        )
        let failures: [DevVlogsPhase0BCameraCaptureError] = [
            disconnect, runtime,
        ]

        for failure in failures {
            var evidence = DevVlogsPhase0BCameraStartEvidence()
            evidence.fail(failure)
            evidence.fail(.recordingFailed)
            evidence.recordingDidStart(at: 2)
            evidence.firstFrameDidArrive(at: 3, presentationTime: 0)
            #expect(evidence.resolution == .failed(failure))
        }
        #expect(disconnect == .deviceUnavailableDuringStart)
        #expect(runtime == .runtimeFailure)
    }

    @Test func movieStartThenDisconnectBeforeFirstFrameFailsWithStartCategory() {
        var evidence = DevVlogsPhase0BCameraStartEvidence()
        evidence.recordingDidStart(at: 2)
        evidence.fail(.deviceUnavailableDuringStart)
        evidence.firstFrameDidArrive(at: 3, presentationTime: 0)

        #expect(evidence.resolution == .failed(.deviceUnavailableDuringStart))
        #expect(evidence.recordingStartTime == 2)
        #expect(evidence.firstFrameTime == nil)
    }

    @Test func recordingAndFirstFrameInEitherOrderResolveStartExactlyOnce() {
        var recordingFirst = DevVlogsPhase0BCameraStartEvidence()
        recordingFirst.recordingDidStart(at: 2)
        #expect(recordingFirst.resolution == .pending)
        recordingFirst.firstFrameDidArrive(at: 3, presentationTime: 0.1)
        recordingFirst.fail(.deviceUnavailableDuringStart)

        var frameFirst = DevVlogsPhase0BCameraStartEvidence()
        frameFirst.firstFrameDidArrive(at: 3, presentationTime: 0.1)
        #expect(frameFirst.resolution == .pending)
        frameFirst.recordingDidStart(at: 2)
        frameFirst.recordingDidStart(at: 4)

        #expect(recordingFirst.resolution == .ready)
        #expect(frameFirst.resolution == .ready)
        #expect(frameFirst.recordingStartTime == 2)
        #expect(frameFirst.firstFrameTime == 3)
    }

    @Test func noFirstFrameTimeoutIsDistinctFromPreRecordingTimeout() {
        var beforeRecording = DevVlogsPhase0BCameraStartEvidence()
        beforeRecording.timeout()
        #expect(beforeRecording.resolution == .failed(.setupTimedOut))

        var afterRecording = DevVlogsPhase0BCameraStartEvidence()
        afterRecording.recordingDidStart(at: 2)
        afterRecording.timeout()
        #expect(afterRecording.resolution == .failed(.firstFrameUnavailable))
    }

    @Test func foreignDomainCollisionsAndUnknownCodesRemainUnknown() {
        let recognizedCodes = [
            AVError.applicationIsNotAuthorized.rawValue,
            AVError.applicationIsNotAuthorizedToUseDevice.rawValue,
            AVError.deviceWasDisconnected.rawValue,
            AVError.deviceNotConnected.rawValue,
            AVError.deviceInUseByAnotherApplication.rawValue,
            AVError.deviceAlreadyUsedByAnotherSession.rawValue,
            AVError.deviceLockedForConfigurationByAnotherProcess.rawValue,
        ]

        for code in recognizedCodes {
            let collision = NSError(domain: "foreign.camera.domain", code: code)
            #expect(
                DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                    collision,
                    context: .starting
                ) == .unknownPlatformFailure
            )
        }
        let unknownAVFoundation = NSError(domain: AVFoundationErrorDomain, code: -11_899)
        let unknownForeign = NSError(domain: "foreign.camera.domain", code: 91)
        #expect(
            DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                unknownAVFoundation,
                context: .steadyCapture
            ) == .unknownPlatformFailure
        )
        #expect(
            DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                unknownForeign,
                context: .steadyCapture
            ) == .unknownPlatformFailure
        )
    }

    @Test func rawClassifierDropsPrivateErrorMaterialBeforeEvidenceCategory() throws {
        let privateToken = "private-device-serial-and-path"
        let error = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.applicationIsNotAuthorizedToUseDevice.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: privateToken,
                NSUnderlyingErrorKey: NSError(domain: privateToken, code: 7),
                "private_path": "/Users/private/\(privateToken)",
            ]
        )
        let classification = DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
            error,
            context: .starting
        )
        let category = classification.redactedCategory
        let encoded = try String(decoding: JSONEncoder().encode(category), as: UTF8.self)

        #expect(classification == .permissionDenied)
        #expect(category == .cameraPermissionDenied)
        #expect(!encoded.contains(privateToken))
        #expect(!encoded.contains("/Users/"))
        #expect(!encoded.contains("NSError"))
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
