#if DEBUG
import Foundation
import XCTest
@testable import HoldType

@MainActor
final class DevVlogsPhase0BPreviewLaunchTests: XCTestCase {
    func testAbsentPreviewKeyPreservesExistingRouterSelection() {
        var previewStarts = 0
        var existingStarts = 0
        DevVlogsPhase0BPreviewLaunch.startApplication(
            environment: [:],
            startPreviewApplication: { previewStarts += 1 },
            startExistingApplication: { existingStarts += 1 }
        )
        XCTAssertEqual(previewStarts, 0)
        XCTAssertEqual(existingStarts, 1)

        var normalStarts = 0
        var harnessStarts = 0
        DevVlogsPhase0BLaunch.startApplication(
            environment: [DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1"],
            startNormalApplication: { normalStarts += 1 },
            startHarnessApplication: { harnessStarts += 1 }
        )
        XCTAssertEqual(normalStarts, 0)
        XCTAssertEqual(harnessStarts, 1)
    }

    func testPreviewRouteRequiresExactAutomationKeychainAndCameraValues() throws {
        let valid = validEnvironment()
        let configuration = try XCTUnwrap(
            try? DevVlogsPhase0BPreviewConfiguration.resolve(environment: valid).get()
        )
        XCTAssertEqual(configuration.cameraUniqueID, "selected-camera")

        var malformed = valid
        malformed[DevVlogsPhase0BPreviewConfiguration.enabledEnvironmentKey] = "true"
        XCTAssertEqual(resolveError(malformed), .invalidEnablement)
        malformed = valid
        malformed[KeychainInteractionPolicy.automationEnvironmentKey] = "true"
        XCTAssertEqual(resolveError(malformed), .automationRequired)
        malformed = valid
        malformed[KeychainInteractionPolicy.authenticationUIEnvironmentKey] = "allow"
        XCTAssertEqual(resolveError(malformed), .keychainPolicyRequired)
        malformed = valid
        malformed.removeValue(forKey: DevVlogsPhase0BPreviewConfiguration.cameraIDEnvironmentKey)
        XCTAssertEqual(resolveError(malformed), .cameraIDRequired)
    }

    func testMalformedAndConflictingPreviewValuesStayInsidePreviewApplication() {
        let malformed = [DevVlogsPhase0BPreviewConfiguration.enabledEnvironmentKey: "bad"]
        XCTAssertTrue(DevVlogsPhase0BPreviewConfiguration.shouldIsolate(environment: malformed))
        var previewStarts = 0
        var existingStarts = 0
        DevVlogsPhase0BPreviewLaunch.startApplication(
            environment: malformed,
            startPreviewApplication: { previewStarts += 1 },
            startExistingApplication: { existingStarts += 1 }
        )
        XCTAssertEqual(previewStarts, 1)
        XCTAssertEqual(existingStarts, 0)

        var captureConflict = validEnvironment()
        captureConflict[DevVlogsPhase0BConfiguration.enabledEnvironmentKey] = "1"
        XCTAssertEqual(resolveError(captureConflict), .conflictingHarnessRoute)
        var authorizationConflict = validEnvironment()
        authorizationConflict[
            DevVlogsPhase0BCameraAuthorizationConfiguration.enabledEnvironmentKey
        ] = "1"
        XCTAssertEqual(resolveError(authorizationConflict), .conflictingHarnessRoute)
    }

    func testValidPreviewConstructsOnlyThePreviewComposition() throws {
        var previewStarts = 0
        var existingStarts = 0
        DevVlogsPhase0BPreviewLaunch.startApplication(
            environment: validEnvironment(),
            startPreviewApplication: { previewStarts += 1 },
            startExistingApplication: { existingStarts += 1 }
        )
        XCTAssertEqual(previewStarts, 1)
        XCTAssertEqual(existingStarts, 0)

        let source = try ownedSource("DevVlogsPhase0BPreviewView.swift")
        let application = try XCTUnwrap(source.range(of: "struct DevVlogsPhase0BPreviewApplication"))
        let tail = source[application.lowerBound...]
        let end = try XCTUnwrap(tail.range(of: "private struct DevVlogsPhase0BPreviewRoot"))
        let composition = tail[..<end.lowerBound]
        XCTAssertTrue(composition.contains("WindowGroup"))
        XCTAssertTrue(composition.contains("CommandGroup(replacing: .newItem)"))
        XCTAssertFalse(composition.contains("MenuBarExtra"))
        XCTAssertFalse(composition.contains("SettingsScene"))
        XCTAssertFalse(composition.contains("HoldTypeAppDelegate"))
        XCTAssertFalse(source.contains("NSWindow"))
        XCTAssertFalse(source.contains("NSPanel"))
        XCTAssertFalse(source.contains("NSViewRepresentable"))
    }

    func testPreviewRouterRunsBeforeTheAcceptedHarnessRouter() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("HoldType/HoldTypeApp.swift"),
            encoding: .utf8
        )
        let entry = try XCTUnwrap(source.range(of: "private enum HoldTypeDebugEntryPoint"))
        let tail = source[entry.lowerBound...]
        let preview = try XCTUnwrap(tail.range(of: "DevVlogsPhase0BPreviewLaunch.startApplication"))
        let harness = try XCTUnwrap(tail.range(of: "DevVlogsPhase0BLaunch.startApplication"))
        XCTAssertLessThan(preview.lowerBound, harness.lowerBound)
    }

    private func validEnvironment() -> [String: String] {
        [
            DevVlogsPhase0BPreviewConfiguration.enabledEnvironmentKey: "1",
            DevVlogsPhase0BPreviewConfiguration.cameraIDEnvironmentKey: "selected-camera",
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }

    private func resolveError(
        _ environment: [String: String]
    ) -> DevVlogsPhase0BPreviewLaunchError? {
        guard case .failure(let error) = DevVlogsPhase0BPreviewConfiguration.resolve(
            environment: environment
        ) else { return nil }
        return error
    }

    private func ownedSource(_ name: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/\(name)"
            ),
            encoding: .utf8
        )
    }
}
#endif
