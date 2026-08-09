#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BStorageTestHostLaunchTests {
    @Test func absentStorageVariablesPreserveTheAcceptedRouter() {
        var storageStarts = 0
        var existingStarts = 0
        DevVlogsPhase0BStorageTestHostLaunch.startApplication(
            environment: [:],
            startStorageApplication: { storageStarts += 1 },
            startExistingApplication: { existingStarts += 1 }
        )
        #expect(storageStarts == 0)
        #expect(existingStarts == 1)
    }

    @Test func completeClosedConfigurationSelectsTheInertHost() throws {
        let environment = validEnvironment()
        let configuration = try #require(
            try? DevVlogsPhase0BStorageTestHostConfiguration.resolve(
                environment: environment
            ).get()
        )
        #expect(configuration.volumeRoot == "/Volumes/redacted-fixture")
        #expect(configuration.destinationClass == "external-ssd")
        #expect(configuration.filesystemClass == "apfs")
        #expect(configuration.caseID == "mechanics_case")
        #expect(configuration.runID == runID)

        let state = DevVlogsPhase0BStorageTestHostState(environment: environment)
        #expect(state.configuration == .success(configuration))
    }

    @Test func everyMissingOrEmptyClosedInputStaysInertWithTypedFailure() {
        let valid = validEnvironment()
        for key in DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnvironmentKeys {
            var missing = valid
            missing.removeValue(forKey: key)
            assertIsolatedFailure(missing, expected: .missingRuntimeValue(key))
            var empty = valid
            empty[key] = ""
            assertIsolatedFailure(empty, expected: .missingRuntimeValue(key))
        }

        var missingHost = valid
        missingHost.removeValue(
            forKey: DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey
        )
        assertIsolatedFailure(missingHost, expected: .invalidHostEnablement)
        var emptyHost = valid
        emptyHost[DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey] = ""
        assertIsolatedFailure(emptyHost, expected: .invalidHostEnablement)
        var missingAutomation = valid
        missingAutomation.removeValue(forKey: KeychainInteractionPolicy.automationEnvironmentKey)
        assertIsolatedFailure(missingAutomation, expected: .automationRequired)
        var emptyAutomation = valid
        emptyAutomation[KeychainInteractionPolicy.automationEnvironmentKey] = ""
        assertIsolatedFailure(emptyAutomation, expected: .automationRequired)
        var missingKeychain = valid
        missingKeychain.removeValue(
            forKey: KeychainInteractionPolicy.authenticationUIEnvironmentKey
        )
        assertIsolatedFailure(missingKeychain, expected: .keychainPolicyRequired)
        var emptyKeychain = valid
        emptyKeychain[KeychainInteractionPolicy.authenticationUIEnvironmentKey] = ""
        assertIsolatedFailure(emptyKeychain, expected: .keychainPolicyRequired)
    }

    @Test func malformedClosedInputsStayInertWithTypedFailures() {
        let cases: [(String, String, DevVlogsPhase0BStorageTestHostLaunchError)] = [
            (DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey,
             "true", .invalidHostEnablement),
            (KeychainInteractionPolicy.automationEnvironmentKey,
             "true", .automationRequired),
            (KeychainInteractionPolicy.authenticationUIEnvironmentKey,
             "allow", .keychainPolicyRequired),
            (DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnableEnvironmentKey,
             "yes", .invalidRuntimeEnablement),
            (DevVlogsPhase0BStorageTestHostConfiguration.volumeRootEnvironmentKey,
             "/", .invalidVolumeRoot),
            (DevVlogsPhase0BStorageTestHostConfiguration.destinationClassEnvironmentKey,
             "external", .invalidDestinationClass),
            (DevVlogsPhase0BStorageTestHostConfiguration.filesystemClassEnvironmentKey,
             "unknown", .invalidFilesystemClass),
            (DevVlogsPhase0BStorageTestHostConfiguration.caseIDEnvironmentKey,
             "bad case", .invalidCaseID),
            (DevVlogsPhase0BStorageTestHostConfiguration.runIDEnvironmentKey,
             runID.uuidString, .invalidRunID),
        ]
        for (key, value, expected) in cases {
            var environment = validEnvironment()
            environment[key] = value
            assertIsolatedFailure(environment, expected: expected)
        }
    }

    @Test func captureAuthorizationAndPreviewConflictsStayInsideTheInertHost() {
        let conflictKeys = [
            DevVlogsPhase0BConfiguration.enabledEnvironmentKey,
            DevVlogsPhase0BConfiguration.runRootEnvironmentKey,
            DevVlogsPhase0BConfiguration.cameraUniqueIDEnvironmentKey,
            DevVlogsPhase0BConfiguration.durationEnvironmentKey,
            DevVlogsPhase0BConfiguration.caseIDEnvironmentKey,
            DevVlogsPhase0BConfiguration.eventLogEnvironmentKey,
            DevVlogsPhase0BCameraAuthorizationConfiguration.enabledEnvironmentKey,
            DevVlogsPhase0BCameraAuthorizationConfiguration.launchTokenEnvironmentKey,
            DevVlogsPhase0BPreviewConfiguration.enabledEnvironmentKey,
            DevVlogsPhase0BPreviewConfiguration.cameraIDEnvironmentKey,
        ]
        for key in conflictKeys {
            var environment = validEnvironment()
            environment[key] = "1"
            assertIsolatedFailure(environment, expected: .conflictingRoute)
        }
    }

    @Test func inertSelectionConstructsNoExistingOwnerAndPerformsNoStorageAction() {
        for environment in [
            validEnvironment(),
            [DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey: "bad"],
            validEnvironment().merging([
                DevVlogsPhase0BPreviewConfiguration.enabledEnvironmentKey: "1"
            ]) { _, new in new },
        ] {
            var storageHosts = 0
            var previewOwners = 0
            var captureOwners = 0
            var authorizationOwners = 0
            var appDelegates = 0
            var runtimes = 0
            var productScenes = 0
            var recoveryOwners = 0
            var filesystemActions = 0
            DevVlogsPhase0BStorageTestHostLaunch.startApplication(
                environment: environment,
                startStorageApplication: { storageHosts += 1 },
                startExistingApplication: {
                    previewOwners += 1
                    captureOwners += 1
                    authorizationOwners += 1
                    appDelegates += 1
                    runtimes += 1
                    productScenes += 1
                    recoveryOwners += 1
                    filesystemActions += 1
                }
            )
            #expect(storageHosts == 1)
            #expect(previewOwners == 0 && captureOwners == 0 && authorizationOwners == 0)
            #expect(appDelegates == 0 && runtimes == 0 && productScenes == 0)
            #expect(recoveryOwners == 0 && filesystemActions == 0)
        }
    }

    @Test func inertApplicationContainsNoProductOrFilesystemOwner() throws {
        let source = try ownedSource("DevVlogsPhase0BStorageTestHostLaunch.swift")
        let application = try #require(
            source.range(of: "struct DevVlogsPhase0BStorageTestHostApplication: App")
        )
        let composition = source[application.lowerBound...]
        #expect(composition.contains("Settings"))
        #expect(composition.contains("EmptyView"))
        for forbidden in [
            "MenuBarExtra", "WindowGroup", "HoldTypeAppDelegate", "DictationRuntime",
            "TranscriptionFailureRecoveryStore", "SettingsScene", "FixesEditorScene",
            "TranscriptHistoryScene", "DevVlogsPhase0BPreviewApplication",
            "DevVlogsPhase0BHarnessApplication", "FileManager", "resourceValues",
            "createDirectory", "Data(contentsOf:", "DiskArbitration", "IOKit", "AppKit",
        ] {
            #expect(!composition.contains(forbidden))
        }
    }

    @Test func storageRouterRunsBeforeEveryAcceptedDebugComposition() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("HoldType/HoldTypeApp.swift"),
            encoding: .utf8
        )
        let entry = try #require(source.range(of: "private enum HoldTypeDebugEntryPoint"))
        let tail = source[entry.lowerBound...]
        let storage = try #require(
            tail.range(of: "DevVlogsPhase0BStorageTestHostLaunch.startApplication")
        )
        let preview = try #require(
            tail.range(of: "DevVlogsPhase0BPreviewLaunch.startApplication")
        )
        let harness = try #require(tail.range(of: "DevVlogsPhase0BLaunch.startApplication"))
        let normal = try #require(tail.range(of: "HoldTypeApp.main()"))
        #expect(storage.lowerBound < preview.lowerBound)
        #expect(preview.lowerBound < harness.lowerBound)
        #expect(harness.lowerBound < normal.lowerBound)
    }

    @Test func testSuiteRuntimeConfigurationMatchesTheClosedHostInputs() throws {
        let valid = validEnvironment()
        let loaded = try DevVlogsExternalStorageRuntimeConfiguration.load(environment: valid)
        let configuration = try #require(loaded)
        #expect(configuration.runID == runID)
        #expect(configuration.caseID == "mechanics_case")
        #expect(configuration.authorization.destinationClass == .externalSSD)
        #expect(configuration.authorization.filesystemClass == .apfs)
        for key in DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnvironmentKeys {
            var missing = valid
            missing.removeValue(forKey: key)
            #expect(throws: DevVlogsStorageHarnessError.invalidRuntimeConfiguration) {
                _ = try DevVlogsExternalStorageRuntimeConfiguration.load(environment: missing)
            }
        }
    }

    private let runID = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!

    private func validEnvironment() -> [String: String] {
        [
            DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey: "1",
            DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnableEnvironmentKey: "execute",
            DevVlogsPhase0BStorageTestHostConfiguration.volumeRootEnvironmentKey:
                "/Volumes/redacted-fixture",
            DevVlogsPhase0BStorageTestHostConfiguration.destinationClassEnvironmentKey:
                "external-ssd",
            DevVlogsPhase0BStorageTestHostConfiguration.filesystemClassEnvironmentKey: "apfs",
            DevVlogsPhase0BStorageTestHostConfiguration.caseIDEnvironmentKey: "mechanics_case",
            DevVlogsPhase0BStorageTestHostConfiguration.runIDEnvironmentKey:
                runID.uuidString.lowercased(),
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }

    private func assertIsolatedFailure(
        _ environment: [String: String],
        expected: DevVlogsPhase0BStorageTestHostLaunchError
    ) {
        #expect(
            DevVlogsPhase0BStorageTestHostConfiguration.shouldIsolate(environment: environment)
        )
        #expect(
            DevVlogsPhase0BStorageTestHostConfiguration.resolve(environment: environment)
                == .failure(expected)
        )
        let state = DevVlogsPhase0BStorageTestHostState(environment: environment)
        #expect(state.configuration == .failure(expected))
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
