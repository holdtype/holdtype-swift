import AudioToolbox
import Darwin
import Foundation

protocol IOSV1VoiceCaptureMediaValidating: Sendable {
    func durationMilliseconds(
        fileDescriptor: Int32,
        byteCount: Int64,
        timeoutNanoseconds: UInt64
    ) throws -> Int64
}

struct IOSV1VoiceCaptureMediaValidator: IOSV1VoiceCaptureMediaValidating {
    private static let queue = DispatchQueue(
        label: "app.holdtype.ios-v1-capture-media",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func durationMilliseconds(
        fileDescriptor: Int32,
        byteCount: Int64,
        timeoutNanoseconds: UInt64
    ) throws -> Int64 {
        let boundedTimeout = min(timeoutNanoseconds, 2_000_000_000)
        let duplicate = Darwin.fcntl(fileDescriptor, F_DUPFD_CLOEXEC, 0)
        guard duplicate >= 0 else { throw mapPOSIX(errno) }
        var status = stat()
        guard Darwin.fstat(duplicate, &status) == 0,
              status.st_mode & S_IFMT == S_IFREG,
              status.st_size == off_t(byteCount), byteCount > 0 else {
            Darwin.close(duplicate)
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        }
        let context = IOSV1VoiceCaptureAudioContext(
            fileDescriptor: duplicate,
            byteCount: byteCount
        )
        let result = IOSV1VoiceCaptureValidationResult()
        Self.queue.async {
            let value: Result<Int64, IOSV1VoiceCaptureError>
            do {
                let seconds = try context.durationSeconds()
                let milliseconds = seconds * 1_000
                guard milliseconds.isFinite, milliseconds > 0,
                      milliseconds <= Double(Int64.max) else {
                    throw IOSV1VoiceCaptureError.mediaValidationFailed
                }
                value = .success(
                    Int64(milliseconds.rounded(.toNearestOrAwayFromZero))
                )
            } catch let error as IOSV1VoiceCaptureError {
                value = .failure(
                    context.protectedDataFailure
                        ? .dataProtectionUnavailable : error
                )
            } catch {
                value = .failure(.mediaValidationFailed)
            }
            result.complete(value)
        }
        guard let value = result.wait(timeoutNanoseconds: boundedTimeout) else {
            context.cancel()
            throw IOSV1VoiceCaptureError.mediaValidationTimedOut
        }
        return try value.get()
    }

    private func mapPOSIX(_ code: Int32) -> IOSV1VoiceCaptureError {
        code == EACCES || code == EPERM
            ? .dataProtectionUnavailable : .mediaValidationFailed
    }
}

private final class IOSV1VoiceCaptureValidationResult: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var value: Result<Int64, IOSV1VoiceCaptureError>?

    func complete(_ value: Result<Int64, IOSV1VoiceCaptureError>) {
        let accepted = lock.withLock {
            guard self.value == nil else { return false }
            self.value = value
            return true
        }
        if accepted { semaphore.signal() }
    }

    func wait(timeoutNanoseconds: UInt64)
        -> Result<Int64, IOSV1VoiceCaptureError>? {
        let timeout = DispatchTime.now() + .nanoseconds(Int(timeoutNanoseconds))
        guard semaphore.wait(timeout: timeout) == .success else { return nil }
        return lock.withLock { value }
    }
}

private final class IOSV1VoiceCaptureAudioContext: @unchecked Sendable {
    private let fileDescriptor: Int32
    private let byteCount: Int64
    private let lock = NSLock()
    private var cancelled = false
    private var readError: Int32?

    init(fileDescriptor: Int32, byteCount: Int64) {
        self.fileDescriptor = fileDescriptor
        self.byteCount = byteCount
    }

    var protectedDataFailure: Bool {
        lock.withLock { readError == EACCES || readError == EPERM }
    }

    var size: Int64 { byteCount }

    func cancel() { lock.withLock { cancelled = true } }

    func durationSeconds() throws -> Float64 {
        var audioFile: AudioFileID?
        guard AudioFileOpenWithCallbacks(
            Unmanaged.passUnretained(self).toOpaque(),
            iosV1VoiceCaptureRead,
            nil,
            iosV1VoiceCaptureSize,
            nil,
            kAudioFileM4AType,
            &audioFile
        ) == noErr, let audioFile else {
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        }
        defer { AudioFileClose(audioFile) }
        var type: AudioFileTypeID = 0
        var typeSize = UInt32(MemoryLayout.size(ofValue: type))
        guard AudioFileGetProperty(
            audioFile, kAudioFilePropertyFileFormat, &typeSize, &type
        ) == noErr, type == kAudioFileM4AType else {
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        }
        var extended: ExtAudioFileRef?
        guard ExtAudioFileWrapAudioFileID(audioFile, false, &extended) == noErr,
              let extended else {
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        }
        defer { ExtAudioFileDispose(extended) }
        var format = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout.size(ofValue: format))
        var frames: Int64 = 0
        var frameSize = UInt32(MemoryLayout.size(ofValue: frames))
        guard ExtAudioFileGetProperty(
            extended, kExtAudioFileProperty_FileDataFormat,
            &formatSize, &format
        ) == noErr,
        ExtAudioFileGetProperty(
            extended, kExtAudioFileProperty_FileLengthFrames,
            &frameSize, &frames
        ) == noErr,
        format.mChannelsPerFrame > 0, format.mSampleRate.isFinite,
        format.mSampleRate > 0, frames > 0 else {
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        }
        return Float64(frames) / format.mSampleRate
    }

    func read(
        position: Int64,
        count: UInt32,
        buffer: UnsafeMutableRawPointer,
        actual: UnsafeMutablePointer<UInt32>
    ) -> OSStatus {
        actual.pointee = 0
        guard !lock.withLock({ cancelled }), position >= 0,
              position <= byteCount else { return OSStatus(ECANCELED) }
        let length = min(Int64(count), byteCount - position)
        guard length > 0 else { return noErr }
        for retry in 0...8 {
            let value = Darwin.pread(
                fileDescriptor, buffer, Int(length), off_t(position)
            )
            if value >= 0 {
                actual.pointee = UInt32(value)
                return noErr
            }
            let code = errno
            if code == EINTR, retry < 8 { continue }
            lock.withLock { if readError == nil { readError = code } }
            return OSStatus(code)
        }
        return OSStatus(EINTR)
    }

    deinit { Darwin.close(fileDescriptor) }
}

private let iosV1VoiceCaptureRead: AudioFile_ReadProc = {
    data, position, count, buffer, actual in
    Unmanaged<IOSV1VoiceCaptureAudioContext>.fromOpaque(data)
        .takeUnretainedValue().read(
            position: position, count: count, buffer: buffer, actual: actual
        )
}

private let iosV1VoiceCaptureSize: AudioFile_GetSizeProc = { data in
    Unmanaged<IOSV1VoiceCaptureAudioContext>.fromOpaque(data)
        .takeUnretainedValue().size
}
