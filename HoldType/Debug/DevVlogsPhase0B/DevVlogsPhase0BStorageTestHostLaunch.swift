#if DEBUG
import Foundation
import SwiftUI

enum DevVlogsPhase0BStorageTestHostLaunchError: Error, Equatable {
    case invalidHostEnablement
    case automationRequired
    case keychainPolicyRequired
    case conflictingRoute
    case missingRuntimeValue(String)
    case invalidRuntimeEnablement
    case invalidVolumeRoot
    case invalidDestinationClass
    case invalidFilesystemClass
    case invalidCaseID
    case invalidRunID
}

struct DevVlogsPhase0BStorageTestHostConfiguration: Equatable {
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

    let volumeRoot: String
    let destinationClass: String
    let filesystemClass: String
    let caseID: String
    let runID: UUID

    static func shouldIsolate(environment: [String: String]) -> Bool {
        environment[hostEnvironmentKey] != nil
            || runtimeEnvironmentKeys.contains { environment[$0] != nil }
    }

    static func resolve(
        environment: [String: String]
    ) -> Result<Self, DevVlogsPhase0BStorageTestHostLaunchError> {
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
                return .failure(.missingRuntimeValue(key))
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
        return .success(Self(
            volumeRoot: volumeRoot,
            destinationClass: destinationClass,
            filesystemClass: filesystemClass,
            caseID: caseID,
            runID: runID
        ))
    }

    private static func hasConflictingRoute(environment: [String: String]) -> Bool {
        let keys = [
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
        return keys.contains { environment[$0] != nil }
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

struct DevVlogsPhase0BStorageTestHostState: Equatable {
    let configuration: Result<
        DevVlogsPhase0BStorageTestHostConfiguration,
        DevVlogsPhase0BStorageTestHostLaunchError
    >

    init(environment: [String: String]) {
        configuration = DevVlogsPhase0BStorageTestHostConfiguration.resolve(
            environment: environment
        )
    }
}

struct DevVlogsPhase0BStorageTestHostApplication: App {
    let launchState: DevVlogsPhase0BStorageTestHostState

    init() {
        launchState = DevVlogsPhase0BStorageTestHostState(
            environment: ProcessInfo.processInfo.environment
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
