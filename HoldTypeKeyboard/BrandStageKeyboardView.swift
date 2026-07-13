import UIKit

enum BrandStageHistoryPresentation: Equatable {
    case unavailable
    case disabled
    case empty
    case results([KeyboardBridgeItem])
}

struct BrandStageKeyboardPresentation: Equatable {
    let statusText: String
    let latestIsEnabled: Bool
    let history: BrandStageHistoryPresentation
    let returnKey: KeyboardReturnKeyPresentation
    let returnIsEnabled: Bool
    let showsInputModeSwitchKey: Bool
}

/// The selected Brand Stage Adaptive composition. The controller owns document
/// proxy behavior; this view owns only layout, appearance, and touch routing.
final class BrandStageKeyboardView: UIView {
    var onHistoryRequested: (() -> Void)?
    var onLatestRequested: (() -> Void)?
    var onRecentResultRequested: ((UUID) -> Void)?
    var onPunctuationRequested: ((String) -> Void)?
    var onSpaceRequested: (() -> Void)?
    var onSpaceCursorGesture: ((UIGestureRecognizer.State, CGFloat) -> Void)?
    var onCursorStepRequested: ((Int) -> Void)?
    var onDeleteStarted: (() -> Void)?
    var onDeleteStopped: (() -> Void)?
    var onReturnRequested: (() -> Void)?

    let nextKeyboardButton = UIButton(type: .system)

