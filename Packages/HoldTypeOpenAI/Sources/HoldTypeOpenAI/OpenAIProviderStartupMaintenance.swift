import Foundation

nonisolated enum OpenAIMultipartScratchNamespace {
    static let directoryName = "holdtype-openai-multipart"
    static let v1Prefix = "htmp-v1-"
    static let fileExtension = ".multipart"
    static let markerName = "com.holdtype.openai.multipart-scratch"
    static let markerValue: [UInt8] = [0x76, 0x31]

    static var defaultDirectoryURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    static func v1FileName(for identifier: UUID) -> String {
        v1Prefix + identifier.uuidString.lowercased() + fileExtension
    }

    static func legacyFileName(for identifier: UUID) -> String {
        identifier.uuidString.uppercased() + fileExtension
    }

    static func identifier(inV1FileName fileName: String) -> UUID? {
        guard fileName.hasPrefix(v1Prefix),
              fileName.hasSuffix(fileExtension) else {
            return nil
        }
        let start = fileName.index(fileName.startIndex, offsetBy: v1Prefix.count)
        let end = fileName.index(fileName.endIndex, offsetBy: -fileExtension.count)
        let value = String(fileName[start..<end])
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.lowercased(),
              fileName == v1FileName(for: identifier) else {
            return nil
        }
        return identifier
    }

    static func identifier(inLegacyFileName fileName: String) -> UUID? {
        guard fileName.hasSuffix(fileExtension) else {
            return nil
        }
        let end = fileName.index(fileName.endIndex, offsetBy: -fileExtension.count)
        let value = String(fileName[..<end])
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.uppercased(),
              fileName == legacyFileName(for: identifier) else {
            return nil
        }
        return identifier
    }

    static func installMarker(on fileDescriptor: Int32) -> Bool {
        let adapter = DarwinOpenAIMultipartScratchPOSIXAdapter()
        return markerIsInstalled(
            on: fileDescriptor,
            adapter: adapter,
            shouldStartOperation: { true }
        )
    }

    static func hasExactMarker(on fileDescriptor: Int32) -> Bool {
        let adapter = DarwinOpenAIMultipartScratchPOSIXAdapter()
        return markerIsExact(
            on: fileDescriptor,
            adapter: adapter,
            shouldStartOperation: { true }
        )
    }
}

public nonisolated enum OpenAIProviderStartupMaintenance {
    private static let scheduler = OpenAIProviderStartupMaintenanceScheduler()

    public static func schedule() {
        scheduler.schedule {
            _ = OpenAIMultipartScratchScavenger().run()
        }
    }
}

nonisolated final class OpenAIProviderStartupMaintenanceScheduler:
    @unchecked Sendable {
    typealias Dispatch = @Sendable (@escaping @Sendable () -> Void) -> Void

    private let lock = NSLock()
    private let dispatch: Dispatch
    private var didSchedule = false

    init(
        dispatch: @escaping Dispatch = { operation in
            DispatchQueue.global(qos: .utility).async(execute: operation)
        }
    ) {
        self.dispatch = dispatch
    }

    @discardableResult
    func schedule(_ operation: @escaping @Sendable () -> Void) -> Bool {
        let shouldSchedule = lock.withLock { () -> Bool in
            guard !didSchedule else {
                return false
            }
            didSchedule = true
            return true
        }
        guard shouldSchedule else {
            return false
        }
        dispatch(operation)
        return true
    }
}
