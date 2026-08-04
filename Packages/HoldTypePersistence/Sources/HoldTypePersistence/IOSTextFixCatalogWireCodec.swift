import CoreFoundation
import Foundation
import HoldTypeDomain

struct IOSTextFixCatalogCanonicalEncoding {
    let catalog: TextFixCatalog
    let data: Data
}

enum IOSTextFixCatalogWireCodec {
    private static let supportedSchemaVersion = 1
    private static let rootFields: Set<String> = ["schemaVersion", "actions"]
    private static let actionFields: Set<String> = [
        "id", "kind", "title", "icon", "prompt", "isEnabled",
    ]

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
                    IOSTextFixCatalogWireV1(catalog: canonicalCatalog)
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
        guard schemaVersion == supportedSchemaVersion else {
            throw IOSTextFixCatalogRepositoryError.unsupportedSchemaVersion
        }
        try root.rejectUnexpectedFields(allowing: rootFields)
        let actionObjects = try root.requiredObjectArray("actions")
        let actions = try actionObjects.enumerated().map { index, object in
            try decodeAction(object, index: index)
        }

        do {
            return try TextFixCatalog(actions: actions)
        } catch {
            throw IOSTextFixCatalogRepositoryError.invalidCatalog
        }
    }

    private static func decodeAction(
        _ object: [String: Any],
        index: Int
    ) throws -> TextFixAction {
        let path = "actions[\(index)]"
        let reader = IOSTextFixCatalogWireObjectReader(
            object: object,
            path: path
        )
        try reader.rejectUnexpectedFields(allowing: actionFields)

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
                isEnabled: isEnabled
            )
        } catch let error as IOSTextFixCatalogRepositoryError {
            throw error
        } catch {
            throw IOSTextFixCatalogRepositoryError.invalidValue(path: path)
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
