#if DEBUG
import AppKit
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BCameraAuthorizationLifecycleTests {
    @Test func terminationExtractionPreservesDeferredExactOnceBehavior() async {
        let coordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(1))
        var cancellationCount = 0
        var completionCount = 0
        let outcome = await withCheckedContinuation { continuation in
            let reply = coordinator.begin(
                cancelActive: { cancellationCount += 1 },
                cleanup: {},
                completion: { value in completionCount += 1; continuation.resume(returning: value) }
            )
            #expect(reply == .terminateLater)
        }
        #expect(outcome == .cleanupCompleted)
        #expect(cancellationCount == 1)
        #expect(completionCount == 1)
        #expect(coordinator.begin(cancelActive: {}, cleanup: {}, completion: { _ in }) == .terminateNow)
    }

    @Test func naturalCompletionStillDefersAndExternalQuitWins() {
        var queued: (@MainActor () -> Void)?
        var requests = 0
        let scheduler = DevVlogsPhase0BNaturalTerminationScheduler { queued = $0 }
        let coordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(35))
        #expect(coordinator.harnessDidComplete())
        scheduler.schedule { if coordinator.permitsNaturalTermination { requests += 1 } }
        #expect(requests == 0)
        #expect(coordinator.begin(cancelActive: {}, cleanup: {}, completion: { _ in }) == .terminateNow)
        queued?()
        #expect(requests == 0)
    }

    @Test func launchSourceUsesWillFinishPolicyAndNoTargetActivation() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let launch = try String(contentsOf: root.appendingPathComponent(
            "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BLaunch.swift"
        ), encoding: .utf8)
        let willFinish = try #require(launch.range(of: "func applicationWillFinishLaunching"))
        let didFinish = try #require(launch.range(of: "func applicationDidFinishLaunching"))
        #expect(willFinish.lowerBound < didFinish.lowerBound)
        #expect(launch.contains("setActivationPolicy(.regular)"))
        #expect(launch.contains("setActivationPolicy(.prohibited)"))
        #expect(launch.contains("makeHandshake"))
        #expect(!launch.contains("NSApplication.shared.activate"))
        #expect(!launch.contains("NSRunningApplication.current.activate"))
    }

    @Test func normalAndHardwareRoutesNeverEnterAuthorization() async {
        for environment in [[:], [DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1"]] {
            var routeCount = 0
            let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
                environment: environment,
                policyReady: false,
                activeConfirmation: .init(isActive: { true }, sleep: { _ in }, confirmationAttempts: 1),
                routeStarted: { routeCount += 1 },
                makeHarness: { throw LifecycleError.unavailable },
                makeHandshake: { _ in throw LifecycleError.unavailable }
            )
            #expect(terminal == nil)
            #expect(routeCount == 0)
        }
    }
}

private enum LifecycleError: Error { case unavailable }
#endif
