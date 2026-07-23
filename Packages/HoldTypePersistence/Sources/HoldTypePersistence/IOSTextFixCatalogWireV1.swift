import Foundation
import HoldTypeDomain

struct IOSTextFixCatalogWireV1: Encodable {
    private let schemaVersion = 1
    private let actions: [IOSTextFixActionWireV1]

    init(catalog: TextFixCatalog) {
        actions = catalog.actions.map(IOSTextFixActionWireV1.init)
    }
}

private struct IOSTextFixActionWireV1: Encodable {
    let id: String
    let kind: String
    let title: String
    let icon: String
    let prompt: String?
    let isEnabled: Bool

    init(action: TextFixAction) {
        id = action.id
        kind = action.kind.rawValue
        title = action.title
        icon = action.icon.rawValue
        prompt = action.prompt
        isEnabled = action.isEnabled
    }
}
