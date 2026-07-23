import HoldTypeDomain
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceFixesCatalogOwnerTests {
    @Test func loadPublishesPinnedBuiltInsAndOnlyEnabledCustomActions()
        async throws {
        let defaults = TextFixCatalog.defaults
        let disabledID = try #require(defaults.customActions.first?.id)
        let catalog = try defaults.settingCustomActionEnabled(
            id: disabledID,
            isEnabled: false
        )
        let owner = IOSVoiceFixesCatalogOwner(
            client: IOSVoiceFixesCatalogClient(load: { catalog })
        )

        await owner.refresh()

        #expect(
            owner.enabledActions.prefix(2).map(\.id) == [
                TextFixAction.translateIdentifier,
                TextFixAction.fixIdentifier,
            ]
        )
        #expect(!owner.enabledActions.map(\.id).contains(disabledID))
        #expect(owner.state == .ready(catalog.enabledActions))
    }

    @Test func loadFailureStaysUnavailableWithoutInventingDefaults() async {
        let owner = IOSVoiceFixesCatalogOwner(
            client: IOSVoiceFixesCatalogClient {
                throw IOSVoiceFixesCatalogTestError.unavailable
            }
        )

        await owner.refresh()

        #expect(owner.state == .unavailable)
        #expect(owner.enabledActions.isEmpty)
    }
}

private enum IOSVoiceFixesCatalogTestError: Error {
    case unavailable
}
