import Foundation

nonisolated final class OpenAITranscriptionMultipartCleanupRegistration: @unchecked Sendable {
    private let lock = NSLock()
    private var cleanup: (@Sendable () -> Void)?
    private var cleanupRequested = false
    private var cleanupScheduled = false

    func install(_ cleanup: @escaping @Sendable () -> Void) {
        let action = lock.withLock { () -> (@Sendable () -> Void)? in
            guard !cleanupScheduled else {
                return nil
            }
            self.cleanup = cleanup
            return takeCleanupIfReady()
        }
        if let action {
            schedule(action)
        }
    }

    func requestCleanup() {
        let action = lock.withLock { () -> (@Sendable () -> Void)? in
            cleanupRequested = true
            return takeCleanupIfReady()
        }
        if let action {
            schedule(action)
        }
    }

    private func takeCleanupIfReady() -> (@Sendable () -> Void)? {
        guard cleanupRequested,
              !cleanupScheduled,
              let cleanup else {
            return nil
        }
        self.cleanup = nil
        cleanupScheduled = true
        return cleanup
    }

    private func schedule(_ cleanup: @escaping @Sendable () -> Void) {
        DispatchQueue.global(qos: .utility).async {
            cleanup()
        }
    }
}

nonisolated struct OpenAITranscriptionPreparedMultipartUpload: Sendable {
    let request: URLRequest
    let body: any OpenAIFileUploadBody
}

