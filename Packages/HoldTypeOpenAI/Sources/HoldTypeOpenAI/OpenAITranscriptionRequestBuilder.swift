import Darwin
import Foundation
import HoldTypeDomain

nonisolated struct OpenAITranscriptionRequestBuilder: Sendable {
    static let defaultEndpointURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    static let maximumAudioByteCountExclusive: Int64 = 25_000_000
    static let maximumMetadataByteCount: Int64 = 1_048_576
    static let maximumAudioReadByteCount = 64 * 1024

    private let endpointURL: URL
    private let boundaryProvider: @Sendable () -> String
    private let scratchDirectoryURL: URL
    private let fileSystem: any OpenAITranscriptionMultipartFileSystem

    init(
        endpointURL: URL = Self.defaultEndpointURL,
        boundary: String? = nil,
        scratchDirectoryURL: URL? = nil,
        fileSystem: any OpenAITranscriptionMultipartFileSystem =
            POSIXOpenAITranscriptionMultipartFileSystem()
    ) {
        self.endpointURL = endpointURL
        boundaryProvider = if let boundary { { boundary } } else { { "Boundary-\(UUID().uuidString)" } }
        self.scratchDirectoryURL = scratchDirectoryURL
            ?? OpenAIMultipartScratchNamespace.defaultDirectoryURL
        self.fileSystem = fileSystem
    }

    func makeCleanupRegistration() -> OpenAITranscriptionMultipartCleanupRegistration {
        OpenAITranscriptionMultipartCleanupRegistration()
    }

    func makePreparation(
        _ transcriptionRequest: AudioTranscriptionRequest,
        cleanupRegistration: OpenAITranscriptionMultipartCleanupRegistration
    ) async throws -> OpenAITranscriptionMultipartPreparation {
        try Task.checkCancellation()
        guard transcriptionRequest.audioFileURL.isFileURL else {
            throw OpenAITranscriptionRequestBuilderError.missingAudioFile(
                transcriptionRequest.audioFileURL
            )
        }

        let fileExtension = transcriptionRequest.audioFileURL.pathExtension.lowercased()
        guard let supportedFile = Self.supportedAudioFiles[fileExtension] else {
            throw OpenAITranscriptionRequestBuilderError.unsupportedAudioFileType(fileExtension)
        }
        let boundary = boundaryProvider()
        guard Self.isSafeBoundary(boundary) else {
            throw OpenAITranscriptionRequestBuilderError.invalidMultipartBoundary
        }

        let source: any OpenAITranscriptionAudioSource
        do {
            source = try fileSystem.openAudioSource(at: transcriptionRequest.audioFileURL)
        } catch OpenAITranscriptionMultipartFileSystemError.missingSource {
            throw OpenAITranscriptionRequestBuilderError.missingAudioFile(
                transcriptionRequest.audioFileURL
            )
        } catch {
            throw OpenAITranscriptionRequestBuilderError.unreadableAudioFile(
                transcriptionRequest.audioFileURL
            )
        }

        var scratch: (any OpenAITranscriptionScratchFile)?
        do {
            guard source.identity.byteCount > 0 else {
                throw OpenAITranscriptionRequestBuilderError.emptyAudioFile(
                    transcriptionRequest.audioFileURL
                )
            }
            guard source.identity.byteCount < Self.maximumAudioByteCountExclusive else {
                throw OpenAITranscriptionRequestBuilderError.audioFileTooLarge(
                    byteCount: source.identity.byteCount,
                    maximumExclusive: Self.maximumAudioByteCountExclusive
                )
            }

            let sizes = try validatedSizes(
                supportedFile: supportedFile,
                transcriptionRequest: transcriptionRequest,
                boundary: boundary,
                audioByteCount: source.identity.byteCount
            )
            try Task.checkCancellation()
            let multipartStrings = makeMultipartStrings(
                supportedFile: supportedFile,
                transcriptionRequest: transcriptionRequest,
                boundary: boundary
            )

            let bodyFileURL = scratchDirectoryURL.appendingPathComponent(
                OpenAIMultipartScratchNamespace.v1FileName(for: UUID()),
                isDirectory: false
            )
            scratch = try fileSystem.createScratchFile(at: bodyFileURL)
            let preparation = OpenAITranscriptionMultipartPreparation(
                endpointURL: endpointURL,
                boundary: boundary,
                sourceFileURL: transcriptionRequest.audioFileURL,
                source: source,
                scratch: try required(scratch),
                prefix: Data(multipartStrings.prefix.utf8),
                suffix: Data(multipartStrings.suffix.utf8),
                expectedBodyByteCount: sizes.bodyByteCount
            )
            cleanupRegistration.install {
                preparation.cleanup()
            }
            try Task.checkCancellation()
            return preparation
        } catch is CancellationError {
            source.close()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw CancellationError()
        } catch let error as OpenAITranscriptionRequestBuilderError {
            source.close()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw error
        } catch {
            source.close()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable
        }
    }

    func makePreparation(
        _ transcriptionRequest: OpenAIReaderTranscriptionRequest,
        cleanupRegistration: OpenAITranscriptionMultipartCleanupRegistration
    ) async throws -> OpenAIReaderTranscriptionMultipartPreparation {
        try Task.checkCancellation()
        let supportedFile = Self.supportedAudioFile(for: transcriptionRequest.format)
        let boundary = boundaryProvider()
        guard Self.isSafeBoundary(boundary) else {
            throw OpenAITranscriptionRequestBuilderError.invalidMultipartBoundary
        }

        let sizes = try validatedSizes(
            supportedFile: supportedFile,
            transcriptionRequest: transcriptionRequest,
            boundary: boundary,
            audioByteCount: transcriptionRequest.byteCount
        )
        try Task.checkCancellation()
        let multipartStrings = makeMultipartStrings(
            supportedFile: supportedFile,
            transcriptionRequest: transcriptionRequest,
            boundary: boundary
        )

        let reader: OpenAITranscriptionAudioReaderLease
        do {
            reader = try transcriptionRequest.claimReader()
        } catch {
            throw OpenAITranscriptionRequestBuilderError.audioReaderAlreadyConsumed
        }

        var scratch: (any OpenAITranscriptionScratchFile)?
        do {
            let bodyFileURL = scratchDirectoryURL.appendingPathComponent(
                OpenAIMultipartScratchNamespace.v1FileName(for: UUID()),
                isDirectory: false
            )
            scratch = try fileSystem.createScratchFile(at: bodyFileURL)
            let preparation = OpenAIReaderTranscriptionMultipartPreparation(
                endpointURL: endpointURL,
                boundary: boundary,
                reader: reader,
                scratch: try required(scratch),
                prefix: Data(multipartStrings.prefix.utf8),
                suffix: Data(multipartStrings.suffix.utf8),
                audioByteCount: transcriptionRequest.byteCount,
                expectedBodyByteCount: sizes.bodyByteCount
            )
            cleanupRegistration.install {
                preparation.cleanup()
            }
            try Task.checkCancellation()
            return preparation
        } catch is CancellationError {
            reader.retire()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw CancellationError()
        } catch let error as OpenAITranscriptionRequestBuilderError {
            reader.retire()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw error
        } catch {
            reader.retire()
            scratch?.unlinkIfOwned()
            scratch?.close()
            throw OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable
        }
    }

    private func makeMultipartStrings(
        supportedFile: SupportedAudioFile,
        transcriptionRequest: AudioTranscriptionRequest,
        boundary: String
    ) -> (prefix: String, suffix: String) {
        var prefix = ""
        prefix.appendFormField(name: "model", value: transcriptionRequest.model, boundary: boundary)
        prefix.appendFormField(name: "response_format", value: "json", boundary: boundary)
        if let languageCode = transcriptionRequest.languageCode {
            prefix.appendFormField(name: "language", value: languageCode, boundary: boundary)
        }
        if let prompt = transcriptionRequest.promptComposition.providerPrompt {
            prefix.appendFormField(name: "prompt", value: prompt, boundary: boundary)
        }
        prefix.appendFileFieldHeader(
            name: "file",
            fileName: supportedFile.controlledFileName,
            contentType: supportedFile.contentType,
            boundary: boundary
        )
        return (prefix, "\r\n--\(boundary)--\r\n")
    }

    private func makeMultipartStrings(
        supportedFile: SupportedAudioFile,
        transcriptionRequest: OpenAIReaderTranscriptionRequest,
        boundary: String
    ) -> (prefix: String, suffix: String) {
        var prefix = ""
        prefix.appendFormField(name: "model", value: transcriptionRequest.model, boundary: boundary)
        prefix.appendFormField(name: "response_format", value: "json", boundary: boundary)
        if let languageCode = transcriptionRequest.languageCode {
            prefix.appendFormField(name: "language", value: languageCode, boundary: boundary)
        }
        if let prompt = transcriptionRequest.promptComposition.providerPrompt {
            prefix.appendFormField(name: "prompt", value: prompt, boundary: boundary)
        }
        prefix.appendFileFieldHeader(
            name: "file",
            fileName: supportedFile.controlledFileName,
            contentType: supportedFile.contentType,
            boundary: boundary
        )
        return (prefix, "\r\n--\(boundary)--\r\n")
    }

    private func validatedSizes(
        supportedFile: SupportedAudioFile,
        transcriptionRequest: AudioTranscriptionRequest,
        boundary: String,
        audioByteCount: Int64
    ) throws -> (metadataByteCount: Int64, bodyByteCount: Int64) {
        var metadata: Int64 = 0
        try addFormFieldSize(name: "model", value: transcriptionRequest.model, boundary: boundary, to: &metadata)
        try addFormFieldSize(name: "response_format", value: "json", boundary: boundary, to: &metadata)
        if let language = transcriptionRequest.languageCode {
            try addFormFieldSize(name: "language", value: language, boundary: boundary, to: &metadata)
        }
        if let prompt = transcriptionRequest.promptComposition.providerPrompt {
            try addFormFieldSize(name: "prompt", value: prompt, boundary: boundary, to: &metadata)
        }
        for value in [
            "--", boundary,
            "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"",
            supportedFile.controlledFileName,
            "\"\r\nContent-Type: ", supportedFile.contentType,
            "\r\n\r\n\r\n--", boundary, "--\r\n",
        ] {
            try addUTF8Size(value, to: &metadata)
        }
        guard metadata <= Self.maximumMetadataByteCount else {
            throw OpenAITranscriptionRequestBuilderError.multipartMetadataTooLarge(
                byteCount: metadata,
                maximum: Self.maximumMetadataByteCount
            )
        }
        let body = metadata.addingReportingOverflow(audioByteCount)
        guard !body.overflow else {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyTooLarge
        }
        return (metadata, body.partialValue)
    }

    private func validatedSizes(
        supportedFile: SupportedAudioFile,
        transcriptionRequest: OpenAIReaderTranscriptionRequest,
        boundary: String,
        audioByteCount: Int64
    ) throws -> (metadataByteCount: Int64, bodyByteCount: Int64) {
        var metadata: Int64 = 0
        try addFormFieldSize(name: "model", value: transcriptionRequest.model, boundary: boundary, to: &metadata)
        try addFormFieldSize(name: "response_format", value: "json", boundary: boundary, to: &metadata)
        if let language = transcriptionRequest.languageCode {
            try addFormFieldSize(name: "language", value: language, boundary: boundary, to: &metadata)
        }
        if let prompt = transcriptionRequest.promptComposition.providerPrompt {
            try addFormFieldSize(name: "prompt", value: prompt, boundary: boundary, to: &metadata)
        }
        for value in [
            "--", boundary,
            "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"",
            supportedFile.controlledFileName,
            "\"\r\nContent-Type: ", supportedFile.contentType,
            "\r\n\r\n\r\n--", boundary, "--\r\n",
        ] {
            try addUTF8Size(value, to: &metadata)
        }
        guard metadata <= Self.maximumMetadataByteCount else {
            throw OpenAITranscriptionRequestBuilderError.multipartMetadataTooLarge(
                byteCount: metadata,
                maximum: Self.maximumMetadataByteCount
            )
        }
        let body = metadata.addingReportingOverflow(audioByteCount)
        guard !body.overflow else {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyTooLarge
        }
        return (metadata, body.partialValue)
    }

    private func addFormFieldSize(
        name: String,
        value: String,
        boundary: String,
        to count: inout Int64
    ) throws {
        for part in ["--", boundary, "\r\nContent-Disposition: form-data; name=\"", name, "\"\r\n\r\n", value, "\r\n"] {
            try addUTF8Size(part, to: &count)
        }
    }

    private func addUTF8Size(_ value: String, to count: inout Int64) throws {
        guard let valueCount = Int64(exactly: value.utf8.count) else {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyTooLarge
        }
        let addition = count.addingReportingOverflow(valueCount)
        guard !addition.overflow else {
            throw OpenAITranscriptionRequestBuilderError.multipartBodyTooLarge
        }
        count = addition.partialValue
    }

    private static func isSafeBoundary(_ boundary: String) -> Bool {
        guard !boundary.isEmpty, boundary.utf8.count <= 70 else { return false }
        return boundary.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45
        }
    }

    private func required<T>(_ value: T?) throws -> T {
        guard let value else { throw OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable }
        return value
    }

    private static let supportedAudioFiles = [
        "m4a": SupportedAudioFile(controlledFileName: "recording.m4a", contentType: "audio/mp4"),
        "wav": SupportedAudioFile(controlledFileName: "recording.wav", contentType: "audio/wav"),
    ]

    private static func supportedAudioFile(
        for format: OpenAIReaderTranscriptionRequest.AudioFormat
    ) -> SupportedAudioFile {
        switch format {
        case .m4a:
            SupportedAudioFile(
                controlledFileName: "recording.m4a",
                contentType: "audio/mp4"
            )
        case .wav:
            SupportedAudioFile(
                controlledFileName: "recording.wav",
                contentType: "audio/wav"
            )
        }
    }
}
nonisolated private struct SupportedAudioFile: Sendable { let controlledFileName: String; let contentType: String }

nonisolated private extension String {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
    }
    mutating func appendFileFieldHeader(name: String, fileName: String, contentType: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
    }
}
