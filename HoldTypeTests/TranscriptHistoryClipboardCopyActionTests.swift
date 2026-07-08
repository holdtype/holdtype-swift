//
//  TranscriptHistoryClipboardCopyActionTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import Testing
@testable import HoldType

struct TranscriptHistoryClipboardCopyActionTests {

    @Test func copyWritesHistoryRowTextToSystemClipboardWriter() throws {
        let writer = FakeSystemClipboardWriter()
        let action = TranscriptHistoryClipboardCopyAction(systemClipboardWriter: writer)
        let entry = try TranscriptHistoryEntry(
            transcriptText: "History row text",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en"
        )

        let result = action.copy(entry)

        #expect(result == .copied)
        #expect(result.statusText == "Copied history row to system clipboard.")
        #expect(writer.copiedTexts == ["History row text"])
    }

    @Test func copyReportsFailureWhenSystemClipboardWriteFails() throws {
        let writer = FakeSystemClipboardWriter(writeSucceeds: false)
        let action = TranscriptHistoryClipboardCopyAction(systemClipboardWriter: writer)
        let entry = try TranscriptHistoryEntry(
            transcriptText: "History row text",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil
        )

        let result = action.copy(entry)

        #expect(result == .failed)
        #expect(result.statusText == "Could not copy history row to system clipboard.")
        #expect(writer.copiedTexts == ["History row text"])
    }
}

private final class FakeSystemClipboardWriter: SystemClipboardWriting {
    private(set) var copiedTexts = [String]()
    private let writeSucceeds: Bool

    init(writeSucceeds: Bool = true) {
        self.writeSucceeds = writeSucceeds
    }

    func copyPlainText(_ text: String) -> Bool {
        copiedTexts.append(text)
        return writeSucceeds
    }
}
