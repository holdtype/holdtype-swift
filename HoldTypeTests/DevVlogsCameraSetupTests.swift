import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsCameraSetupTests {
    @Test func refreshMapsPermissionAndReadsAvailableCamerasWithoutRequestingAccess() {
        let client = CameraSetupClientFake(
            status: .notDetermined,
            cameras: [DevVlogsCamera(id: "desk", label: "Desk Camera")]
        )
        let store = DevVlogsCameraSetupStore(client: client)

        store.refresh()

        #expect(store.permissionStatus == .notDetermined)
        #expect(store.cameras == [DevVlogsCamera(id: "desk", label: "Desk Camera")])
        #expect(client.requestAccessCount == 0)
    }

    @Test func explicitRequestIsIgnoredWhileOffAndRefreshesItsResultWhenEnabled() async {
        let client = CameraSetupClientFake(status: .notDetermined, requestedStatus: .allowed)
        let store = DevVlogsCameraSetupStore(client: client)
        store.refresh()

        store.requestAccessIfNeeded(isEnabled: false)
        #expect(client.requestAccessCount == 0)

        store.requestAccessIfNeeded(isEnabled: true)
        await Task.yield()

        #expect(client.requestAccessCount == 1)
        #expect(store.permissionStatus == .allowed)
    }

    @Test func deniedStatusUsesOnlyTheExplicitEnabledRecoveryAction() {
        let client = CameraSetupClientFake(status: .denied)
        let store = DevVlogsCameraSetupStore(client: client)
        store.refresh()

        #expect(store.openCameraSettingsIfNeeded(isEnabled: false) == false)
        #expect(client.openSettingsCount == 0)
        #expect(store.openCameraSettingsIfNeeded(isEnabled: true) == true)
        #expect(client.openSettingsCount == 1)
    }

    @Test func discoveryFiltersDisconnectedAndSuspendedCameras() {
        let cameras = DevVlogsCameraDiscovery.availableCameras(from: [
            DevVlogsCameraDiscoveryCandidate(
                id: "disconnected",
                label: "Disconnected",
                isConnected: false,
                isSuspended: false
            ),
            DevVlogsCameraDiscoveryCandidate(
                id: "suspended",
                label: "Suspended",
                isConnected: true,
                isSuspended: true
            ),
            DevVlogsCameraDiscoveryCandidate(
                id: "desk",
                label: "Desk Camera",
                isConnected: true,
                isSuspended: false
            )
        ])

        #expect(cameras == [DevVlogsCamera(id: "desk", label: "Desk Camera")])
    }

    @Test func discoveryFailureIsUnavailableRatherThanAFalsePermissionState() {
        let client = CameraSetupClientFake(status: .allowed, discoveryFails: true)
        let store = DevVlogsCameraSetupStore(client: client)

        store.refresh()

        #expect(store.permissionStatus == .unavailable)
        #expect(store.cameras.isEmpty)
    }

    private final class CameraSetupClientFake: DevVlogsCameraSetupClient {
        var status: DevVlogsCameraAuthorizationStatus
        let requestedStatus: DevVlogsCameraAuthorizationStatus?
        let cameras: [DevVlogsCamera]
        let discoveryFails: Bool
        private(set) var requestAccessCount = 0
        private(set) var openSettingsCount = 0

        init(
            status: DevVlogsCameraAuthorizationStatus,
            requestedStatus: DevVlogsCameraAuthorizationStatus? = nil,
            cameras: [DevVlogsCamera] = [],
            discoveryFails: Bool = false
        ) {
            self.status = status
            self.requestedStatus = requestedStatus
            self.cameras = cameras
            self.discoveryFails = discoveryFails
        }

        func authorizationStatus() -> DevVlogsCameraAuthorizationStatus {
            status
        }

        func availableCameras() throws -> [DevVlogsCamera] {
            if discoveryFails {
                throw CameraSetupFakeError.discoveryFailed
            }

            return cameras
        }

        func requestAccess(completion: @escaping (Bool) -> Void) {
            requestAccessCount += 1
            if let requestedStatus {
                status = requestedStatus
            }
            completion(status == .allowed)
        }

        func openCameraSettings() -> Bool {
            openSettingsCount += 1
            return true
        }
    }

    private enum CameraSetupFakeError: Error {
        case discoveryFailed
    }
}
