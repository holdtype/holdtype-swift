import Foundation
import HoldTypePersistence

enum FixesEditorActivity: Equatable {
    case idle
    case loading
    case saving
    case deleting
    case reordering
    case restoringDefaults

    var isBusy: Bool {
        self != .idle
    }
}

struct FixesEditorIssue: Equatable {
    enum Kind: Equatable {
        case load
        case save
        case validation
    }

    let kind: Kind
    let title: String
    let message: String

    var allowsRetry: Bool {
        kind == .load
    }

    static func loading(_ error: Error) -> FixesEditorIssue {
        guard let repositoryError = error as? TextFixCatalogRepositoryError else {
            return FixesEditorIssue(
                kind: .load,
                title: "Fixes Couldn’t Load",
                message:
                    "HoldType couldn’t read your Fixes. Nothing was changed. Try loading them again."
            )
        }

        switch repositoryError {
        case .unsupportedSchemaVersion:
            return FixesEditorIssue(
                kind: .load,
                title: "Newer Fixes Catalog",
                message:
                    "This catalog needs a newer HoldType version. HoldType preserved it and will not overwrite it."
            )
        case .sourceTooLarge:
            return FixesEditorIssue(
                kind: .load,
                title: "Fixes Catalog Is Too Large",
                message:
                    "HoldType preserved the catalog and will not overwrite it. Reduce it with a compatible HoldType version."
            )
        case .malformedData,
             .topLevelNotObject,
             .missingRequiredValue,
             .invalidValueType,
             .invalidValue,
             .unexpectedFields,
             .invalidCatalog:
            return FixesEditorIssue(
                kind: .load,
                title: "Fixes Catalog Is Damaged",
                message:
                    "HoldType preserved the damaged catalog and will not replace it with defaults."
            )
        case .readFailed:
            return FixesEditorIssue(
                kind: .load,
                title: "Fixes Couldn’t Load",
                message:
                    "HoldType couldn’t read your Fixes. Nothing was changed. Try loading them again."
            )
        case .encodingFailed,
             .encodedDataTooLarge,
             .encodedStructureTooComplex,
             .writeFailed:
            return loadingFallback
        }
    }

    static func saving(_ error: Error) -> FixesEditorIssue {
        _ = error
        return FixesEditorIssue(
            kind: .save,
            title: "Fixes Weren’t Saved",
            message:
                "HoldType kept the last saved catalog. Check access to Application Support and try again."
        )
    }

    static func validation(_ message: String) -> FixesEditorIssue {
        FixesEditorIssue(
            kind: .validation,
            title: "Fix Needs Attention",
            message: message
        )
    }

    private static let loadingFallback = FixesEditorIssue(
        kind: .load,
        title: "Fixes Couldn’t Load",
        message:
            "HoldType couldn’t read your Fixes. Nothing was changed. Try loading them again."
    )
}
