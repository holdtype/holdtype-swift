import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboardView = BrandStageKeyboardView()
    private let deleteRepeater = KeyboardDeleteRepeater()
    private var cursorAccumulator = KeyboardCursorDragAccumulator()
    private var previousCursorLocationX: CGFloat?
    private var insertionGate = KeyboardInsertionEventGate()
    private var latestItem: KeyboardBridgeItem?
    private var recentItems: [KeyboardBridgeItem] = []
    private var historyPresentation = BrandStageHistoryPresentation.unavailable
    private var insertionStatusWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        hasDictationKey = false
        configureKeyboardView()
        reloadSharedSnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSharedSnapshot()
    }

    override func viewWillDisappear(_ animated: Bool) {
        deleteRepeater.stop()
        insertionStatusWorkItem?.cancel()
        super.viewWillDisappear(animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardView.updatePreferredHeight(for: traitCollection)
        render()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        insertionStatusWorkItem?.cancel()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        reloadSharedSnapshot()
    }

    private func configureKeyboardView() {
        view.backgroundColor = .clear
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        keyboardView.nextKeyboardButton.addTarget(
            self,
            action: #selector(handleInputModeList(from:with:)),
            for: .allTouchEvents
        )
        keyboardView.onHistoryRequested = { [weak self] in
            self?.keyboardView.showHistory()
        }
        keyboardView.onLatestRequested = { [weak self] in
            guard let self, let latestItem else { return }
            insert(latestItem)
        }
        keyboardView.onRecentResultRequested = { [weak self] resultID in
            guard let self,
                  let item = recentItems.first(where: {
                      $0.resultID == resultID && $0.expiresAt > Date()
                  }) else {
                return
            }
            insert(item)
        }
        keyboardView.onPunctuationRequested = { [weak self] character in
            self?.insertText(character)
        }
        keyboardView.onSpaceRequested = { [weak self] in
            self?.insertText(" ")
        }
        keyboardView.onSpaceCursorGesture = { [weak self] state, x in
            self?.handleCursorGesture(state: state, locationX: x)
        }
        keyboardView.onCursorStepRequested = { [weak self] offset in
            self?.textDocumentProxy.adjustTextPosition(
                byCharacterOffset: offset
            )
        }
        keyboardView.onDeleteStarted = { [weak self] in
            guard let self else { return }
            deleteRepeater.start { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            }
        }
        keyboardView.onDeleteStopped = { [weak self] in
            self?.deleteRepeater.stop()
        }
        keyboardView.onReturnRequested = { [weak self] in
            self?.insertText("\n")
        }
    }

    private func reloadSharedSnapshot() {
        guard hasFullAccess else {
            latestItem = nil
            recentItems = []
            historyPresentation = .unavailable
            render()
            return
        }

        do {
            let store = try KeyboardBridgeStore.appGroup()
            guard let snapshot = try store.load() else {
                latestItem = nil
                recentItems = []
                historyPresentation = .unavailable
                render()
                return
            }

            let now = Date()
            latestItem = snapshot.latestForInsertion(at: now)
            recentItems = snapshot.validRecentResults(at: now)
            if !snapshot.historyEnabled {
                historyPresentation = .disabled
            } else if recentItems.isEmpty {
                historyPresentation = .empty
            } else {
                historyPresentation = .results(recentItems)
            }
        } catch {
            latestItem = nil
            recentItems = []
            historyPresentation = .unavailable
        }
        render()
    }

    private func render(statusOverride: String? = nil) {
        keyboardView.render(
            BrandStageKeyboardPresentation(
                statusText: statusOverride ?? statusText,
                latestIsEnabled: latestItem != nil,
                history: historyPresentation,
                returnKey: KeyboardReturnKeyPresentation(
                    semantic: Self.returnSemantic(
                        for: textDocumentProxy.returnKeyType ?? .default
                    )
                ),
                returnIsEnabled: returnIsEnabled,
                showsInputModeSwitchKey: needsInputModeSwitchKey
            )
        )
    }

    private var statusText: String {
        if !hasFullAccess {
            return "Voice starts in HoldType · Full Access enables results"
        }
        if latestItem != nil {
            return "Latest result is ready"
        }
        return "Voice starts in the HoldType app"
    }

    private var returnIsEnabled: Bool {
        !((textDocumentProxy.enablesReturnKeyAutomatically ?? false)
            && !textDocumentProxy.hasText)
    }

    private func insert(_ item: KeyboardBridgeItem) {
        guard item.expiresAt > Date() else {
            reloadSharedSnapshot()
            return
        }
        insertText(item.text, confirmation: "Inserted")
    }

    private func insertText(
        _ text: String,
        confirmation: String? = nil
    ) {
        guard insertionGate.beginEvent() else { return }
        defer { insertionGate.endEvent() }
        textDocumentProxy.insertText(text)

        guard let confirmation else { return }
        insertionStatusWorkItem?.cancel()
        render(statusOverride: confirmation)
        let workItem = DispatchWorkItem { [weak self] in
            self?.reloadSharedSnapshot()
        }
        insertionStatusWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.8,
            execute: workItem
        )
    }

    private func handleCursorGesture(
        state: UIGestureRecognizer.State,
        locationX: CGFloat
    ) {
        switch state {
        case .began:
            cursorAccumulator.reset()
            previousCursorLocationX = locationX
        case .changed:
            guard let previousCursorLocationX else { return }
            self.previousCursorLocationX = locationX
            if let movement = cursorAccumulator.consume(
                horizontalDelta: Double(locationX - previousCursorLocationX)
            ) {
                textDocumentProxy.adjustTextPosition(
                    byCharacterOffset: movement.characterOffset
                )
            }
        case .ended, .cancelled, .failed:
            cursorAccumulator.reset()
            previousCursorLocationX = nil
        default:
            break
        }
    }

    private static func returnSemantic(
        for returnKeyType: UIReturnKeyType
    ) -> KeyboardReturnKeySemantic {
        switch returnKeyType {
        case .go:
            .go
        case .google, .search, .yahoo:
            .search
        case .join:
            .join
        case .next:
            .next
        case .route:
            .route
        case .send:
            .send
        case .done:
            .done
        case .emergencyCall:
            .emergencyCall
        case .continue:
            .continueAction
        case .default:
            .lineBreak
        @unknown default:
            .lineBreak
        }
    }
}

@MainActor
private final class KeyboardDeleteRepeater {
    private let profile = KeyboardDeleteRepeatProfile()
    private var timer: Timer?
    private var completedRepeats = 0
    private var action: (() -> Void)?

    func start(action: @escaping () -> Void) {
        stop()
        self.action = action
        action()
        schedule(after: profile.initialDelay)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        completedRepeats = 0
        action = nil
    }

    private func schedule(after interval: TimeInterval) {
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: false
        )
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func timerFired() {
        fire()
    }

    private func fire() {
        guard let action else { return }
        action()
        completedRepeats += 1
        schedule(
            after: profile.interval(
                afterCompletedRepeats: completedRepeats
            )
        )
    }
}
