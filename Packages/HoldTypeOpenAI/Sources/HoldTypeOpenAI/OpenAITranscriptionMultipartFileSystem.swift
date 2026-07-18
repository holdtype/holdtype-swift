import Foundation

nonisolated struct OpenAITranscriptionFileIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let byteCount: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64
}

nonisolated enum OpenAITranscriptionMultipartFileSystemError: Error, Equatable, Sendable {
    case missingSource
    case invalidSource
    case sourceReadFailed
    case sourceChanged
    case scratchUnavailable
    case scratchWriteFailed
}

nonisolated protocol OpenAITranscriptionAudioSource: Sendable {
    var identity: OpenAITranscriptionFileIdentity { get }
    func read(upToCount count: Int) throws -> Data
    func validateUnchanged() throws
    func close()
}

nonisolated protocol OpenAITranscriptionScratchFile: Sendable {
    var fileURL: URL { get }
    func writeAll(_ data: Data) throws
    func synchronizeAndValidate(expectedByteCount: Int64) throws
    func pinFinalizedUploadArtifact(
        expectedByteCount: Int64
    ) throws -> any OpenAIFileUploadBody
    func close()
    func unlinkIfOwned()
}

nonisolated protocol OpenAITranscriptionMultipartFileSystem: Sendable {
    func openAudioSource(at fileURL: URL) throws -> any OpenAITranscriptionAudioSource
    func createScratchFile(at fileURL: URL) throws -> any OpenAITranscriptionScratchFile
}

nonisolated protocol OpenAITranscriptionPOSIXCalling: Sendable {
    func read(_ fileDescriptor: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int
    func write(_ fileDescriptor: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int
    func synchronize(_ fileDescriptor: Int32) -> Int32
    func pread(
        _ fileDescriptor: Int32,
        _ buffer: UnsafeMutableRawPointer,
        _ count: Int,
        _ offset: Int64
    ) -> Int
    func installMultipartScratchMarker(on fileDescriptor: Int32) -> Bool
    func hasExactMultipartScratchMarker(on fileDescriptor: Int32) -> Bool
    func applyPrivateMultipartScratchConfiguration(on fileDescriptor: Int32) -> Bool
    func hasExactPrivateMultipartScratchConfiguration(on fileDescriptor: Int32) -> Bool
    func publishMultipartScratch(
        in directoryFileDescriptor: Int32,
        from stagingName: String,
        to finalName: String
    ) -> Bool
    func lockMultipartScratch(on fileDescriptor: Int32) -> Bool
}
