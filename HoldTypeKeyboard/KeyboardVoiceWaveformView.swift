import QuartzCore
import UIKit

enum KeyboardVoiceWaveformPhase: Equatable {
    case ready
    case starting
    case listening
    case processing

    func motion(reduceMotion: Bool) -> KeyboardVoiceWaveformMotion {
        guard !reduceMotion else { return .staticSilhouette }
        switch self {
        case .ready:
            return .staticSilhouette
        case .starting:
            return .opacitySweep
        case .listening:
            return .listeningPulse
        case .processing:
            return .processingSweep
        }
    }
}

enum KeyboardVoiceWaveformMotion: Equatable {
    case staticSilhouette
    case opacitySweep
    case listeningPulse
    case processingSweep
}

/// Decorative phase-driven side waveforms for the keyboard Voice stage.
/// The extension does not receive microphone power and never presents these
/// bars as live metering.
final class KeyboardVoiceWaveformView: UIView {
    private let contentLayer = CALayer()
    private let leftBarLayers: [CALayer]
    private let rightBarLayers: [CALayer]
    private var accessibilityObservers: [NSObjectProtocol] = []
    private var renderedLayout: WaveformLayout?
    private(set) var phase: KeyboardVoiceWaveformPhase = .ready
    private(set) var presentationIsVisible = true

