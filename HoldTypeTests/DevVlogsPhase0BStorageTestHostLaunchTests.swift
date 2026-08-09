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
        let validation = try #require(
            try? DevVlogsPhase0BStorageTestHostConfiguration.resolve(
                environment: environment
            ).get()
        )
        #expect(validation == .validated)
        #expect(Mirror(reflecting: validation).children.isEmpty)

        let state = DevVlogsPhase0BStorageTestHostState(environment: environment)
        #expect(state.validation == .success(.validated))
    }

    @Test func appLifetimeStateContainsNoRawConfiguration() throws {
        let privateValues = [
            "/Volumes/private-root-sentinel", "external-hdd", "exfat",
            "private_case_sentinel", runID.uuidString.lowercased(), "execute", "skip", "1",
        ]
        let environment = validEnvironment(
            volumeRoot: privateValues[0],
            destinationClass: privateValues[1],
            filesystemClass: privateValues[2],
            caseID: privateValues[3]
        )
        let validation = DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment
        )
        let state = DevVlogsPhase0BStorageTestHostState(environment: environment)
        let application = DevVlogsPhase0BStorageTestHostApplication(environment: environment)
        #expect(try validation.get() == .validated)
        #expect(Mirror(reflecting: try validation.get()).children.isEmpty)
        assertDiagnosticsContainNone(privateValues, in: validation)
        assertDiagnosticsContainNone(privateValues, in: state)
        assertDiagnosticsContainNone(privateValues, in: application)
    }

    @Test func failureLifetimeStateContainsNoRawInputOrAssociatedValue() {
        let privateRoot = "/Volumes/private-failure-root-sentinel/"
        let environment = validEnvironment(volumeRoot: privateRoot)
        let validation = DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment
        )
        let state = DevVlogsPhase0BStorageTestHostState(environment: environment)
        #expect(validation == .failure(.invalidVolumeRoot))
        #expect(Mirror(reflecting: DevVlogsPhase0BStorageTestHostLaunchError.invalidVolumeRoot)
            .children.isEmpty)
        assertDiagnosticsContainNone([privateRoot], in: validation)
        assertDiagnosticsContainNone([privateRoot], in: state)
    }

    @Test func everyMissingOrEmptyClosedInputStaysInertWithTypedFailure() {
        let valid = validEnvironment()
        for key in DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnvironmentKeys {
            var missing = valid
            missing.removeValue(forKey: key)
            assertIsolatedFailure(missing, expected: .missingRuntimeValue)
            var empty = valid
            empty[key] = ""
            assertIsolatedFailure(empty, expected: .missingRuntimeValue)
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

    @Test func completeObserverConfigurationInstallsOnlyInsideTheInertHost() throws {
        let environment = validObserverEnvironment()
        var installed: DevVlogsPhase0BProtectedStorageObserverInstallConfiguration?
        let result = DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment,
            rawEnvironment: rawEntries(environment),
            installObserver: { installed = $0 }
        )
        #expect(try result.get() == .validated)
        #expect(installed?.runID == runID)
        #expect(installed?.taskHome.path == "/private/tmp/holdtype-observer-home")
        #expect(DevVlogsPhase0BStorageTestHostConfiguration.shouldIsolate(
            environment: environment))
    }

    @Test func partialMalformedDuplicateAndUnknownObserverInputsFailClosed() {
        let valid = validObserverEnvironment()
        for key in [
            DevVlogsPhase0BProtectedStorageObserverConfiguration.modeEnvironmentKey,
            DevVlogsPhase0BProtectedStorageObserverConfiguration.runIDEnvironmentKey,
            DevVlogsPhase0BProtectedStorageObserverConfiguration.caseIDEnvironmentKey,
            DevVlogsPhase0BProtectedStorageObserverConfiguration
                .privateHomeValidationEnvironmentKey,
            "HOME", "CFFIXED_USER_HOME", "TMPDIR",
        ] {
            var missing = valid
            missing.removeValue(forKey: key)
            assertObserverFailure(missing, expected: .duplicateOrMissingObserverValue)
            var empty = valid
            empty[key] = ""
            assertObserverFailure(empty, expected: .invalidObserverConfiguration)
        }
        var malformed = valid
        malformed[DevVlogsPhase0BProtectedStorageObserverConfiguration.modeEnvironmentKey] = "json"
        assertObserverFailure(malformed, expected: .invalidObserverConfiguration)
        var unknown = valid
        unknown["HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_EXTRA"] = "1"
        assertObserverFailure(unknown, expected: .unknownObserverValue)
        var duplicateRaw = rawEntries(valid)
        duplicateRaw.append(
            "\(DevVlogsPhase0BProtectedStorageObserverConfiguration.modeEnvironmentKey)=stderr-json-v1"
        )
        #expect(DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: valid, rawEnvironment: duplicateRaw, installObserver: { _ in })
            == .failure(.duplicateOrMissingObserverValue))
    }

    @Test func observerConflictsWithEveryOtherDebugStorageRoute() {
        let conflictKeys = DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnvironmentKeys
            + DevVlogsPhase0BStorageTestHostConfiguration.existingRouteEnvironmentKeys
        for key in conflictKeys {
            var environment = validObserverEnvironment()
            environment[key] = "1"
            assertObserverFailure(environment, expected: .conflictingRoute)
        }
    }

    private let runID = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!

    private func validEnvironment(
        volumeRoot: String = "/Volumes/redacted-fixture",
        destinationClass: String = "external-ssd",
        filesystemClass: String = "apfs",
        caseID: String = "mechanics_case"
    ) -> [String: String] {
        [
            DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey: "1",
            DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnableEnvironmentKey: "execute",
            DevVlogsPhase0BStorageTestHostConfiguration.volumeRootEnvironmentKey: volumeRoot,
            DevVlogsPhase0BStorageTestHostConfiguration.destinationClassEnvironmentKey:
                destinationClass,
            DevVlogsPhase0BStorageTestHostConfiguration.filesystemClassEnvironmentKey:
                filesystemClass,
            DevVlogsPhase0BStorageTestHostConfiguration.caseIDEnvironmentKey: caseID,
            DevVlogsPhase0BStorageTestHostConfiguration.runIDEnvironmentKey:
                runID.uuidString.lowercased(),
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }

    private func validObserverEnvironment() -> [String: String] {
        let home = "/private/tmp/holdtype-observer-home"
        return [
            DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey: "1",
            DevVlogsPhase0BProtectedStorageObserverConfiguration.modeEnvironmentKey:
                DevVlogsPhase0BProtectedStorageObserverConfiguration.modeValue,
            DevVlogsPhase0BProtectedStorageObserverConfiguration.runIDEnvironmentKey:
                runID.uuidString.lowercased(),
            DevVlogsPhase0BProtectedStorageObserverConfiguration.caseIDEnvironmentKey:
                DevVlogsPhase0BProtectedStorageObserverConfiguration.caseIDValue,
            DevVlogsPhase0BProtectedStorageObserverConfiguration
                .privateHomeValidationEnvironmentKey: "1",
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
            "HOME": home,
            "CFFIXED_USER_HOME": home,
            "TMPDIR": home + "/tmp",
        ]
    }

    private func rawEntries(_ environment: [String: String]) -> [String] {
        environment.map { "\($0.key)=\($0.value)" }
    }

    private func assertObserverFailure(
        _ environment: [String: String],
        expected: DevVlogsPhase0BStorageTestHostLaunchError
    ) {
        #expect(DevVlogsPhase0BStorageTestHostConfiguration.shouldIsolate(
            environment: environment))
        #expect(DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment,
            rawEnvironment: rawEntries(environment),
            installObserver: { _ in }
        ) == .failure(expected))
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
        #expect(state.validation == .failure(expected))
        #expect(Mirror(reflecting: expected).children.isEmpty)
    }

    private func assertDiagnosticsContainNone<T>(_ values: [String], in subject: T) {
        var dumpOutput = ""
        dump(subject, to: &dumpOutput)
        for output in [String(describing: subject), String(reflecting: subject), dumpOutput] {
            for value in values {
                #expect(!output.contains(value))
            }
        }
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
