import CoreFoundation
import Foundation

struct IOSTextFixCatalogWireObjectReader {
    let object: [String: Any]
    let path: String

    func rejectUnexpectedFields(allowing allowedFields: Set<String>) throws {
        guard Set(object.keys).isSubset(of: allowedFields) else {
            throw IOSTextFixCatalogRepositoryError.unexpectedFields(path: path)
        }
    }

    func requiredObjectArray(_ key: String) throws -> [[String: Any]] {
        try requireField(key)
        guard let values = object[key] as? [Any],
              values.allSatisfy({ $0 is [String: Any] }) else {
            throw IOSTextFixCatalogRepositoryError.invalidValueType(
                path: valuePath(key)
            )
        }
        return values.compactMap { $0 as? [String: Any] }
    }

    func requiredString(_ key: String) throws -> String {
        try requireField(key)
        guard let value = object[key] as? String else {
            throw IOSTextFixCatalogRepositoryError.invalidValueType(
                path: valuePath(key)
            )
        }
        return value
    }

    func optionalString(_ key: String) throws -> String? {
        guard object.keys.contains(key) else {
            return nil
        }
        guard let value = object[key] as? String else {
            throw IOSTextFixCatalogRepositoryError.invalidValueType(
                path: valuePath(key)
            )
        }
        return value
    }

    func requiredBoolean(_ key: String) throws -> Bool {
        try requireField(key)
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw IOSTextFixCatalogRepositoryError.invalidValueType(
                path: valuePath(key)
            )
        }
        return number.boolValue
    }

    func requiredInteger(_ key: String) throws -> Int {
        try requireField(key)
        guard let number = object[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !Self.isFloatingPointNumber(number),
              let integer = Int(number.stringValue) else {
            throw IOSTextFixCatalogRepositoryError.invalidValueType(
                path: valuePath(key)
            )
        }
        return integer
    }

    private func requireField(_ key: String) throws {
        guard object.keys.contains(key) else {
            throw IOSTextFixCatalogRepositoryError.missingRequiredValue(
                path: valuePath(key)
            )
        }
    }

    private func valuePath(_ key: String) -> String {
        path == "$" ? key : "\(path).\(key)"
    }

    private static func isFloatingPointNumber(_ number: NSNumber) -> Bool {
        let typeEncoding = String(cString: number.objCType)
        return typeEncoding == "f" || typeEncoding == "d"
    }
}
