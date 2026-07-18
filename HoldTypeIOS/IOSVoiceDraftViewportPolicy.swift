import UIKit

enum IOSVoiceDraftTypographyTier: Equatable {
    case large
    case compact
}

struct IOSVoiceDraftTypographyPolicy {
    static let compactPointSize: CGFloat = 18
    static let returnHeadroomInLines: CGFloat = 1.5

    static func resolve(
        current: IOSVoiceDraftTypographyTier,
        largeContentHeight: CGFloat,
        viewportHeight: CGFloat,
        largeLineHeight: CGFloat,
        usesAccessibilitySize: Bool
    ) -> IOSVoiceDraftTypographyTier {
        guard !usesAccessibilitySize else { return .large }
        guard viewportHeight > 0 else { return current }

        switch current {
        case .large:
            return largeContentHeight > viewportHeight ? .compact : .large
        case .compact:
            let returnThreshold = viewportHeight
                - (largeLineHeight * returnHeadroomInLines)
            return largeContentHeight <= returnThreshold ? .large : .compact
        }
    }
}

enum IOSVoiceDraftScrollCommand: Equatable {
    case none
    case top
    case bottom
}

enum IOSVoiceDraftFocusCommand: Equatable {
    case none
    case becomeFirstResponder
    case resignFirstResponder
}

struct IOSVoiceDraftFocusPolicy {
    static func resolve(
        wantsFocus: Bool,
        isEditable: Bool,
        isFirstResponder: Bool
    ) -> IOSVoiceDraftFocusCommand {
        let shouldBeFirstResponder = wantsFocus && isEditable
        if shouldBeFirstResponder, !isFirstResponder {
            return .becomeFirstResponder
        }
        if !shouldBeFirstResponder, isFirstResponder {
            return .resignFirstResponder
        }
        return .none
    }
}

struct IOSVoiceDraftFollowTailState: Equatable {
    private(set) var isFollowingTail = true
    private(set) var hasUnseenAppend = false

    mutating func receive(
        _ change: IOSVoiceDraftContentChangeKind,
        wasAtBottom: Bool
    ) -> IOSVoiceDraftScrollCommand {
        switch change {
        case .append:
            guard isFollowingTail, wasAtBottom else {
                hasUnseenAppend = true
                return .none
            }
            hasUnseenAppend = false
            return .bottom
        case .replace:
            isFollowingTail = true
            hasUnseenAppend = false
            return .top
        case .preservePosition:
            return .none
        }
    }

    mutating func suspend() {
        isFollowingTail = false
    }

    mutating func userScrolled(isAtBottom: Bool) {
        isFollowingTail = isAtBottom
        if isAtBottom {
            hasUnseenAppend = false
        }
    }

    mutating func jumpToLatest() {
        isFollowingTail = true
        hasUnseenAppend = false
    }
}
