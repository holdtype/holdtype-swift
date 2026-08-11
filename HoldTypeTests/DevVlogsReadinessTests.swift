import Testing
import Foundation
@testable import HoldType

@MainActor
struct DevVlogsReadinessTests {
    @Test func disabledFeatureIsOffBeforeAnySetupState() {
        #expect(DevVlogsReadinessReducer.reduce(makeInput(isEnabled: false)) == .off)
    }

    @Test func missingRequiredChoicesNeedSetup() {
        #expect(DevVlogsReadinessReducer.reduce(makeInput(preferredCamera: nil)) == .setupRequired)
        #expect(DevVlogsReadinessReducer.reduce(makeInput(destination: .needsSetup)) == .setupRequired)
    }

    @Test func configuredAndAvailableChoicesAreReady() {
        #expect(DevVlogsReadinessReducer.reduce(makeInput()) == .ready)
    }

    @Test func cameraFailureHasDeterministicPriorityOverDestinationFailure() {
        let readiness = DevVlogsReadinessReducer.reduce(
            makeInput(
                cameraPermissionStatus: .denied,
                destination: .unavailable(.missing)
            )
        )

        #expect(readiness == .degradedCameraUnavailable)
    }

    @Test func unavailableDestinationDegradesOnlyAfterTheOtherChoicesAreConfigured() {
        #expect(
            DevVlogsReadinessReducer.reduce(makeInput(destination: .unavailable(.missing)))
                == .degradedDestinationUnavailable
        )
    }

    @Test func coordinatorBootstrapsConfiguredRelaunchAndRecomputesPassiveChanges() throws {
        let suiteName = "DevVlogsReadinessTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let preferredCamera = DevVlogsCamera(id: "desk", label: "Desk Camera")
        let settingsStore = DevVlogsSettingsStore(
            isEnabled: true,
            preferredCamera: preferredCamera,
            applicationPolicy: DevVlogsApplicationPolicy(
                mode: .allAppsExceptExcludedApps,
                selectedApps: [],
                excludedApps: []
            )
        )
        let cameraClient = CameraClientFake(status: .allowed, cameras: [preferredCamera])
        let cameraStore = DevVlogsCameraSetupStore(client: cameraClient)
        let bookmarkResolver = BookmarkResolverFake()
        let fileAccess = FileAccessFake()
        let defaultURL = URL(fileURLWithPath: "/fixture/Movies/HoldType Dev Vlogs")
        let customURL = URL(fileURLWithPath: "/fixture/External/Dev Vlogs")
        fileAccess.states[customURL.path] = .directory(isWritable: true)

        let firstStore = DevVlogsDestinationSetupStore(
            userDefaults: userDefaults,
            bookmarkResolver: bookmarkResolver,
            fileAccess: fileAccess,
            defaultDestinationURL: defaultURL
        )
        firstStore.selectCustomFolder(customURL)
        let destinationStore = DevVlogsDestinationSetupStore(
            userDefaults: userDefaults,
            bookmarkResolver: bookmarkResolver,
            fileAccess: fileAccess,
            defaultDestinationURL: defaultURL
        )

        DevVlogsReadinessCoordinator.refresh(
            cameraSetupStore: cameraStore,
            destinationStore: destinationStore
        )

        #expect(readiness(settingsStore, cameraStore, destinationStore) == .ready)
        #expect(cameraClient.requestAccessCount == 0)
        #expect(fileAccess.createdURLs.isEmpty)

        cameraClient.cameras = []
        DevVlogsReadinessCoordinator.refresh(
            cameraSetupStore: cameraStore,
            destinationStore: destinationStore
        )
        #expect(readiness(settingsStore, cameraStore, destinationStore) == .degradedCameraUnavailable)

        cameraClient.cameras = [preferredCamera]
        fileAccess.states[customURL.path] = .missing
        DevVlogsReadinessCoordinator.refresh(
            cameraSetupStore: cameraStore,
            destinationStore: destinationStore
        )
        #expect(readiness(settingsStore, cameraStore, destinationStore) == .degradedDestinationUnavailable)
        #expect(cameraClient.requestAccessCount == 0)
        #expect(fileAccess.createdURLs.isEmpty)
    }

    private func makeInput(
        isEnabled: Bool = true,
        preferredCamera: DevVlogsCamera? = DevVlogsCamera(id: "desk", label: "Desk Camera"),
        cameraPermissionStatus: DevVlogsCameraPermissionStatus = .allowed,
        destination: DevVlogsDestinationAvailability = .available
    ) -> DevVlogsReadinessInput {
        DevVlogsReadinessInput(
            isEnabled: isEnabled,
            preferredCamera: preferredCamera,
            cameraPermissionStatus: cameraPermissionStatus,
            availableCameras: [DevVlogsCamera(id: "desk", label: "Desk Camera")],
            applicationPolicy: DevVlogsApplicationPolicy(
                mode: .allAppsExceptExcludedApps,
                selectedApps: [],
                excludedApps: []
            ),
            destination: DevVlogsDestinationStatus(
                selection: destination == .needsSetup
                    ? .proposedDefault(path: "/fixture/Movies/HoldType Dev Vlogs")
                    : .custom(displayName: "Dev Vlogs", pathSnapshot: "/fixture/Dev Vlogs"),
                availability: destination
            )
        )
    }

    private func readiness(
        _ settingsStore: DevVlogsSettingsStore,
        _ cameraStore: DevVlogsCameraSetupStore,
        _ destinationStore: DevVlogsDestinationSetupStore
    ) -> DevVlogsReadiness {
        DevVlogsReadinessReducer.reduce(
            DevVlogsReadinessInput(
                isEnabled: settingsStore.isEnabled,
                preferredCamera: settingsStore.preferredCamera,
                cameraPermissionStatus: cameraStore.permissionStatus,
                availableCameras: cameraStore.cameras,
                applicationPolicy: settingsStore.applicationPolicy,
                destination: destinationStore.status
            )
        )
    }

    private final class CameraClientFake: DevVlogsCameraSetupClient {
        var status: DevVlogsCameraAuthorizationStatus
        var cameras: [DevVlogsCamera]
        let cameraDeviceChangeNotifications: [Notification.Name] = []
        private(set) var requestAccessCount = 0

        init(status: DevVlogsCameraAuthorizationStatus, cameras: [DevVlogsCamera]) {
            self.status = status
            self.cameras = cameras
        }

        func authorizationStatus() -> DevVlogsCameraAuthorizationStatus { status }
        func availableCameras() throws -> [DevVlogsCamera] { cameras }
        func requestAccess(completion: @escaping (Bool) -> Void) {
            requestAccessCount += 1
            completion(status == .allowed)
        }
        func openCameraSettings() -> Bool { false }
    }

    private final class BookmarkResolverFake: DevVlogsDestinationBookmarkResolving {
        func bookmarkData(for url: URL) throws -> Data { Data(url.path.utf8) }
        func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution {
            DevVlogsBookmarkResolution(
                url: URL(fileURLWithPath: String(decoding: data, as: UTF8.self)),
                isStale: false
            )
        }
        func startAccessingSecurityScopedResource(at url: URL) -> Bool { true }
        func stopAccessingSecurityScopedResource(at url: URL) {}
    }

    private final class FileAccessFake: DevVlogsDestinationFileAccessing {
        var states: [String: DevVlogsDestinationDirectoryState] = [:]
        private(set) var createdURLs: [URL] = []

        func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState {
            states[url.path] ?? .missing
        }

        func createDirectory(at url: URL) throws {
            createdURLs.append(url)
        }
    }
}