    override init(frame: CGRect) {
        leftBarLayers = Self.makeBarLayers()
        rightBarLayers = Self.makeBarLayers()
        super.init(frame: frame)
        configureHierarchy()
        configureAccessibilityObservers()
        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitAccessibilityContrast.self,
            UITraitDisplayScale.self,
        ]) { (view: KeyboardVoiceWaveformView, _) in
            view.renderedLayout = nil
            view.setNeedsLayout()
            view.applyAppearance()
        }
        applyAppearance()
    }

    isolated deinit {
        for observer in accessibilityObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentLayer.frame = bounds

        let layout = WaveformLayout(
            size: bounds.size,
            displayScale: traitCollection.displayScale
        )
        guard renderedLayout != layout else { return }
        renderedLayout = layout
        layoutBars(using: layout)
        applyAppearance()
        restartAnimations()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restartAnimations()
    }

    func render(_ phase: KeyboardVoiceWaveformPhase) {
        guard self.phase != phase else { return }
        self.phase = phase
        applyAppearance()
        restartAnimations()
    }

    func setPresentationVisible(_ isVisible: Bool) {
        guard presentationIsVisible != isVisible else { return }
        presentationIsVisible = isVisible
        restartAnimations()
    }

    var barCountPerSide: Int {
        leftBarLayers.count
    }

    var leftBarFrames: [CGRect] {
        leftBarLayers.map(\.frame)
    }

    var rightBarFrames: [CGRect] {
        rightBarLayers.map(\.frame)
    }

    var hasActiveAnimations: Bool {
        allBarLayers.contains { !($0.animationKeys() ?? []).isEmpty }
    }

    private var allBarLayers: [CALayer] {
        leftBarLayers + rightBarLayers
    }

    private func configureHierarchy() {
        isAccessibilityElement = false
        isUserInteractionEnabled = false
        layer.masksToBounds = false
        contentLayer.masksToBounds = false
        layer.addSublayer(contentLayer)
        for barLayer in allBarLayers {
            contentLayer.addSublayer(barLayer)
        }
    }

    private func configureAccessibilityObservers() {
        accessibilityObservers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartAnimations()
                }
            }
        )
        accessibilityObservers.append(
            NotificationCenter.default.addObserver(
                forName:
                    UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyAppearance()
                }
            }
        )
    }

    private func layoutBars(using layout: WaveformLayout) {
        guard layout.halfWidth > 0 else {
            for barLayer in allBarLayers {
                barLayer.frame = .zero
            }
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        for index in Self.waveformHeights.indices {
            let height = max(
                layout.minimumBarHeight,
                Self.waveformHeights[index] * layout.heightScale
            )
            let y = layout.pixelAligned(bounds.midY - height / 2)
            let barSize = CGSize(width: layout.barWidth, height: height)

            leftBarLayers[index].frame = CGRect(
                origin: CGPoint(
                    x: layout.pixelAligned(
                        layout.leftMinimumX + CGFloat(index) * layout.barStep
                    ),
                    y: y
                ),
                size: barSize
            )
            rightBarLayers[index].frame = CGRect(
                origin: CGPoint(
                    x: layout.pixelAligned(
                        layout.rightMaximumX
                            - layout.barWidth
                            - CGFloat(index) * layout.barStep
                    ),
                    y: y
                ),
                size: barSize
            )
        }
    }

    private func applyAppearance() {
        let accent = phase.accent.resolvedColor(with: traitCollection)
        let highContrast = traitCollection.accessibilityContrast == .high
            || UIAccessibility.isDarkerSystemColorsEnabled
        let allowsGlow = !UIAccessibility.isReduceTransparencyEnabled

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        for (index, barLayer) in leftBarLayers.enumerated() {
            applyAppearance(
                to: barLayer,
                index: index,
                accent: accent,
                highContrast: highContrast,
                allowsGlow: allowsGlow
            )
        }
        for (index, barLayer) in rightBarLayers.enumerated() {
            applyAppearance(
                to: barLayer,
                index: index,
                accent: accent,
                highContrast: highContrast,
                allowsGlow: allowsGlow
            )
        }
    }

    private func applyAppearance(
        to barLayer: CALayer,
        index: Int,
        accent: UIColor,
        highContrast: Bool,
        allowsGlow: Bool
    ) {
        let heightRatio = Self.waveformHeights[index]
            / (Self.waveformHeights.max() ?? 1)
        let baseOpacity = Float(
            min(1, (highContrast ? 0.54 : 0.34) + heightRatio * 0.5)
        )
        barLayer.backgroundColor = accent.cgColor
        barLayer.opacity = baseOpacity
        barLayer.cornerRadius = barLayer.bounds.width / 2
        barLayer.shadowColor = accent.cgColor
        barLayer.shadowOpacity = allowsGlow ? 0.18 : 0
        barLayer.shadowRadius = allowsGlow ? 1.5 : 0
        barLayer.shadowOffset = .zero
        barLayer.shadowPath = CGPath(
            roundedRect: barLayer.bounds,
            cornerWidth: barLayer.cornerRadius,
            cornerHeight: barLayer.cornerRadius,
            transform: nil
        )
    }

    private func restartAnimations() {
        for barLayer in allBarLayers {
            barLayer.removeAllAnimations()
        }

        let motion = phase.motion(
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
        guard window != nil,
              presentationIsVisible,
              motion != .staticSilhouette else {
            return
        }

        let startTime = CACurrentMediaTime()
        for (index, barLayer) in leftBarLayers.enumerated() {
            addAnimation(
                motion,
                to: barLayer,
                index: index,
                sideOffset: 0,
                startTime: startTime
            )
        }
        for (index, barLayer) in rightBarLayers.enumerated() {
            addAnimation(
                motion,
                to: barLayer,
                index: index,
                sideOffset: motion == .listeningPulse ? 0.11 : 0,
                startTime: startTime
            )
        }
    }

    private func addAnimation(
        _ motion: KeyboardVoiceWaveformMotion,
        to barLayer: CALayer,
        index: Int,
        sideOffset: CFTimeInterval,
        startTime: CFTimeInterval
    ) {
        let baseOpacity = barLayer.opacity
        let animation: CAAnimation
        let delay: CFTimeInterval

        switch motion {
        case .staticSilhouette:
            return
        case .opacitySweep:
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [
                baseOpacity * 0.62,
                min(1, baseOpacity * 1.08),
                baseOpacity * 0.62,
            ]
            opacity.keyTimes = [0, 0.5, 1]
            opacity.duration = 1.8
            animation = opacity
            delay = Double(index) * 0.035
        case .listeningPulse:
            let scale = CAKeyframeAnimation(keyPath: "transform.scale.y")
            scale.values = [0.64, 1.08, 0.82, 1]
            scale.keyTimes = [0, 0.32, 0.7, 1]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [
                baseOpacity * 0.72,
                min(1, baseOpacity * 1.12),
                baseOpacity * 0.82,
                baseOpacity,
            ]
            opacity.keyTimes = scale.keyTimes

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 0.92
            animation = group
            delay = Double(index) * 0.028 + sideOffset
        case .processingSweep:
            let scale = CAKeyframeAnimation(keyPath: "transform.scale.y")
            scale.values = [0.78, 1.06, 0.78]
            scale.keyTimes = [0, 0.5, 1]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [
                baseOpacity * 0.55,
                min(1, baseOpacity * 1.08),
                baseOpacity * 0.55,
            ]
            opacity.keyTimes = scale.keyTimes

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 1.55
            animation = group
            delay = Double(index) * 0.045
        }

        animation.beginTime = startTime + delay
        animation.repeatCount = .infinity
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        barLayer.add(animation, forKey: "keyboard.voice.waveform")
    }

    private static func makeBarLayers() -> [CALayer] {
        waveformHeights.map { _ in CALayer() }
    }

    fileprivate static let waveformHeights: [CGFloat] = [
        3, 4, 5, 6, 8, 10, 14, 20, 28, 36, 24,
        30, 22, 18, 16, 12, 9, 7, 5, 4, 3,
    ]
}

private struct WaveformLayout: Equatable {
    let size: CGSize
    let displayScale: CGFloat
    let indicatorDiameter: CGFloat
    let centerGap: CGFloat
    let halfWidth: CGFloat
    let barWidth: CGFloat
    let barStep: CGFloat
    let heightScale: CGFloat
    let minimumBarHeight: CGFloat
    let leftMinimumX: CGFloat
    let rightMaximumX: CGFloat

    init(size: CGSize, displayScale: CGFloat) {
        self.size = size
        self.displayScale = max(1, displayScale)

        let usesCompactGeometry = size.height < 112
        indicatorDiameter = usesCompactGeometry ? 88 : 128
        centerGap = usesCompactGeometry ? 8 : 12
        heightScale = min(1, max(0, size.height / 128))
        minimumBarHeight = usesCompactGeometry ? 1.5 : 2
        barWidth = usesCompactGeometry ? 1.5 : 2

        let availableHalfWidth = max(
            0,
            (size.width - indicatorDiameter - centerGap * 2) / 2
        )
        halfWidth = min(usesCompactGeometry ? 94 : 112, availableHalfWidth)
        barStep = halfWidth > barWidth
            ? (halfWidth - barWidth)
                / CGFloat(KeyboardVoiceWaveformView.waveformHeights.count - 1)
            : 0

        let contentWidth = indicatorDiameter + centerGap * 2 + halfWidth * 2
        leftMinimumX = (size.width - contentWidth) / 2
        rightMaximumX = size.width - leftMinimumX
    }

    func pixelAligned(_ value: CGFloat) -> CGFloat {
        (value * displayScale).rounded() / displayScale
    }
}

private extension KeyboardVoiceWaveformPhase {
    var accent: UIColor {
        switch self {
        case .ready, .starting, .listening:
            UIColor(red: 0.031, green: 0.545, blue: 0.941, alpha: 1)
        case .processing:
            UIColor(red: 0.388, green: 0.078, blue: 0.894, alpha: 1)
        }
    }
}
