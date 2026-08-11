import Combine
import AVFoundation
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
            ),
            DevVlogsCameraDiscoveryCandidate(
                id: "continuity",
                label: "Continuity Camera",
                isConnected: true,
                isSuspended: false
            )
        ])

        #expect(cameras == [
            DevVlogsCamera(id: "continuity", label: "Continuity Camera"),
            DevVlogsCamera(id: "desk", label: "Desk Camera")
        ])
    }

    @Test func discoveryIncludesContinuityCameraWhenTheDeploymentSupportsIt() {
        if #available(macOS 14.0, *) {
            #expect(DevVlogsCameraDiscovery.deviceTypes.contains(.continuityCamera))
        }
    }

    @Test func cameraDeviceChangeNotificationRefreshesTheCurrentCameraList() {
        let notificationCenter = NotificationCenter()
        let notificationName = Notification.Name("DevVlogsCameraSetupTests.camera-changed")
        let client = CameraSetupClientFake(
            status: .allowed,
            cameras: [DevVlogsCamera(id: "desk", label: "Desk Camera")],
            cameraDeviceChangeNotifications: [notificationName]
        )
        let store = DevVlogsCameraSetupStore(client: client)
        store.refresh()
        client.cameras = [DevVlogsCamera(id: "continuity", label: "Continuity Camera")]

        var refreshCount = 0
        let cancellable = store.cameraDeviceChangePublisher(notificationCenter: notificationCenter)
            .sink { _ in
                refreshCount += 1
                store.refreshAfterCameraDeviceChange()
            }
        notificationCenter.post(name: notificationName, object: nil)

        #expect(refreshCount == 1)
        #expect(store.cameras == [DevVlogsCamera(id: "continuity", label: "Continuity Camera")])
        withExtendedLifetime(cancellable) {}
    }

    @Test func applicationActivationRefreshesPermissionAndCamerasWithoutRequestingAccess() {
        let client = CameraSetupClientFake(status: .denied)
        let store = DevVlogsCameraSetupStore(client: client)
        store.refresh()
        client.status = .allowed
        client.cameras = [DevVlogsCamera(id: "desk", label: "Desk Camera")]

        store.refreshAfterApplicationActivation()

        #expect(store.permissionStatus == .allowed)
        #expect(store.cameras == [DevVlogsCamera(id: "desk", label: "Desk Camera")])
        #expect(client.requestAccessCount == 0)
    }

    @Test func stableIDAvailabilityDoesNotChangeWhenTheDisplayLabelChanges() {
        let remembered = DevVlogsCamera(id: "stable-id", label: "Desk Camera")
        let rediscovered = DevVlogsCamera(id: "stable-id", label: "Renamed Desk Camera")

        #expect(remembered.hasSameIdentity(as: rediscovered))
        #expect(remembered != rediscovered)
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
        var cameras: [DevVlogsCamera]
        let discoveryFails: Bool
        let cameraDeviceChangeNotifications: [Notification.Name]
        private(set) var requestAccessCount = 0
        private(set) var openSettingsCount = 0

        init(
            status: DevVlogsCameraAuthorizationStatus,
            requestedStatus: DevVlogsCameraAuthorizationStatus? = nil,
            cameras: [DevVlogsCamera] = [],
            discoveryFails: Bool = false,
            cameraDeviceChangeNotifications: [Notification.Name] = []
        ) {
            self.status = status
            self.requestedStatus = requestedStatus
            self.cameras = cameras
            self.discoveryFails = discoveryFails
            self.cameraDeviceChangeNotifications = cameraDeviceChangeNotifications
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
