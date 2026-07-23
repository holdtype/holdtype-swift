import UIKit

@MainActor
extension KeyboardViewController {
    var currentKeyboardFixPresentation:
        KeyboardFixExtensionPresentation {
        fixRuntime.refreshAvailability()
        return fixRuntime.presentation
    }

    func makeKeyboardFixRuntime() -> KeyboardFixExtensionRuntime {
        let runtime = KeyboardFixExtensionRuntime(
            dependencies: .live(
                currentTarget: { [weak self] in
                    self?.currentKeyboardFixTarget
                },
                applyOutput: { [weak self] output, identity in
                    self?.applyKeyboardFixOutput(
                        output,
                        identity: identity
                    ) ?? false
                },
                openContainingApp: { [weak self] url, onFailure in
                    guard let self else {
                        onFailure()
                        return
                    }
                    openContainingApp(url, onFailure: onFailure)
                },
                hasFullAccess: { [weak self] in
                    self?.hasSharedContainerAccess == true
                },
                dictationIsBusy: { [weak self] in
                    self?.keyboardFixDictationIsBusy == true
                }
            )
        )
        runtime.onPresentationChanged = { [weak self] _ in
            self?.render()
        }
        keyboardView.onFixesVisibilityChanged = {
            [weak runtime] isVisible in
            if isVisible {
                runtime?.reloadMetadata()
                runtime?.refreshAvailability()
            } else {
                runtime?.cancelActiveRequest()
            }
        }
        keyboardView.onFixRequested = { [weak runtime] actionIdentifier in
            runtime?.activate(actionIdentifier: actionIdentifier)
        }
        return runtime
    }

    private var currentKeyboardFixTarget:
        KeyboardFixExtensionTarget? {
        let documentProxy = activeDocumentProxy
        guard let documentIdentifier = dependencies.loadDocumentIdentifier(
            documentProxy
        ),
        let selectedText = documentProxy.selectedText,
        KeyboardFixBridgeValidation.containsVisibleContent(selectedText),
        selectedText.utf8.count
            <= KeyboardFixBridgeConfiguration.maximumSourceUTF8Bytes
        else {
            return nil
        }
        return KeyboardFixExtensionTarget(
            documentIdentifier: documentIdentifier.uuidString,
            selectedText: selectedText
        )
    }

    private var keyboardFixDictationIsBusy: Bool {
        switch currentDictationPresentation.voiceStage {
        case .ready:
            false
        case .opening, .starting, .listening, .processing:
            true
        }
    }

    private func applyKeyboardFixOutput(
        _ output: String,
        identity: KeyboardFixRequestIdentity
    ) -> Bool {
        guard currentKeyboardFixTarget?.matches(identity) == true,
              insertionGate.beginEvent()
        else {
            return false
        }
        defer { insertionGate.endEvent() }
        activeDocumentProxy.insertText(output)
        return true
    }
}
