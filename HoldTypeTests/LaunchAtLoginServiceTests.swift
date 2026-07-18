import Foundation
import Testing
@testable import HoldType

struct LaunchAtLoginServiceTests {

    @Test func mapsSystemStatusesToProductStatuses() {
        #expect(makeService(status: .enabled).currentStatus() == .enabled)
        #expect(makeService(status: .notRegistered).currentStatus() == .disabled)
        #expect(makeService(status: .requiresApproval).currentStatus() == .requiresApproval)

        let notFoundStatus = makeService(status: .notFound).currentStatus()
        #expect(notFoundStatus == .unavailable("macOS could not find the HoldType Login Item registration."))
    }

    @Test func enablingRegistersAndReturnsRefreshedStatus() {
        let client = FakeLaunchAtLoginClient(status: .notRegistered)
        client.statusAfterRegister = .requiresApproval
        let service = LaunchAtLoginService(client: client)

        let status = service.setEnabled(true)

        #expect(status == .requiresApproval)
        #expect(client.registerCount == 1)
        #expect(client.unregisterCount == 0)
    }

    @Test func disablingUnregistersPendingApprovalRegistration() {
        let client = FakeLaunchAtLoginClient(status: .requiresApproval)
        client.statusAfterUnregister = .notRegistered
        let service = LaunchAtLoginService(client: client)

        let status = service.setEnabled(false)

        #expect(status == .disabled)
        #expect(client.registerCount == 0)
        #expect(client.unregisterCount == 1)
    }

    @Test func registrationErrorBecomesUnavailableStatus() {
        let client = FakeLaunchAtLoginClient(status: .notRegistered)
        client.registerError = NSError(
            domain: "LaunchAtLoginTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Registration failed."]
        )
        let service = LaunchAtLoginService(client: client)

        #expect(service.setEnabled(true) == .unavailable("Registration failed."))
    }

    @Test func pendingApprovalKeepsToggleOnButIsNotEnabled() {
        let status = LaunchAtLoginStatus.requiresApproval

        #expect(status.toggleValue)
        #expect(status.isEnabled == false)
        #expect(status.loginItemsActionTitle == "Approve in Login Items")
    }

    @Test func opensLoginItemsSettingsThroughClient() {
        let client = FakeLaunchAtLoginClient(status: .notRegistered)
        let service = LaunchAtLoginService(client: client)

        #expect(service.openLoginItemsSettings())
        #expect(client.openSettingsCount == 1)
    }

    private func makeService(status: LaunchAtLoginAuthorizationStatus) -> LaunchAtLoginService {
        LaunchAtLoginService(client: FakeLaunchAtLoginClient(status: status))
    }
}

private final class FakeLaunchAtLoginClient: LaunchAtLoginClient {
    var status: LaunchAtLoginAuthorizationStatus
    var statusAfterRegister: LaunchAtLoginAuthorizationStatus?
    var statusAfterUnregister: LaunchAtLoginAuthorizationStatus?
    var registerError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginAuthorizationStatus) {
        self.status = status
    }

    func currentStatus() -> LaunchAtLoginAuthorizationStatus {
        status
    }

    func register() throws {
        registerCount += 1

        if let registerError {
            throw registerError
        }

        if let statusAfterRegister {
            status = statusAfterRegister
        }
    }

    func unregister() throws {
        unregisterCount += 1

        if let statusAfterUnregister {
            status = statusAfterUnregister
        }
    }

    func openLoginItemsSettings() -> Bool {
        openSettingsCount += 1
        return true
    }
}
