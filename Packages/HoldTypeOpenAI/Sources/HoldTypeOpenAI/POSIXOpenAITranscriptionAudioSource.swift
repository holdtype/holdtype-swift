import Darwin
import Foundation

nonisolated func makePOSIXOpenAITranscriptionAudioSource(
    at fileURL: URL,
    calls: any OpenAITranscriptionPOSIXCalling
) throws -> any OpenAITranscriptionAudioSource {
    try fileURL.withUnsafeFileSystemRepresentation { path in
        guard let path else { throw OpenAITranscriptionMultipartFileSystemError.invalidSource }
        var pathStatus = stat()
        guard Darwin.lstat(path, &pathStatus) == 0 else {
            if errno == ENOENT { throw OpenAITranscriptionMultipartFileSystemError.missingSource }
            throw OpenAITranscriptionMultipartFileSystemError.invalidSource
        }
        guard isRegular(pathStatus), !isSymbolicLink(pathStatus) else {
            throw OpenAITranscriptionMultipartFileSystemError.invalidSource
        }
        let fd = Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else {
            if errno == ENOENT { throw OpenAITranscriptionMultipartFileSystemError.missingSource }
            throw OpenAITranscriptionMultipartFileSystemError.invalidSource
        }
        var descriptorStatus = stat()
        guard Darwin.fstat(fd, &descriptorStatus) == 0,
              isRegular(descriptorStatus),
              fileIdentity(pathStatus) == fileIdentity(descriptorStatus) else {
            Darwin.close(fd)
            throw OpenAITranscriptionMultipartFileSystemError.invalidSource
        }
        return POSIXOpenAITranscriptionAudioSource(
            fileURL: fileURL,
            fileDescriptor: fd,
            identity: fileIdentity(descriptorStatus),
            calls: calls
        )
    }
}

nonisolated private final class POSIXOpenAITranscriptionAudioSource:
    OpenAITranscriptionAudioSource,
    @unchecked Sendable {
    private struct State {
        var fileDescriptor: Int32?
        var activeOperationCount = 0
        var closeRequested = false
    }

    let identity: OpenAITranscriptionFileIdentity
    private let fileURL: URL
    private let calls: any OpenAITranscriptionPOSIXCalling
    private let lock = NSLock()
    private var state: State

    init(
        fileURL: URL,
        fileDescriptor: Int32,
        identity: OpenAITranscriptionFileIdentity,
        calls: any OpenAITranscriptionPOSIXCalling
    ) {
        self.fileURL = fileURL
        self.identity = identity
        self.calls = calls
        state = State(fileDescriptor: fileDescriptor)
    }

    func read(upToCount count: Int) throws -> Data {
        guard count > 0 else { return Data() }
        let fd = try beginDescriptorUse(
            failure: OpenAITranscriptionMultipartFileSystemError.sourceReadFailed
        )
        defer { finishDescriptorUse() }

        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes { bytes -> Int in
            guard let base = bytes.baseAddress else { return 0 }
            while true {
                let result = calls.read(fd, base, count)
                if result < 0, errno == EINTR { continue }
                return result
            }
        }
        guard result >= 0, result <= count else {
            throw OpenAITranscriptionMultipartFileSystemError.sourceReadFailed
        }
        data.count = result
        return data
    }

    func validateUnchanged() throws {
        let fd = try beginDescriptorUse(
            failure: OpenAITranscriptionMultipartFileSystemError.sourceChanged
        )
        defer { finishDescriptorUse() }

        var descriptorStatus = stat()
        guard Darwin.fstat(fd, &descriptorStatus) == 0,
              fileIdentity(descriptorStatus) == identity else {
            throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
        }
        try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw OpenAITranscriptionMultipartFileSystemError.sourceChanged }
            var pathStatus = stat()
            guard Darwin.lstat(path, &pathStatus) == 0,
                  fileIdentity(pathStatus) == identity else {
                throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
            }
        }
    }

    func close() {
        let descriptor = lock.withLock { () -> Int32? in
            state.closeRequested = true
            guard state.activeOperationCount == 0 else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    private func beginDescriptorUse(failure: Error) throws -> Int32 {
        try lock.withLock {
            guard !state.closeRequested, let descriptor = state.fileDescriptor else {
                throw failure
            }
            state.activeOperationCount += 1
            return descriptor
        }
    }

    private func finishDescriptorUse() {
        let descriptor = lock.withLock { () -> Int32? in
            state.activeOperationCount -= 1
            guard state.activeOperationCount == 0, state.closeRequested else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    deinit { close() }
}

nonisolated private func isSymbolicLink(_ status: stat) -> Bool {
    status.st_mode & S_IFMT == S_IFLNK
}