    private let rootStack = UIStackView()
    private let historyButton = UIButton(type: .system)
    private let latestButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let stageContainer = UIView()
    private let voiceStage = UIStackView()
    private let historyStage = UIStackView()
    private let historyMessageLabel = UILabel()
    private let historyResultsScrollView = UIScrollView()
    private let historyResultsStack = UIStackView()
    private let spaceButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)
    private let microphoneView = UIView()
    private let microphoneImageView = UIImageView()
    private let waveformStack = UIStackView()
    private var preferredHeightConstraint: NSLayoutConstraint?
    private var historyPresentation = BrandStageHistoryPresentation.unavailable
    private var isShowingHistory = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureInteractions()
        applyAppearance()
        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitVerticalSizeClass.self,
        ]) { (view: BrandStageKeyboardView, _) in
            view.applyAppearance()
            view.updatePreferredHeight(for: view.traitCollection)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func render(_ presentation: BrandStageKeyboardPresentation) {
        statusLabel.text = presentation.statusText
        latestButton.isEnabled = presentation.latestIsEnabled
        historyPresentation = presentation.history
        nextKeyboardButton.isHidden = !presentation.showsInputModeSwitchKey
        returnButton.isEnabled = presentation.returnIsEnabled
        renderReturnKey(presentation.returnKey)
        if isShowingHistory {
            renderHistoryStage()
        }
    }

    func showHistory() {
        guard !isShowingHistory else { return }
        isShowingHistory = true
        renderHistoryStage()
        voiceStage.isHidden = true
        historyStage.isHidden = false
        UIAccessibility.post(
            notification: .layoutChanged,
            argument: historyMessageLabel
        )
    }

    func showVoiceStage() {
        guard isShowingHistory else { return }
        isShowingHistory = false
        historyStage.isHidden = true
        voiceStage.isHidden = false
        UIAccessibility.post(notification: .layoutChanged, argument: statusLabel)
    }

    func updatePreferredHeight(for traitCollection: UITraitCollection) {
        preferredHeightConstraint?.constant = traitCollection.verticalSizeClass
            == .compact ? 224 : 272
    }

    private func configureHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Self.keyboardBackground

        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.axis = .vertical
        rootStack.spacing = 8
        addSubview(rootStack)

        let topRail = makeTopRail()
        configureVoiceStage()
        configureHistoryStage()
        stageContainer.translatesAutoresizingMaskIntoConstraints = false
        stageContainer.addSubview(voiceStage)
        stageContainer.addSubview(historyStage)
        NSLayoutConstraint.activate([
            voiceStage.leadingAnchor.constraint(equalTo: stageContainer.leadingAnchor),
            voiceStage.trailingAnchor.constraint(equalTo: stageContainer.trailingAnchor),
            voiceStage.topAnchor.constraint(equalTo: stageContainer.topAnchor),
            voiceStage.bottomAnchor.constraint(equalTo: stageContainer.bottomAnchor),
            historyStage.leadingAnchor.constraint(equalTo: stageContainer.leadingAnchor),
            historyStage.trailingAnchor.constraint(equalTo: stageContainer.trailingAnchor),
            historyStage.topAnchor.constraint(equalTo: stageContainer.topAnchor),
            historyStage.bottomAnchor.constraint(equalTo: stageContainer.bottomAnchor),
            stageContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
        ])
        historyStage.isHidden = true

        let punctuationRow = makePunctuationRow()
        let editingRow = makeEditingRow()
        rootStack.addArrangedSubview(topRail)
        rootStack.addArrangedSubview(stageContainer)
        rootStack.addArrangedSubview(punctuationRow)
        rootStack.addArrangedSubview(editingRow)

        let height = heightAnchor.constraint(equalToConstant: 272)
        height.priority = UILayoutPriority(999)
        preferredHeightConstraint = height

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            rootStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
            height,
            topRail.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            punctuationRow.heightAnchor.constraint(equalToConstant: 44),
            editingRow.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func makeTopRail() -> UIStackView {
        configureKey(
            historyButton,
            title: "History",
            systemImage: "clock.arrow.circlepath",
            accessibilityLabel: "Open recent results"
        )
        configureKey(
            latestButton,
            title: "Latest",
            systemImage: "arrow.down.doc",
            accessibilityLabel: "Insert latest"
        )

        let logo = UIImageView(
            image: UIImage(named: "HoldTypeMark")
                ?? UIImage(systemName: "waveform.circle.fill")
        )
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.contentMode = .scaleAspectFit
        logo.isAccessibilityElement = false
        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.accessibilityIdentifier = "keyboard.brand-stage.status"

        let identity = UIStackView(arrangedSubviews: [logo, statusLabel])
        identity.axis = .vertical
        identity.alignment = .center
        identity.spacing = 1
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 30),
            logo.heightAnchor.constraint(equalToConstant: 30),
        ])

        let rail = UIStackView(
            arrangedSubviews: [historyButton, identity, latestButton]
        )
        rail.axis = .horizontal
        rail.alignment = .center
        rail.distribution = .equalCentering
        rail.spacing = 8
        historyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
            .isActive = true
        latestButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96)
            .isActive = true
        return rail
    }

    private func configureVoiceStage() {
        voiceStage.translatesAutoresizingMaskIntoConstraints = false
        voiceStage.axis = .horizontal
        voiceStage.alignment = .center
        voiceStage.distribution = .fill
        voiceStage.spacing = 10

        configureWaveform()
        let leftWaveform = waveformStack
        let rightWaveform = mirroredWaveform()
        voiceStage.addArrangedSubview(leftWaveform)
        voiceStage.addArrangedSubview(microphoneView)
        voiceStage.addArrangedSubview(rightWaveform)
        leftWaveform.widthAnchor.constraint(greaterThanOrEqualToConstant: 70)
            .isActive = true
        rightWaveform.widthAnchor.constraint(equalTo: leftWaveform.widthAnchor)
            .isActive = true
        microphoneView.widthAnchor.constraint(equalToConstant: 66).isActive = true
        microphoneView.heightAnchor.constraint(equalToConstant: 66).isActive = true

        microphoneView.layer.cornerRadius = 33
        microphoneView.layer.borderWidth = 2
        microphoneView.isUserInteractionEnabled = false
        microphoneView.isAccessibilityElement = false
        microphoneImageView.translatesAutoresizingMaskIntoConstraints = false
        microphoneImageView.image = UIImage(systemName: "mic.fill")
        microphoneImageView.contentMode = .scaleAspectFit
        microphoneImageView.tintColor = .white
        microphoneView.addSubview(microphoneImageView)
        NSLayoutConstraint.activate([
            microphoneImageView.centerXAnchor.constraint(equalTo: microphoneView.centerXAnchor),
            microphoneImageView.centerYAnchor.constraint(equalTo: microphoneView.centerYAnchor),
            microphoneImageView.widthAnchor.constraint(equalToConstant: 28),
            microphoneImageView.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func configureHistoryStage() {
        historyStage.translatesAutoresizingMaskIntoConstraints = false
        historyStage.axis = .vertical
        historyStage.spacing = 6

        let closeButton = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Recent results"
        configuration.image = UIImage(systemName: "xmark.circle.fill")
        configuration.imagePlacement = .trailing
        configuration.baseForegroundColor = .label
        closeButton.configuration = configuration
        closeButton.contentHorizontalAlignment = .fill
        closeButton.accessibilityLabel = "Close recent results"
        closeButton.addTarget(
            self,
            action: #selector(closeHistoryTapped),
            for: .touchUpInside
        )

        historyMessageLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        historyMessageLabel.adjustsFontForContentSizeCategory = true
        historyMessageLabel.textColor = .secondaryLabel
        historyMessageLabel.textAlignment = .center
        historyMessageLabel.numberOfLines = 2

        historyResultsScrollView.showsHorizontalScrollIndicator = false
        historyResultsScrollView.alwaysBounceHorizontal = true
        historyResultsStack.translatesAutoresizingMaskIntoConstraints = false
        historyResultsStack.axis = .horizontal
        historyResultsStack.spacing = 8
        historyResultsScrollView.addSubview(historyResultsStack)
        NSLayoutConstraint.activate([
            historyResultsStack.leadingAnchor.constraint(equalTo: historyResultsScrollView.contentLayoutGuide.leadingAnchor),
            historyResultsStack.trailingAnchor.constraint(equalTo: historyResultsScrollView.contentLayoutGuide.trailingAnchor),
            historyResultsStack.topAnchor.constraint(equalTo: historyResultsScrollView.contentLayoutGuide.topAnchor),
            historyResultsStack.bottomAnchor.constraint(equalTo: historyResultsScrollView.contentLayoutGuide.bottomAnchor),
            historyResultsStack.heightAnchor.constraint(equalTo: historyResultsScrollView.frameLayoutGuide.heightAnchor),
        ])

        historyStage.addArrangedSubview(closeButton)
        historyStage.addArrangedSubview(historyMessageLabel)
        historyStage.addArrangedSubview(historyResultsScrollView)
    }

    private func makePunctuationRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        for (character, name) in [
            (".", "Period"),
            (",", "Comma"),
            ("?", "Question mark"),
            ("!", "Exclamation mark"),
        ] {
            let button = UIButton(type: .system)
            configureKey(button, title: character, accessibilityLabel: name)
            button.addAction(UIAction { [weak self] _ in
                self?.onPunctuationRequested?(character)
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeEditingRow() -> UIStackView {
        configureKey(
            nextKeyboardButton,
            systemImage: "globe",
            accessibilityLabel: "Next keyboard"
        )
        configureKey(
            spaceButton,
            systemImage: "arrow.left.and.right",
            accessibilityLabel: "Space"
        )
        spaceButton.accessibilityHint =
            "Tap for a space. Touch and drag to move the cursor."
        configureKey(
            deleteButton,
            systemImage: "delete.left",
            accessibilityLabel: "Delete"
        )
        configureKey(
            returnButton,
            systemImage: "return",
            accessibilityLabel: "Return"
        )

        let row = UIStackView(
            arrangedSubviews: [
                nextKeyboardButton,
                spaceButton,
                deleteButton,
                returnButton,
            ]
        )
        row.axis = .horizontal
        row.spacing = 8
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 48)
            .isActive = true
        deleteButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        returnButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 64)
            .isActive = true
        return row
    }

    private func configureWaveform() {
        waveformStack.axis = .horizontal
        waveformStack.alignment = .center
        waveformStack.distribution = .equalCentering
        waveformStack.spacing = 3
        for height: CGFloat in [5, 9, 14, 20, 14, 9, 5] {
            waveformStack.addArrangedSubview(makeWaveformBar(height: height))
        }
    }

    private func mirroredWaveform() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.spacing = 3
        for height: CGFloat in [5, 9, 14, 20, 14, 9, 5] {
            stack.addArrangedSubview(makeWaveformBar(height: height))
        }
        return stack
    }

    private func makeWaveformBar(height: CGFloat) -> UIView {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = Self.waveformColor
        bar.layer.cornerRadius = 1.5
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: 3),
            bar.heightAnchor.constraint(equalToConstant: height),
        ])
        return bar
    }

    private func configureInteractions() {
        historyButton.addTarget(
            self,
            action: #selector(historyTapped),
            for: .touchUpInside
        )
        latestButton.addTarget(
            self,
            action: #selector(latestTapped),
            for: .touchUpInside
        )
        spaceButton.addTarget(
            self,
            action: #selector(spaceTapped),
            for: .touchUpInside
        )
        let cursorGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(spaceCursorGestureChanged(_:))
        )
        cursorGesture.minimumPressDuration = 0.30
        cursorGesture.cancelsTouchesInView = true
        spaceButton.addGestureRecognizer(cursorGesture)
        spaceButton.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: "Move cursor left",
                target: self,
                selector: #selector(moveCursorLeft)
            ),
            UIAccessibilityCustomAction(
                name: "Move cursor right",
                target: self,
                selector: #selector(moveCursorRight)
            ),
        ]

        deleteButton.addTarget(
            self,
            action: #selector(deleteStarted),
            for: .touchDown
        )
        for event: UIControl.Event in [
            .touchUpInside,
            .touchUpOutside,
            .touchCancel,
            .touchDragExit,
        ] {
            deleteButton.addTarget(
                self,
                action: #selector(deleteStopped),
                for: event
            )
        }
        returnButton.addTarget(
            self,
            action: #selector(returnTapped),
            for: .touchUpInside
        )
    }

    private func renderHistoryStage() {
        historyResultsStack.arrangedSubviews.forEach { view in
            historyResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch historyPresentation {
        case .unavailable:
            historyMessageLabel.text = "Recent results aren’t available."
            historyResultsScrollView.isHidden = true
        case .disabled:
            historyMessageLabel.text = "Save History is off in HoldType."
            historyResultsScrollView.isHidden = true
        case .empty:
            historyMessageLabel.text = "No recent results yet."
            historyResultsScrollView.isHidden = true
        case .results(let items):
            historyMessageLabel.text = "Choose a result to insert"
            historyResultsScrollView.isHidden = false
            for item in items {
                let button = UIButton(type: .system)
                configureKey(
                    button,
                    title: Self.preview(item.text),
                    accessibilityLabel: "Insert recent result, \(item.text)"
                )
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.contentHorizontalAlignment = .leading
                button.widthAnchor.constraint(equalToConstant: 176).isActive = true
                button.addAction(UIAction { [weak self] _ in
                    self?.onRecentResultRequested?(item.resultID)
                }, for: .touchUpInside)
                historyResultsStack.addArrangedSubview(button)
            }
        }
    }

    private func renderReturnKey(_ presentation: KeyboardReturnKeyPresentation) {
        var configuration = returnButton.configuration
        switch presentation {
        case .returnSymbol:
            configuration?.title = nil
            configuration?.image = UIImage(systemName: "return")
        case .title(let title):
            configuration?.title = title
            configuration?.image = nil
        }
        returnButton.configuration = configuration
        returnButton.accessibilityLabel = presentation.accessibilityLabel
    }

    private func configureKey(
        _ button: UIButton,
        title: String? = nil,
        systemImage: String? = nil,
        accessibilityLabel: String
    ) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = systemImage.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = 6
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = Self.keyBackground
        configuration.baseForegroundColor = Self.keyForeground
        configuration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFontMetrics(forTextStyle: .body).scaledFont(
                    for: UIFont.systemFont(ofSize: 16, weight: .medium),
                    maximumPointSize: 20
                )
                return outgoing
            }
        button.configuration = configuration
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits.insert(.keyboardKey)
    }

    private func applyAppearance() {
        backgroundColor = Self.keyboardBackground
        statusLabel.textColor = .secondaryLabel
        microphoneView.backgroundColor = Self.microphoneBackground
        microphoneView.layer.borderColor = Self.microphoneBorder.resolvedColor(
            with: traitCollection
        ).cgColor
        let contrast = UIAccessibility.isDarkerSystemColorsEnabled
        microphoneView.layer.borderWidth = contrast ? 3 : 2
    }

    private static func preview(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > 48 else { return singleLine }
        return String(singleLine.prefix(47)) + "…"
    }

    @objc private func historyTapped() {
        onHistoryRequested?()
    }

    @objc private func latestTapped() {
        onLatestRequested?()
    }

    @objc private func closeHistoryTapped() {
        showVoiceStage()
    }

    @objc private func spaceTapped() {
        onSpaceRequested?()
    }

    @objc private func spaceCursorGestureChanged(
        _ gesture: UILongPressGestureRecognizer
    ) {
        onSpaceCursorGesture?(gesture.state, gesture.location(in: spaceButton).x)
    }

    @objc private func moveCursorLeft() -> Bool {
        onCursorStepRequested?(-1)
        return true
    }

    @objc private func moveCursorRight() -> Bool {
        onCursorStepRequested?(1)
        return true
    }

    @objc private func deleteStarted() {
        onDeleteStarted?()
    }

    @objc private func deleteStopped() {
        onDeleteStopped?()
    }

    @objc private func returnTapped() {
        onReturnRequested?()
    }

    private static let keyboardBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.035, green: 0.055, blue: 0.10, alpha: 1)
            : UIColor.systemGroupedBackground
    }

    private static let keyBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.13)
            : UIColor.secondarySystemGroupedBackground
    }

    private static let keyForeground = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .label
    }

    private static let waveformColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.62, blue: 0.84, alpha: 0.75)
            : UIColor(red: 0.32, green: 0.40, blue: 0.70, alpha: 0.55)
    }

    private static let microphoneBackground = UIColor { traits in
        let alpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.58 : 0.50
        return UIColor(red: 0.32, green: 0.40, blue: 0.91, alpha: alpha)
    }

    private static let microphoneBorder = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.52, green: 0.30, blue: 0.95, alpha: 0.9)
            : UIColor(red: 0.32, green: 0.40, blue: 0.91, alpha: 0.75)
    }
}
