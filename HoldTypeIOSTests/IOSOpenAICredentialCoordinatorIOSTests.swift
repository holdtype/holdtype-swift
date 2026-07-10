import Foundation
import HoldTypeIOSCore
import Testing

struct IOSOpenAICredentialCoordinatorIOSTests {
    @Test func publicContainingAppContractImportsWithoutPerformingKeychainWork() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-ios-credential-core-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let markerFileURL = directoryURL.appendingPathComponent(
            "credential-presence-v1.json"
        )

        let coordinator = try IOSOpenAICredentialCoordinator(
            applicationIdentifierAccessGroup: "TESTTEAMID.app.holdtype.HoldType.ios",
            markerFileURL: markerFileURL
        )

        #expect(!FileManager.default.fileExists(atPath: markerFileURL.path))
        let status = await coordinator.credentialStatus()
        #expect(status.primary == .notCheckedInThisProcess)
        #expect(status.statusNeedsRefresh == false)
        #expect(status.localMarkerIssue == nil)
        #expect(!FileManager.default.fileExists(atPath: markerFileURL.path))
        requireSendable(IOSOpenAICredentialCoordinator.self)
        requireSendable(IOSOpenAICredentialStatus.self)
        requireSendable(IOSOpenAICredentialResolutionOutcome.self)
    }

    @Test func publicStatusAndErrorDiagnosticsAreRedacted() {
        let status = IOSOpenAICredentialStatus(
            primary: .availableInThisProcess,
            statusNeedsRefresh: true,
            localMarkerIssue: .unavailable
        )
        let error = IOSOpenAICredentialCoordinatorError.credentialAccessFailed(
            .keychainFailure,
            markerRestorationFailed: true
        )

        for value in [status as Any, error as Any] {
            let renderings = [
                String(describing: value),
                String(reflecting: value),
            ]
            for rendering in renderings {
                #expect(!rendering.contains("sk-ios-secret"))
                #expect(!rendering.contains("-25308"))
            }
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