nonisolated struct OpenAITranscriptionMultipartPreparation: Sendable {
    let bodyFileURL: URL
    private let endpointURL: URL
    private let boundary: String
    private let sourceFileURL: URL
    private let source: any OpenAITranscriptionAudioSource
    private let scratch: any OpenAITranscriptionScratchFile
    private let prefix: Data
    private let suffix: Data
    private let expectedBodyByteCount: Int64

    init(
        endpointURL: URL,
        boundary: String,
        sourceFileURL: URL,
        source: any OpenAITranscriptionAudioSource,
        scratch: any OpenAITranscriptionScratchFile,
        prefix: Data,
        suffix: Data,
        expectedBodyByteCount: Int64
    ) {
        self.endpointURL = endpointURL
        self.boundary = boundary
        self.sourceFileURL = sourceFileURL
        self.source = source
        self.scratch = scratch
        bodyFileURL = scratch.fileURL
        self.prefix = prefix
        self.suffix = suffix
        self.expectedBodyByteCount = expectedBodyByteCount
    }

    func prepareRequest() async throws -> OpenAITranscriptionPreparedMultipartUpload {
        do {
            try Task.checkCancellation()
            try scratch.writeAll(prefix)
            try Task.checkCancellation()
            var audioCount: Int64 = 0
            while audioCount < source.identity.byteCount {
                try Task.checkCancellation()
                let remaining = source.identity.byteCount - audioCount
                let requested = min(
                    OpenAITranscriptionRequestBuilder.maximumAudioReadByteCount,
                    Int(remaining)
                )
                let chunk = try source.read(upToCount: requested)
                try Task.checkCancellation()
                guard !chunk.isEmpty else {
                    throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
                }
                let addition = audioCount.addingReportingOverflow(Int64(chunk.count))
                guard !addition.overflow, addition.partialValue <= source.identity.byteCount else {
                    throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
                }
                audioCount = addition.partialValue
                try scratch.writeAll(chunk)
                try Task.checkCancellation()
                await Task.yield()
            }
            let trailingByte = try source.read(upToCount: 1)
            try Task.checkCancellation()
            guard trailingByte.isEmpty else {
                throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
            }
            try source.validateUnchanged()
            try Task.checkCancellation()
            try scratch.writeAll(suffix)
            try Task.checkCancellation()
            try scratch.synchronizeAndValidate(expectedByteCount: expectedBodyByteCount)
            try Task.checkCancellation()
            try source.validateUnchanged()
            try Task.checkCancellation()
            let uploadBody = try scratch.pinFinalizedUploadArtifact(
                expectedByteCount: expectedBodyByteCount
            )
            try Task.checkCancellation()
            source.close()
            scratch.close()

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue(String(expectedBodyByteCount), forHTTPHeaderField: "Content-Length")
            try Task.checkCancellation()
            return OpenAITranscriptionPreparedMultipartUpload(
                request: request,
                body: uploadBody
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch OpenAITranscriptionMultipartFileSystemError.sourceChanged {
            throw OpenAITranscriptionRequestBuilderError.audioFileChanged(sourceFileURL)
        } catch OpenAITranscriptionMultipartFileSystemError.sourceReadFailed {
            throw OpenAITranscriptionRequestBuilderError.unreadableAudioFile(sourceFileURL)
        } catch let error as OpenAITranscriptionRequestBuilderError {
            throw error
        } catch {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable
        }
    }

    func cleanup() {
        source.close()
        scratch.unlinkIfOwned()
        scratch.close()
    }
}

nonisolated struct OpenAIReaderTranscriptionMultipartPreparation: Sendable {
    let bodyFileURL: URL
    private let endpointURL: URL
    private let boundary: String
    private let reader: OpenAITranscriptionAudioReaderLease
    private let scratch: any OpenAITranscriptionScratchFile
    private let prefix: Data
    private let suffix: Data
    private let audioByteCount: Int64
    private let expectedBodyByteCount: Int64

    init(
        endpointURL: URL,
        boundary: String,
        reader: OpenAITranscriptionAudioReaderLease,
        scratch: any OpenAITranscriptionScratchFile,
        prefix: Data,
        suffix: Data,
        audioByteCount: Int64,
        expectedBodyByteCount: Int64
    ) {
        self.endpointURL = endpointURL
        self.boundary = boundary
        self.reader = reader
        self.scratch = scratch
        bodyFileURL = scratch.fileURL
        self.prefix = prefix
        self.suffix = suffix
        self.audioByteCount = audioByteCount
        self.expectedBodyByteCount = expectedBodyByteCount
    }

    func prepareRequest() async throws -> OpenAITranscriptionPreparedMultipartUpload {
        defer { reader.retire() }
        do {
            try Task.checkCancellation()
            try scratch.writeAll(prefix)
            try Task.checkCancellation()
            var audioCount: Int64 = 0
            while audioCount < audioByteCount {
                try Task.checkCancellation()
                let remaining = audioByteCount - audioCount
                let requested = min(
                    OpenAITranscriptionRequestBuilder.maximumAudioReadByteCount,
                    Int(remaining)
                )
                let chunk = try await readAudio(
                    atOffset: audioCount,
                    maximumByteCount: requested
                )
                try Task.checkCancellation()
                guard !chunk.isEmpty else {
                    throw OpenAITranscriptionAudioReaderError.invalidRead
                }
                let addition = audioCount.addingReportingOverflow(Int64(chunk.count))
                guard !addition.overflow, addition.partialValue <= audioByteCount else {
                    throw OpenAITranscriptionAudioReaderError.invalidRead
                }
                audioCount = addition.partialValue
                try scratch.writeAll(chunk)
                try Task.checkCancellation()
                await Task.yield()
            }

            let trailingByte = try await readAudio(
                atOffset: audioByteCount,
                maximumByteCount: 1
            )
            try Task.checkCancellation()
            guard trailingByte.isEmpty else {
                throw OpenAITranscriptionAudioReaderError.invalidRead
            }
            try scratch.writeAll(suffix)
            try Task.checkCancellation()
            try scratch.synchronizeAndValidate(expectedByteCount: expectedBodyByteCount)
            try Task.checkCancellation()
            let uploadBody = try scratch.pinFinalizedUploadArtifact(
                expectedByteCount: expectedBodyByteCount
            )
            try Task.checkCancellation()
            scratch.close()

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue(String(expectedBodyByteCount), forHTTPHeaderField: "Content-Length")
            try Task.checkCancellation()
            return OpenAITranscriptionPreparedMultipartUpload(
                request: request,
                body: uploadBody
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch OpenAITranscriptionAudioReaderError.invalidRead {
            throw OpenAITranscriptionRequestBuilderError.audioReaderChanged
        } catch OpenAITranscriptionAudioReaderError.alreadyConsumed {
            throw OpenAITranscriptionRequestBuilderError.audioReaderAlreadyConsumed
        } catch let error as OpenAITranscriptionRequestBuilderError {
            throw error
        } catch {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable
        }
    }

    private func readAudio(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        do {
            return try await reader.read(
                atOffset: offset,
                maximumByteCount: maximumByteCount
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch OpenAITranscriptionAudioReaderError.invalidRead {
            throw OpenAITranscriptionRequestBuilderError.audioReaderChanged
        } catch OpenAITranscriptionAudioReaderError.alreadyConsumed {
            throw OpenAITranscriptionRequestBuilderError.audioReaderAlreadyConsumed
        } catch {
            throw OpenAITranscriptionRequestBuilderError.audioReaderUnreadable
        }
    }

    func cleanup() {
        reader.retire()
        scratch.unlinkIfOwned()
        scratch.close()
    }
}

nonisolated extension OpenAIReaderTranscriptionMultipartPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "OpenAIReaderTranscriptionMultipartPreparation(<redacted>)" }
    var debugDescription: String { description }
    var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .struct
        )
    }
}

nonisolated extension OpenAITranscriptionMultipartPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "OpenAITranscriptionMultipartPreparation(<redacted>)" }
    var debugDescription: String { description }
    var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .struct
        )
    }
}
