#if DEBUG
import Foundation

enum DevVlogsPhase0BPreviewLaunchError: Error, Equatable {
    case invalidEnablement
    case automationRequired
    case keychainPolicyRequired
    case cameraIDRequired
    case conflictingHarnessRoute

    var message: String {
        switch self {
        case .invalidEnablement:
            "Preview mode must be enabled with the exact value 1."
        case .automationRequired:
            "Preview mode requires the repository automation policy."
        case .keychainPolicyRequired:
            "Preview mode requires non-interactive Keychain policy."
        case .cameraIDRequired:
            "Select one exact camera identifier before launching preview mode."
        case .conflictingHarnessRoute:
            "Preview mode cannot run with a capture or authorization harness route."
        }
    }
}

struct DevVlogsPhase0BPreviewConfiguration: Equatable {
    static let enabledEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_PREVIEW"
    static let cameraIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_PREVIEW_CAMERA_ID"

    let cameraUniqueID: String

    static func shouldIsolate(environment: [String: String]) -> Bool {
        environment[enabledEnvironmentKey] != nil
    }

    static func resolve(
        environment: [String: String]
    ) -> Result<Self, DevVlogsPhase0BPreviewLaunchError> {
        guard environment[enabledEnvironmentKey] == "1" else {
            return .failure(.invalidEnablement)
        }
        guard environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1" else {
            return .failure(.automationRequired)
        }
        guard environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey]
            == KeychainInteractionPolicy.skipAuthenticationUIValue else {
            return .failure(.keychainPolicyRequired)
        }
        guard !hasConflictingHarnessValue(environment: environment) else {
            return .failure(.conflictingHarnessRoute)
        }
        guard let cameraUniqueID = environment[cameraIDEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !cameraUniqueID.isEmpty,
            cameraUniqueID.count <= 512 else {
            return .failure(.cameraIDRequired)
        }
        return .success(Self(cameraUniqueID: cameraUniqueID))
    }

    private static func hasConflictingHarnessValue(environment: [String: String]) -> Bool {
        let keys = [
            DevVlogsPhase0BConfiguration.enabledEnvironmentKey,
            DevVlogsPhase0BConfiguration.runRootEnvironmentKey,
            DevVlogsPhase0BConfiguration.cameraUniqueIDEnvironmentKey,
            DevVlogsPhase0BConfiguration.durationEnvironmentKey,
            DevVlogsPhase0BConfiguration.caseIDEnvironmentKey,
            DevVlogsPhase0BConfiguration.eventLogEnvironmentKey,
            DevVlogsPhase0BCameraAuthorizationConfiguration.enabledEnvironmentKey,
            DevVlogsPhase0BCameraAuthorizationConfiguration.launchTokenEnvironmentKey,
        ]
        return keys.contains { environment[$0] != nil }
    }
}

@MainActor
enum DevVlogsPhase0BPreviewLaunch {
    static func startApplication(
        environment: [String: String],
        startPreviewApplication: () -> Void,
        startExistingApplication: () -> Void
    ) {
        if DevVlogsPhase0BPreviewConfiguration.shouldIsolate(environment: environment) {
            startPreviewApplication()
        } else {
            startExistingApplication()
        }
    }
}
#endif
