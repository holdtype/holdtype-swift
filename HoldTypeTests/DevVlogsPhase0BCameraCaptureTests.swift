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

        #expect(
            DevVlogsPhase0BCameraFailureContext.resolve(
                startPending: true,
                firstFrameObserved: true
            ) == .starting
        )
        #expect(
            DevVlogsPhase0BCameraFailureContext.resolve(
                startPending: false,
                firstFrameObserved: false
            ) == .starting
        )
        let steadyContext = DevVlogsPhase0BCameraFailureContext.resolve(
            startPending: false,
            firstFrameObserved: true
        )
        #expect(steadyContext == .steadyCapture)

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
                    context: steadyContext
                ) == .disconnectedDuringCapture
            )
        }
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
