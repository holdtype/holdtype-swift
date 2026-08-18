import Foundation
import Testing
@testable import HoldType

@MainActor
struct MacOSTextFixCatalogStoreTests {
    @Test func developmentAndProductionCatalogRootsAreSeparate() {
        let root = URL(
            fileURLWithPath: "/Users/person/Library/Application Support",
            isDirectory: true
        )

        let productionRoot = MacOSTextFixCatalogBuildChannel.production
            .applicationSupportRootURL(in: root)
        let developmentRoot = MacOSTextFixCatalogBuildChannel.development
            .applicationSupportRootURL(in: root)

        #expect(productionRoot == root)
        #expect(
            developmentRoot.path ==
                "/Users/person/Library/Application Support/app.holdtype.HoldType.debug"
        )
        #expect(developmentRoot != productionRoot)

        #if DEBUG
        #expect(MacOSTextFixCatalogBuildChannel.current == .development)
        #else
        #expect(MacOSTextFixCatalogBuildChannel.current == .production)
        #endif
    }
}
