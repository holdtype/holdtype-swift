import Foundation
import HoldTypeDomain
@testable import HoldTypePersistence

let expectedTextFixCatalogFilePolicy = ProtectedAtomicMetadataFilePolicy(
    maximumByteCount: 1_024 * 1_024,
    fileProtection: .complete,
    excludesFromBackup: false
)

func makeTextFixCatalogRepository(
    fileSystem: TextFixCatalogFileSystemFake
) -> IOSTextFixCatalogRepository {
    IOSTextFixCatalogRepository(
        fileURL: URL(
            fileURLWithPath: "/app-private/HoldType/ios-text-fixes.json"
        ),
        fileSystem: fileSystem
    )
}

func makeTextFixCatalog(
    customActions: [TextFixAction]
) throws -> TextFixCatalog {
    try TextFixCatalog(
        actions: Array(TextFixCatalog.defaults.actions.prefix(2)) + customActions
    )
}

func makeCustomTextFixAction(
    id: String = "custom.example",
    title: String = "Example",
    icon: TextFixIcon = .custom,
    prompt: String = "Rewrite this text.",
    isEnabled: Bool = true
) throws -> TextFixAction {
    try TextFixAction(
        id: id,
        kind: .customPrompt,
        title: title,
        icon: icon,
        prompt: prompt,
        isEnabled: isEnabled
    )
}

func textFixRootData(actions: Any?) throws -> Data {
    var root: [String: Any] = ["schemaVersion": 1]
    if let actions {
        root["actions"] = actions
    }
    return try JSONSerialization.data(
        withJSONObject: root,
        options: [.sortedKeys]
    )
}

func textFixBuiltInActionObjects() -> [[String: Any]] {
    TextFixCatalog.defaults.actions.prefix(2).map(textFixActionObject)
}

func textFixActionObject(_ action: TextFixAction) -> [String: Any] {
    var object: [String: Any] = [
        "id": action.id,
        "kind": action.kind.rawValue,
        "title": action.title,
        "icon": action.icon.rawValue,
        "isEnabled": action.isEnabled,
    ]
    if let prompt = action.prompt {
        object["prompt"] = prompt
    }
    return object
}

func replacingTextFixField(
    _ object: [String: Any],
    key: String,
    value: Any
) -> [String: Any] {
    var result = object
    result[key] = value
    return result
}

func removingTextFixField(
    _ object: [String: Any],
    key: String
) -> [String: Any] {
    var result = object
    result.removeValue(forKey: key)
    return result
}

enum TextFixCatalogFileSystemFakeError: Error {
    case readFailed
    case replacementFailed
}

final class TextFixCatalogFileSystemFake:
    ProtectedAtomicMetadataFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedData: Data?
    private var storedReadPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementCallCount = 0
    private let readError: Error?
    private let replacementError: Error?

    var data: Data? { lock.withLock { storedData } }
    var readPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReadPolicies }
    }
    var replacementPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReplacementPolicies }
    }
    var replacementCallCount: Int {
        lock.withLock { storedReplacementCallCount }
    }

    init(
        data: Data? = nil,
        readError: Error? = nil,
        replacementError: Error? = nil
    ) {
        storedData = data
        self.readError = readError
        self.replacementError = replacementError
    }

    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        try lock.withLock {
            storedReadPolicies.append(policy)
            if let readError {
                throw readError
            }
            return storedData
        }
    }

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        try lock.withLock {
            storedReplacementPolicies.append(policy)
            storedReplacementCallCount += 1
            if let replacementError {
                throw replacementError
            }
            storedData = data
        }
    }

    func removeFileIfPresent(at fileURL: URL) throws {
        lock.withLock {
            storedData = nil
        }
    }
}
