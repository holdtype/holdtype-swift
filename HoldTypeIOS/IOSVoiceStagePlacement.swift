import CoreGraphics

struct IOSVoiceStagePlacement {
    static let minimumHeight: CGFloat = 300
    static let minimumDraftHeight: CGFloat = 250
    static let maximumDraftHeight: CGFloat = 340
    static let contentSpacing: CGFloat = 14
    static let minimumContentHeight =
        minimumDraftHeight + contentSpacing + minimumHeight

    static func activityCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    static func cancellationCenter(in size: CGSize) -> CGPoint {
        let center = activityCenter(in: size)
        return CGPoint(x: center.x + 78, y: center.y + 78)
    }
}
