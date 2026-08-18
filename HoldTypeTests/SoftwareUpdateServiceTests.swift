import Foundation
import Testing
@testable import HoldType

@MainActor
struct SoftwareUpdateServiceTests {
    @Test func developmentBuildNeverStartsTheProductionUpdater() {
        let configured = SoftwareUpdateConfiguration(
            feedURL: URL(string: "https://example.com/appcast.xml"),
            publicKey: "public-key"
        )

        #expect(
            SoftwareUpdateService.shouldStartUpdater(
                configuration: configured,
                buildChannel: .production
            )
        )
        #expect(
            !SoftwareUpdateService.shouldStartUpdater(
                configuration: configured,
                buildChannel: .development
            )
        )

        #if DEBUG
        #expect(SoftwareUpdateBuildChannel.current == .development)
        #else
        #expect(SoftwareUpdateBuildChannel.current == .production)
        #endif
    }

    @Test func incompleteProductionConfigurationDoesNotStartTheUpdater() {
        let configurations = [
            SoftwareUpdateConfiguration(feedURL: nil, publicKey: "public-key"),
            SoftwareUpdateConfiguration(
                feedURL: URL(string: "https://example.com/appcast.xml"),
                publicKey: nil
            ),
            SoftwareUpdateConfiguration(
                feedURL: URL(string: "https://example.com/appcast.xml"),
                publicKey: ""
            ),
        ]

        for configuration in configurations {
            #expect(
                !SoftwareUpdateService.shouldStartUpdater(
                    configuration: configuration,
                    buildChannel: .production
                )
            )
        }
    }
}
