import Foundation

struct IOSVoiceDraftTextTargetSnapshot: Equatable, Sendable {
    let text: String
    let selectedUTF16Range: NSRange

    init?(text: String, selectedRange: NSRange) {
        let utf16Count = text.utf16.count
        guard selectedRange.location != NSNotFound,
              selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location <= utf16Count,
              selectedRange.length <= utf16Count - selectedRange.location,
              Self.isScalarBoundary(
                selectedRange.location,
                in: text
              ),
              Self.isScalarBoundary(
                selectedRange.location + selectedRange.length,
                in: text
              ) else {
            return nil
        }
        self.text = text
        selectedUTF16Range = selectedRange
    }

    private static func isScalarBoundary(
        _ offset: Int,
        in text: String
    ) -> Bool {
        let utf16 = text.utf16
        let index = utf16.index(utf16.startIndex, offsetBy: offset)
        return index.samePosition(in: text) != nil
    }
}

struct IOSVoiceDraftResolvedTextTarget: Equatable, Sendable {
    let sourceText: String
    let utf16Range: NSRange

    init?(
        confirmedText: String,
        captured snapshot: IOSVoiceDraftTextTargetSnapshot?
    ) {
        let range: NSRange
        if let snapshot {
            guard snapshot.text == confirmedText else { return nil }
            range = snapshot.selectedUTF16Range.length > 0
                ? snapshot.selectedUTF16Range
                : NSRange(location: 0, length: confirmedText.utf16.count)
        } else {
            range = NSRange(location: 0, length: confirmedText.utf16.count)
        }
        guard let stringRange = Range(range, in: confirmedText) else {
            return nil
        }
        let sourceText = String(confirmedText[stringRange])
        guard !sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return nil
        }
        self.sourceText = sourceText
        utf16Range = range
    }

    func replacingSource(
        in currentText: String,
        with replacement: String
    ) -> String? {
        guard let stringRange = Range(utf16Range, in: currentText),
              String(currentText[stringRange]) == sourceText else {
            return nil
        }
        return currentText.replacingCharacters(
            in: stringRange,
            with: replacement
        )
    }
}
