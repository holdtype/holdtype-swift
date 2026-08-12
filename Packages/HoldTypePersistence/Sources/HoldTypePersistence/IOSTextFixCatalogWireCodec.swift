import CoreFoundation
import Foundation
import HoldTypeDomain

struct IOSTextFixCatalogCanonicalEncoding {
    let catalog: TextFixCatalog
    let data: Data
}

enum IOSTextFixCatalogWireCodec {
    private static let currentSchemaVersion = 2
    private static let rootFields: Set<String> = ["schemaVersion", "actions"]
    private static let v1ActionFields: Set<String> = [
        "id", "kind", "title", "icon", "prompt", "isEnabled",
    ]
    private static let v2ActionFields = v1ActionFields.union([
        "processingProfile", "customModel", "reasoningEffort",
    ])

    static func encode(
        _ catalog: TextFixCatalog
    ) throws -> IOSTextFixCatalogCanonicalEncoding {
        let canonicalCatalog: TextFixCatalog
        do {
            canonicalCatalog = try TextFixCatalog(actions: catalog.actions)
        } catch {
            throw IOSTextFixCatalogRepositoryError.invalidCatalog
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return IOSTextFixCatalogCanonicalEncoding(
                catalog: canonicalCatalog,
                data: try encoder.encode(
                    IOSTextFixCatalogWireV2(catalog: canonicalCatalog)
                )
            )
        } catch {
            throw IOSTextFixCatalogRepositoryError.encodingFailed
        }
    }

    static func decode(
        _ data: Data,
        maximumInputByteCount: Int
    ) throws -> TextFixCatalog {
        do {
            try BoundedJSONMemberValidator.validate(
                data,
                limits: .metadataFile(
                    maximumInputByteCount: maximumInputByteCount
                )
            )
        } catch let error as BoundedJSONMemberValidationError {
            switch error {
            case .inputTooLarge:
                throw IOSTextFixCatalogRepositoryError.sourceTooLarge
            case .malformedJSON,
                 .duplicateObjectMember,
                 .resourceLimitExceeded:
                throw IOSTextFixCatalogRepositoryError.malformedData
            }
        } catch {
            throw IOSTextFixCatalogRepositoryError.malformedData
        }

        let rootValue: Any
        do {
            rootValue = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw IOSTextFixCatalogRepositoryError.malformedData
        }
        guard let rootObject = rootValue as? [String: Any] else {
            throw IOSTextFixCatalogRepositoryError.topLevelNotObject
        }

        let root = IOSTextFixCatalogWireObjectReader(
            object: rootObject,
            path: "$"
        )
        let schemaVersion = try root.requiredInteger("schemaVersion")
        guard (1...currentSchemaVersion).contains(schemaVersion) else {
            throw IOSTextFixCatalogRepositoryError.unsupportedSchemaVersion
        }
        try root.rejectUnexpectedFields(allowing: rootFields)
        let actionObjects = try root.requiredObjectArray("actions")
        let actions = try actionObjects.enumerated().map { index, object in
            try decodeAction(
                object,
                index: index,
                schemaVersion: schemaVersion
            )
        }

        do {
            return try TextFixCatalog(actions: actions)
        } catch {
            throw IOSTextFixCatalogRepositoryError.invalidCatalog
        }
    }

    private static func decodeAction(
        _ object: [String: Any],
        index: Int,
        schemaVersion: Int
    ) throws -> TextFixAction {
        let path = "actions[\(index)]"
        let reader = IOSTextFixCatalogWireObjectReader(
            object: object,
            path: path
        )
        try reader.rejectUnexpectedFields(
            allowing: schemaVersion == 1 ? v1ActionFields : v2ActionFields
        )

        let kindPath = "\(path).kind"
        let rawKind = try reader.requiredString("kind")
        guard let kind = TextFixActionKind(rawValue: rawKind) else {
            throw IOSTextFixCatalogRepositoryError.invalidValue(path: kindPath)
        }

        let iconPath = "\(path).icon"
        let rawIcon = try reader.requiredString("icon")
        guard let icon = TextFixIcon(rawValue: rawIcon) else {
            throw IOSTextFixCatalogRepositoryError.invalidValue(path: iconPath)
        }

        let id = try reader.requiredString("id")
        let title = try reader.requiredString("title")
        let prompt = try reader.optionalString("prompt")
        let isEnabled = try reader.requiredBoolean("isEnabled")
        let processingProfile = try decodeProcessingProfile(
            reader,
            schemaVersion: schemaVersion
        )

        do {
            return try TextFixAction(
                id: id,
                kind: kind,
                title: canonicalTitle(
                    id: id,
                    kind: kind,
                    title: title,
                    icon: icon,
                    prompt: prompt,
                    isEnabled: isEnabled
                ),
                icon: icon,
                prompt: prompt,
                processingProfile: processingProfile,
                isEnabled: isEnabled
            )
        } catch let error as IOSTextFixCatalogRepositoryError {
            throw error
        } catch {
            throw IOSTextFixCatalogRepositoryError.invalidValue(path: path)
        }
    }

    private static func decodeProcessingProfile(
        _ reader: IOSTextFixCatalogWireObjectReader,
        schemaVersion: Int
    ) throws -> TextFixProcessingProfile {
        guard schemaVersion >= 2 else {
            return .inherit
        }

        let rawPreset = try reader.requiredString("processingProfile")
        guard let preset = TextFixProcessingProfile.Preset(rawValue: rawPreset) else {
            throw IOSTextFixCatalogRepositoryError.invalidValue(
                path: "\(reader.path).processingProfile"
            )
        }

        switch preset {
        case .inherit:
            try rejectCustomProcessingFields(reader)
            return .inherit
        case .gpt56Terra:
            try rejectCustomProcessingFields(reader)
            return .gpt56Terra
        case .gpt56SolMax:
            try rejectCustomProcessingFields(reader)
            return .gpt56SolMax
        case .custom:
            let model = try reader.requiredString("customModel")
            let rawEffort = try reader.requiredString("reasoningEffort")
            guard let effort = TextFixReasoningEffort(rawValue: rawEffort) else {
                throw IOSTextFixCatalogRepositoryError.invalidValue(
                    path: "\(reader.path).reasoningEffort"
                )
            }
            do {
                return try .custom(model: model, reasoningEffort: effort)
            } catch {
                throw IOSTextFixCatalogRepositoryError.invalidValue(
                    path: reader.path
                )
            }
        }
    }

    private static func rejectCustomProcessingFields(
        _ reader: IOSTextFixCatalogWireObjectReader
    ) throws {
        guard !reader.object.keys.contains("customModel"),
              !reader.object.keys.contains("reasoningEffort")
        else {
            throw IOSTextFixCatalogRepositoryError.invalidValue(path: reader.path)
        }
    }

    private static func canonicalTitle(
        id: String,
        kind: TextFixActionKind,
        title: String,
        icon: TextFixIcon,
        prompt: String?,
        isEnabled: Bool
    ) -> String {
        guard id == TextFixAction.fixIdentifier,
              kind == .fix,
              title == "Fix",
              icon == .fix,
              prompt == nil,
              isEnabled
        else {
            return title
        }
        return "Correct Text"
    }
}
