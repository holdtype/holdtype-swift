import UIKit

final class IOSVoiceDraftUITextView: UITextView {
    var onLayout: ((IOSVoiceDraftUITextView) -> Void)?
    var onExternalTextAssignment: ((String) -> Void)?
    var onAccessibilityScroll: ((IOSVoiceDraftUITextView) -> Void)?
    var ignoresExternalTextAssignments = false

    override var text: String! {
        didSet {
            guard !ignoresExternalTextAssignments,
                  text != oldValue else {
                return
            }
            onExternalTextAssignment?(text ?? "")
        }
    }

    override var accessibilityValue: String? {
        get { text }
        set {
            let value = newValue ?? ""
            guard text != value else { return }
            text = value
        }
    }

    override func accessibilityScroll(
        _ direction: UIAccessibilityScrollDirection
    ) -> Bool {
        let didScroll = super.accessibilityScroll(direction)
        if didScroll {
            onAccessibilityScroll?(self)
        }
        return didScroll
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }
}
