import Foundation
import HoldTypeDomain

struct IOSTextFixCatalogWireV2: Encodable {
    private let schemaVersion = 2
    private let actions: [IOSTextFixActionWireV2]

    init(catalog: TextFixCatalog) {
        actions = catalog.actions.map(IOSTextFixActionWireV2.init)
    }
}

private struct IOSTextFixActionWireV2: Encodable {
    let id: String
    let kind: String
    let title: String
    let icon: String
    let prompt: String?
    let processingProfile: String
    let customModel: String?
    let reasoningEffort: String?
    let isEnabled: Bool

    init(action: TextFixAction) {
        id = action.id
        kind = action.kind.rawValue
        title = action.title
        icon = action.icon.rawValue
        prompt = action.prompt
        processingProfile = action.processingProfile.preset.rawValue
        customModel = action.processingProfile.customModel
        reasoningEffort = action.processingProfile.customReasoningEffort?.rawValue
        isEnabled = action.isEnabled
    }
}
