import Foundation
import HoldTypeDomain

public enum IOSTextFixCatalogRepositoryError: Error, Equatable, Sendable {
    case readFailed
    case sourceTooLarge
    case malformedData
    case topLevelNotObject
    case missingRequiredValue(path: String)
    case invalidValueType(path: String)
    case invalidValue(path: String)
    case unsupportedSchemaVersion
    case unexpectedFields(path: String)
    case invalidCatalog
    case encodingFailed
    case encodedDataTooLarge
    case encodedStructureTooComplex
    case writeFailed
}

/// Serializes access to the containing app's canonical app-private Fixes catalog.
public actor IOSTextFixCatalogRepository {
    public static let maximumByteCount = 1_024 * 1_024

    private static let filePolicy = ProtectedAtomicMetadataFilePolicy(
        maximumByteCount: maximumByteCount,
        fileProtection: .complete,
        excludesFromBackup: false
    )

    private let fileURL: URL
    private let fileSystem: any ProtectedAtomicMetadataFileSystem

    public init(applicationSupportDirectoryURL: URL) {
        fileURL = IOSTextFixCatalogStorageLocation.fileURL(
            in: applicationSupportDirectoryURL
        )
        fileSystem = FoundationProtectedAtomicMetadataFileSystem()
    }

    init(
        fileURL: URL,
        fileSystem: any ProtectedAtomicMetadataFileSystem
    ) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
    }

    public func load() throws -> TextFixCatalog {
        let data: Data?
        do {
            data = try fileSystem.readFileIfPresent(
                at: fileURL,
                policy: Self.filePolicy
            )
        } catch ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded {
            throw IOSTextFixCatalogRepositoryError.sourceTooLarge
        } catch {
            throw IOSTextFixCatalogRepositoryError.readFailed
        }

        guard let data else {
            return .defaults
        }
        return try IOSTextFixCatalogWireCodec.decode(
            data,
            maximumInputByteCount: Self.filePolicy.maximumByteCount
        )
    }

    @discardableResult
    public func save(_ catalog: TextFixCatalog) throws -> TextFixCatalog {
        let encoding = try IOSTextFixCatalogWireCodec.encode(catalog)
        guard encoding.data.count <= Self.filePolicy.maximumByteCount else {
            throw IOSTextFixCatalogRepositoryError.encodedDataTooLarge
        }
        do {
            try BoundedJSONMemberValidator.validate(
                encoding.data,
                limits: .metadataFile(
                    maximumInputByteCount: Self.filePolicy.maximumByteCount
                )
            )
        } catch BoundedJSONMemberValidationError.inputTooLarge {
            throw IOSTextFixCatalogRepositoryError.encodedDataTooLarge
        } catch BoundedJSONMemberValidationError.resourceLimitExceeded {
            throw IOSTextFixCatalogRepositoryError.encodedStructureTooComplex
        } catch {
            throw IOSTextFixCatalogRepositoryError.encodingFailed
        }

        do {
            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: encoding.data,
                policy: Self.filePolicy
            )
        } catch ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded {
            throw IOSTextFixCatalogRepositoryError.encodedDataTooLarge
        } catch {
            throw IOSTextFixCatalogRepositoryError.writeFailed
        }
        return encoding.catalog
    }
}

extension IOSTextFixCatalogRepository: CustomStringConvertible,
    CustomDebugStringConvertible {
    public nonisolated var description: String {
        "IOSTextFixCatalogRepository(redacted)"
    }

    public nonisolated var debugDescription: String { description }
}
