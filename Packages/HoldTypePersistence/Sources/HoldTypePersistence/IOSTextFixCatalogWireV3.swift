import Foundation
import HoldTypeDomain

struct IOSTextFixCatalogWireV3: Encodable {
    private let schemaVersion = 3
    private let actions: [IOSTextFixActionWireV3]

    init(catalog: TextFixCatalog) {
        actions = catalog.actions.map(IOSTextFixActionWireV3.init)
    }
}

private struct IOSTextFixActionWireV3: Encodable {
    let id: String
    let kind: String
    let title: String
    let icon: String
    let prompt: String?
    let processingProfile: String
    let customModel: String?
    let reasoningEffort: String?
    let usesBuiltInWritingSkill: Bool
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
        usesBuiltInWritingSkill = action.usesBuiltInWritingSkill
        isEnabled = action.isEnabled
    }
}
