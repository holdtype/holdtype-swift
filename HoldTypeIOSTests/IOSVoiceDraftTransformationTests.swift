import Foundation
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceDraftTransformationTests {
    @Test func unicodeSelectionIsSplicedWithOneUndoRedoMutation()
        async throws {
        try await withOwner(text: "Say 👩🏽‍💻 now") { owner in
            let original = owner.text
            let selectedRange = (original as NSString).range(of: "👩🏽‍💻")
            let snapshot = try #require(
                IOSVoiceDraftTextTargetSnapshot(
                    text: original,
                    selectedRange: selectedRange
                )
            )
            let reservation = try #require(
                owner.beginTransformation(targeting: snapshot)
            )

            #expect(reservation.text == "👩🏽‍💻")
            #expect(reservation.sourceUTF16Range == selectedRange)
            #expect(
                await owner.commitTransformation(
                    "HoldType",
                    reservation: reservation
                ) == .confirmed(changed: true)
            )
            #expect(owner.text == "Say HoldType now")

            #expect(await owner.undo())
            #expect(owner.text == original)
            #expect(!owner.canUndo)
            #expect(await owner.redo())
            #expect(owner.text == "Say HoldType now")
            #expect(!owner.canRedo)
        }
    }

    @Test func emptySelectionTargetsTheCompleteConfirmedDraft()
        async throws {
        try await withOwner(text: "Complete draft") { owner in
            let snapshot = try #require(
                IOSVoiceDraftTextTargetSnapshot(
                    text: owner.text,
                    selectedRange: NSRange(location: 4, length: 0)
                )
            )
            let reservation = try #require(
                owner.beginTransformation(targeting: snapshot)
            )

            #expect(reservation.text == "Complete draft")
            #expect(
                reservation.sourceUTF16Range
                    == NSRange(location: 0, length: owner.text.utf16.count)
            )
            #expect(
                await owner.commitTransformation(
                    "Replacement",
                    reservation: reservation
                ) == .confirmed(changed: true)
            )
            #expect(owner.text == "Replacement")
        }
    }

    @Test func capturedWorkingSelectionCommitsBeforeItIsReserved()
        async throws {
        try await withOwner(text: "Original") { owner in
            #expect(owner.beginEditing())
            owner.updateEditingText("Working 😀 text")
            let workingText = owner.visibleText
            let selectedRange = (workingText as NSString).range(of: "😀")
            let snapshot = try #require(
                IOSVoiceDraftTextTargetSnapshot(
                    text: workingText,
                    selectedRange: selectedRange
                )
            )

            let reservation = try #require(
                await owner.beginTransformation(capturing: snapshot)
            )
            #expect(!owner.isEditing)
            #expect(owner.text == workingText)
            #expect(reservation.text == "😀")
            #expect(
                await owner.commitTransformation(
                    "emoji",
                    reservation: reservation
                ) == .confirmed(changed: true)
            )
            #expect(owner.text == "Working emoji text")

            #expect(await owner.undo())
            #expect(owner.text == workingText)
            #expect(await owner.redo())
            #expect(owner.text == "Working emoji text")
        }
    }

    @Test func staleCapturedTextIsRejectedBeforeReservation()
        async throws {
        try await withOwner(text: "Confirmed") { owner in
            let snapshot = try #require(
                IOSVoiceDraftTextTargetSnapshot(
                    text: "Older",
                    selectedRange: NSRange(location: 0, length: 5)
                )
            )

            #expect(
                owner.beginTransformation(targeting: snapshot) == nil
            )
            #expect(owner.operation == .idle)
            #expect(owner.text == "Confirmed")
        }
    }

    @Test func repositoryChangeMakesSelectedRangeResultStale()
        async throws {
        try await withRepository { repository in
            let owner = IOSVoiceDraftOwner(repository: repository)
            #expect(await owner.refresh())
            #expect(
                await owner.accept(
                    try accepted(text: "Keep selected source"),
                    mode: .append
                )
            )
            let selectedRange = (owner.text as NSString).range(of: "selected")
            let snapshot = try #require(
                IOSVoiceDraftTextTargetSnapshot(
                    text: owner.text,
                    selectedRange: selectedRange
                )
            )
            let reservation = try #require(
                owner.beginTransformation(targeting: snapshot)
            )

            _ = try await repository.append(
                IOSVoiceDraftSegment(resultID: UUID(), text: "External")
            )

            #expect(
                await owner.commitTransformation(
                    "changed",
                    reservation: reservation
                ) == .stale
            )
            #expect(owner.text == "Keep selected source\n\nExternal")
            #expect(!owner.canUndo)
        }
    }

    private func withOwner(
        text: String,
        operation: (IOSVoiceDraftOwner) async throws -> Void
    ) async throws {
        try await withRepository { repository in
            let owner = IOSVoiceDraftOwner(repository: repository)
            #expect(await owner.refresh())
            #expect(
                await owner.accept(
                    try accepted(text: text),
                    mode: .append
                )
            )
            try await operation(owner)
        }
    }

    private func withRepository(
        operation: (IOSVoiceDraftRepository) async throws -> Void
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "holdtype-draft-transformation-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try await operation(
            IOSVoiceDraftRepository(applicationSupportDirectoryURL: root)
        )
    }

    private func accepted(
        text: String
    ) throws -> IOSV1AcceptedOutputDeliveryRecord {
        try IOSV1AcceptedOutputDeliveryRecord(
            resultID: UUID(),
            sourceAttemptID: UUID(),
            acceptedText: text,
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }
}
