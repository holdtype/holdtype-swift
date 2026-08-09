#if DEBUG
import Foundation
import SwiftUI

enum DevVlogsPhase0BStorageTestHostLaunchError: Error, Equatable {
    case invalidHostEnablement
    case automationRequired
    case keychainPolicyRequired
    case conflictingRoute
    case missingRuntimeValue
    case invalidRuntimeEnablement
    case invalidVolumeRoot
    case invalidDestinationClass
    case invalidFilesystemClass
    case invalidCaseID
    case invalidRunID
    case duplicateOrMissingObserverValue
    case invalidObserverConfiguration
    case unknownObserverValue
}

enum DevVlogsPhase0BStorageTestHostValidation: Equatable {
    case validated
}

@MainActor
enum DevVlogsPhase0BStorageTestHostConfiguration {
    static let hostEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST"
    static let runtimeEnableEnvironmentKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_ENABLE"
    static let volumeRootEnvironmentKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_VOLUME_ROOT"
    static let destinationClassEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_DESTINATION_CLASS"
    static let filesystemClassEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_FILESYSTEM_CLASS"
    static let caseIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_CASE_ID"
    static let runIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_RUN_ID"

    static let runtimeEnvironmentKeys = [
        runtimeEnableEnvironmentKey,
        volumeRootEnvironmentKey,
        destinationClassEnvironmentKey,
        filesystemClassEnvironmentKey,
        caseIDEnvironmentKey,
        runIDEnvironmentKey,
    ]

    static let existingRouteEnvironmentKeys = [
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

    static func shouldIsolate(environment: [String: String]) -> Bool {
        environment[hostEnvironmentKey] != nil
            || runtimeEnvironmentKeys.contains { environment[$0] != nil }
            || DevVlogsPhase0BProtectedStorageObserverConfiguration.isPresent(
                environment: environment
            )
    }

    static func resolve(
        environment: [String: String]
    ) -> Result<DevVlogsPhase0BStorageTestHostValidation,
        DevVlogsPhase0BStorageTestHostLaunchError> {
        resolve(
            environment: environment,
            rawEnvironment: nil,
            installObserver: { DevVlogsPhase0BProtectedStorageObserver.shared.install($0) }
        )
    }

    static func resolve(
        environment: [String: String],
        rawEnvironment: [String]?,
        installObserver: (
            DevVlogsPhase0BProtectedStorageObserverInstallConfiguration
        ) -> Void
    ) -> Result<DevVlogsPhase0BStorageTestHostValidation,
        DevVlogsPhase0BStorageTestHostLaunchError> {
        if DevVlogsPhase0BProtectedStorageObserverConfiguration.isPresent(
            environment: environment
        ) {
            return DevVlogsPhase0BProtectedStorageObserverConfiguration.resolveAndInstall(
                environment: environment,
                rawEnvironment: rawEnvironment,
                install: installObserver
            )
        }
        guard environment[hostEnvironmentKey] == "1" else {
            return .failure(.invalidHostEnablement)
        }
        guard environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1" else {
            return .failure(.automationRequired)
        }
        guard environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey]
            == KeychainInteractionPolicy.skipAuthenticationUIValue else {
            return .failure(.keychainPolicyRequired)
        }
        guard !hasConflictingRoute(environment: environment) else {
            return .failure(.conflictingRoute)
        }
        for key in runtimeEnvironmentKeys {
            guard let value = environment[key], !value.isEmpty else {
                return .failure(.missingRuntimeValue)
            }
        }
        guard environment[runtimeEnableEnvironmentKey] == "execute" else {
            return .failure(.invalidRuntimeEnablement)
        }
        guard let volumeRoot = environment[volumeRootEnvironmentKey],
              isValidVolumeRoot(volumeRoot) else {
            return .failure(.invalidVolumeRoot)
        }
        guard let destinationClass = environment[destinationClassEnvironmentKey],
              ["external-ssd", "external-hdd"].contains(destinationClass) else {
            return .failure(.invalidDestinationClass)
        }
        guard let filesystemClass = environment[filesystemClassEnvironmentKey],
              ["apfs", "hfs", "exfat"].contains(filesystemClass) else {
            return .failure(.invalidFilesystemClass)
        }
        guard let caseID = environment[caseIDEnvironmentKey],
              isSafeIdentifier(caseID) else {
            return .failure(.invalidCaseID)
        }
        guard let runIDValue = environment[runIDEnvironmentKey],
              let runID = UUID(uuidString: runIDValue),
              runID.uuidString.lowercased() == runIDValue else {
            return .failure(.invalidRunID)
        }
        return .success(.validated)
    }

    private static func hasConflictingRoute(environment: [String: String]) -> Bool {
        existingRouteEnvironmentKeys.contains { environment[$0] != nil }
    }

    private static func isValidVolumeRoot(_ value: String) -> Bool {
        value.hasPrefix("/")
            && value != "/"
            && !value.hasSuffix("/")
            && !value.contains("\n")
            && URL(fileURLWithPath: value).standardizedFileURL.path == value
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        (1 ... 64).contains(value.count) && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
    }
}

@MainActor
enum DevVlogsPhase0BStorageTestHostLaunch {
    static func startApplication(
        environment: [String: String],
        startStorageApplication: () -> Void,
        startExistingApplication: () -> Void
    ) {
        if DevVlogsPhase0BStorageTestHostConfiguration.shouldIsolate(environment: environment) {
            startStorageApplication()
        } else {
            startExistingApplication()
        }
    }
}

@MainActor
struct DevVlogsPhase0BStorageTestHostState: Equatable {
    let validation: Result<
        DevVlogsPhase0BStorageTestHostValidation,
        DevVlogsPhase0BStorageTestHostLaunchError
    >

    init(environment: [String: String]) {
        self.init(
            environment: environment,
            rawEnvironment: nil,
            installObserver: { DevVlogsPhase0BProtectedStorageObserver.shared.install($0) }
        )
    }

    init(
        environment: [String: String],
        rawEnvironment: [String]?,
        installObserver: (
            DevVlogsPhase0BProtectedStorageObserverInstallConfiguration
        ) -> Void
    ) {
        validation = DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment,
            rawEnvironment: rawEnvironment,
            installObserver: installObserver
        )
    }
}

@MainActor
struct DevVlogsPhase0BStorageTestHostApplication: App {
    let launchState: DevVlogsPhase0BStorageTestHostState

    init() {
        launchState = DevVlogsPhase0BStorageTestHostState(
            environment: ProcessInfo.processInfo.environment,
            rawEnvironment: DevVlogsPhase0BProtectedStorageObserverConfiguration
                .currentRawEnvironment(),
            installObserver: { DevVlogsPhase0BProtectedStorageObserver.shared.install($0) }
        )
    }

    init(environment: [String: String]) {
        launchState = DevVlogsPhase0BStorageTestHostState(environment: environment)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
#endif
