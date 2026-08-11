import Testing
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
}
