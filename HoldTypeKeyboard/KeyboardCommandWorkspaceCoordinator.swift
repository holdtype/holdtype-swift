import UIKit

/// Owns the mutually exclusive Quick Insert and Fixes workspaces.
///
/// `BrandStageKeyboardView` continues to own layout and styling. This
/// coordinator owns only workspace state, touch routing, and accessibility
/// focus transitions.
@MainActor
final class KeyboardCommandWorkspaceCoordinator: NSObject {
    var onFixesVisibilityChanged: ((Bool) -> Void)?
    var onFixRequested: ((String) -> Void)?
    var onBeforeWorkspaceToggle: (() -> Void)?

    private let quickInsertButton: UIButton
    private let quickInsertStage: UIView
    private let quickInsertButtons: () -> [UIButton]
    private let fixesButton: UIButton
    private let fixesStage: KeyboardFixesPanelView
    private let voiceStage: UIView
    private let voiceWaveformView: KeyboardVoiceWaveformView
    private let stageContainer: UIView
    private let activeVoiceAccessibilityTarget: UIView
    private var renderedStatus: KeyboardVoiceStatus?
    private var quickInsertIsPresented = false
    private var fixesIsPresented = false

    init(
        quickInsertButton: UIButton,
        quickInsertStage: UIView,
        quickInsertButtons: @escaping () -> [UIButton],
        fixesButton: UIButton,
        fixesStage: KeyboardFixesPanelView,
        voiceStage: UIView,
        voiceWaveformView: KeyboardVoiceWaveformView,
        stageContainer: UIView,
        activeVoiceAccessibilityTarget: UIView
    ) {
        self.quickInsertButton = quickInsertButton
        self.quickInsertStage = quickInsertStage
        self.quickInsertButtons = quickInsertButtons
        self.fixesButton = fixesButton
        self.fixesStage = fixesStage
        self.voiceStage = voiceStage
        self.voiceWaveformView = voiceWaveformView
        self.stageContainer = stageContainer
        self.activeVoiceAccessibilityTarget = activeVoiceAccessibilityTarget
        super.init()
        configureInteractions()
    }

    func render(
        status: KeyboardVoiceStatus,
        fixes: KeyboardFixExtensionPresentation
    ) {
        renderedStatus = status
        fixesStage.render(fixes)
        updateWorkspaceVisibility()
        updateButtonPresentations()
    }

    func applyAppearance(
        traitCollection: UITraitCollection,
        inactiveBorder: UIColor,
        activeBorder: UIColor
    ) {
        updateButtonPresentation(
            quickInsertButton,
            isPresented: quickInsertIsPresented,
            closedImage: "face.smiling",
            openLabel: "Open Quick Insert",
            closeLabel: "Close Quick Insert",
            traitCollection: traitCollection,
            inactiveBorder: inactiveBorder,
            activeBorder: activeBorder
        )
        updateButtonPresentation(
            fixesButton,
            isPresented: fixesIsPresented,
            closedImage: "wand.and.stars",
            openLabel: "Open Fixes",
            closeLabel: "Close Fixes",
            traitCollection: traitCollection,
            inactiveBorder: inactiveBorder,
            activeBorder: activeBorder
        )
    }

    func closeAll() {
        closeQuickInsert()
        closeFixes(notify: true)
    }

    func closeQuickInsert() {
        guard quickInsertIsPresented else { return }
        quickInsertIsPresented = false
        updateWorkspaceVisibility()
        updateButtonPresentations()
    }

    private func configureInteractions() {
        quickInsertButton.addTarget(
            self,
            action: #selector(toggleQuickInsert),
            for: .touchUpInside
        )
        fixesButton.addTarget(
            self,
            action: #selector(toggleFixes),
            for: .touchUpInside
        )
        fixesStage.onActionRequested = { [weak self] actionIdentifier in
            self?.onFixRequested?(actionIdentifier)
        }
    }

    @objc private func toggleQuickInsert() {
        guard quickInsertButton.isEnabled else { return }
        onBeforeWorkspaceToggle?()
        closeFixes(notify: true)
        quickInsertIsPresented.toggle()
        updateWorkspaceVisibility()
        updateButtonPresentations()
        UIAccessibility.post(
            notification: .layoutChanged,
            argument: quickInsertIsPresented
                ? quickInsertButtons().first
                : activeVoiceAccessibilityTarget
        )
    }

    @objc private func toggleFixes() {
        onBeforeWorkspaceToggle?()
        closeQuickInsert()
        fixesIsPresented.toggle()
        updateWorkspaceVisibility()
        updateButtonPresentations()
        onFixesVisibilityChanged?(fixesIsPresented)
        UIAccessibility.post(
            notification: .layoutChanged,
            argument: fixesIsPresented
                ? fixesStage
                : activeVoiceAccessibilityTarget
        )
    }

    private func closeFixes(notify: Bool) {
        guard fixesIsPresented else { return }
        fixesIsPresented = false
        updateWorkspaceVisibility()
        updateButtonPresentations()
        if notify {
            onFixesVisibilityChanged?(false)
        }
    }

    private func updateWorkspaceVisibility() {
        quickInsertStage.isHidden = !quickInsertIsPresented
        fixesStage.isHidden = !fixesIsPresented
        let showsVoice = !quickInsertIsPresented && !fixesIsPresented
        voiceStage.isHidden = !showsVoice
        voiceWaveformView.setPresentationVisible(showsVoice)

        if quickInsertIsPresented {
            stageContainer.accessibilityValue = "Quick Insert"
        } else if fixesIsPresented {
            stageContainer.accessibilityValue = "Fixes"
        } else {
            stageContainer.accessibilityValue = renderedStatus?.rawValue
        }
    }

    private func updateButtonPresentations() {
        applyAppearance(
            traitCollection: stageContainer.traitCollection,
            inactiveBorder: inactiveBorderColor,
            activeBorder: activeBorderColor
        )
    }

    private func updateButtonPresentation(
        _ button: UIButton,
        isPresented: Bool,
        closedImage: String,
        openLabel: String,
        closeLabel: String,
        traitCollection: UITraitCollection,
        inactiveBorder: UIColor,
        activeBorder: UIColor
    ) {
        var configuration = button.configuration
        configuration?.image = UIImage(
            systemName: isPresented ? "xmark" : closedImage
        )
        button.configuration = configuration
        button.accessibilityLabel = isPresented ? closeLabel : openLabel
        button.accessibilityValue = isPresented ? "Open" : "Closed"
        button.layer.borderColor = (
            isPresented ? activeBorder : inactiveBorder
        ).resolvedColor(with: traitCollection).cgColor
        button.layer.borderWidth = isPresented
            ? 2
            : (UIAccessibility.isDarkerSystemColorsEnabled ? 1.5 : 0.5)
    }

    private var inactiveBorderColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.16)
                : UIColor(red: 0.73, green: 0.76, blue: 0.83, alpha: 1)
        }
    }

    private var activeBorderColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)
                : UIColor(red: 0.42, green: 0.36, blue: 0.96, alpha: 1)
        }
    }
}
