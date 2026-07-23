import UIKit

@MainActor
extension KeyboardViewController {
    var activeDocumentProxy: any UITextDocumentProxy {
        if let documentProxyProviderOverride =
            dependencies.documentProxyProviderOverride {
            return documentProxyProviderOverride()
        }
        return dependencies.documentProxyOverride ?? textDocumentProxy
    }

    var hasSharedContainerAccess: Bool {
        dependencies.fullAccessOverride ?? hasFullAccess
    }
}
