#if DEBUG
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
