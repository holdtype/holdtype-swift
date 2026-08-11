import Darwin
import Foundation

@MainActor
enum InputMonitoringPermissionLaunchRecovery {
    static let requestEnvironmentKey = "HOLDTYPE_REQUEST_INPUT_MONITORING_ON_LAUNCH"
    static let openSettingsEnvironmentKey = "HOLDTYPE_OPEN_INPUT_MONITORING_SETTINGS_ON_LAUNCH"
    static let exitAfterRequestEnvironmentKey = "HOLDTYPE_EXIT_AFTER_INPUT_MONITORING_REQUEST"
    static let requestDelayAfterActivation: DispatchTimeInterval = .milliseconds(500)

    static func shouldRequest(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[requestEnvironmentKey] == "1"
    }

    static func requestIfNeeded(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        permissionService: InputMonitoringPermissionService = InputMonitoringPermissionService(),
        activateApp: @MainActor () -> Void = {
            AppWindowActivation.activateForWindowPresentation()
        },
        scheduleRequestAfterActivation: @escaping (@escaping @MainActor () -> Void) -> Void = { request in
            DispatchQueue.main.asyncAfter(deadline: .now() + requestDelayAfterActivation) {
                Task { @MainActor in
                    request()
                }
            }
        },
        terminateProcess: @escaping () -> Void = {
            Darwin.exit(0)
        }
    ) {
        guard shouldRequest(environment: environment) else {
            return
        }

        activateApp()
        scheduleRequestAfterActivation {
            let status = permissionService.requestPermission()
            if status != .allowed || environment[openSettingsEnvironmentKey] == "1" {
                permissionService.openInputMonitoringSettings()
            }

            if environment[exitAfterRequestEnvironmentKey] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                    terminateProcess()
                }
            }
        }
    }

    static func launchFreshRequest(
        bundleURL: URL = Bundle.main.bundleURL,
        openSettings: Bool = true
    ) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-n",
            bundleURL.path,
            "--env",
            "\(requestEnvironmentKey)=1",
            "--env",
            "\(openSettingsEnvironmentKey)=\(openSettings ? "1" : "0")",
            "--env",
            "\(exitAfterRequestEnvironmentKey)=1"
        ]

        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}
