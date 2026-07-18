import Darwin
import Foundation

nonisolated extension OpenAITranscriptionPOSIXCalling {
    func pread(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int, _ offset: Int64) -> Int {
        Darwin.pread(fd, buffer, count, off_t(offset))
    }

    func installMultipartScratchMarker(on fileDescriptor: Int32) -> Bool {
        OpenAIMultipartScratchNamespace.installMarker(on: fileDescriptor)
    }

    func hasExactMultipartScratchMarker(on fileDescriptor: Int32) -> Bool {
        OpenAIMultipartScratchNamespace.hasExactMarker(on: fileDescriptor)
    }

    func applyPrivateMultipartScratchConfiguration(on fileDescriptor: Int32) -> Bool {
        OpenAIPrivateMultipartScratchConfiguration.apply(to: fileDescriptor)
    }

    func hasExactPrivateMultipartScratchConfiguration(on fileDescriptor: Int32) -> Bool {
        OpenAIPrivateMultipartScratchConfiguration.isExact(on: fileDescriptor)
    }

    func publishMultipartScratch(
        in directoryFileDescriptor: Int32,
        from stagingName: String,
        to finalName: String
    ) -> Bool {
        stagingName.withCString { stagingPath in
            finalName.withCString { finalPath in
                var result: Int32
                repeat {
                    result = Darwin.renameatx_np(
                        directoryFileDescriptor,
                        stagingPath,
                        directoryFileDescriptor,
                        finalPath,
                        UInt32(RENAME_EXCL)
                    )
                } while result != 0 && errno == EINTR
                return result == 0
            }
        }
    }

    func lockMultipartScratch(on fileDescriptor: Int32) -> Bool {
        flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0
    }
}

nonisolated private enum OpenAIPrivateMultipartScratchConfiguration {
    // F_SETPROTECTIONCLASS uses protection class 1 for FileProtectionType.complete.
    private static let completeProtectionClass: Int32 = 1
    private static let backupExclusionAttributeName =
        "com.apple.metadata:com_apple_backup_excludeItem"
    private static let backupExclusionAttributeValue = Data([
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30,
        0x5F, 0x10, 0x11, 0x63, 0x6F, 0x6D, 0x2E, 0x61,
        0x70, 0x70, 0x6C, 0x65, 0x2E, 0x62, 0x61, 0x63,
        0x6B, 0x75, 0x70, 0x64, 0x08, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x1C,
    ])

    static func apply(to fileDescriptor: Int32) -> Bool {
        var protectionResult: Int32
        repeat {
            protectionResult = Darwin.fcntl(
                fileDescriptor,
                F_SETPROTECTIONCLASS,
                completeProtectionClass
            )
        } while protectionResult != 0 && errno == EINTR
        guard protectionResult == 0 else { return false }

        let backupResult = backupExclusionAttributeName.withCString { name in
            backupExclusionAttributeValue.withUnsafeBytes { bytes in
                var result: Int32
                repeat {
                    result = Darwin.fsetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        0
                    )
                } while result != 0 && errno == EINTR
                return result
            }
        }
        return backupResult == 0
    }

    static func isExact(on fileDescriptor: Int32) -> Bool {
        var protectionClass: Int32
        repeat {
            protectionClass = Darwin.fcntl(fileDescriptor, F_GETPROTECTIONCLASS)
        } while protectionClass < 0 && errno == EINTR
        guard protectionClass == completeProtectionClass else { return false }

        let attributeSize = backupExclusionAttributeName.withCString { name in
            var result: Int
            repeat {
                result = Darwin.fgetxattr(fileDescriptor, name, nil, 0, 0, 0)
            } while result < 0 && errno == EINTR
            return result
        }
        guard attributeSize == backupExclusionAttributeValue.count else { return false }

        var actualValue = Data(count: attributeSize)
        let readSize = backupExclusionAttributeName.withCString { name in
            actualValue.withUnsafeMutableBytes { bytes in
                var result: Int
                repeat {
                    result = Darwin.fgetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        0
                    )
                } while result < 0 && errno == EINTR
                return result
            }
        }
        return readSize == attributeSize && actualValue == backupExclusionAttributeValue
    }
}

nonisolated struct DarwinOpenAITranscriptionPOSIXCalls: OpenAITranscriptionPOSIXCalling {
    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int { Darwin.read(fd, buffer, count) }
    func write(_ fd: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int { Darwin.write(fd, buffer, count) }
    func synchronize(_ fd: Int32) -> Int32 { Darwin.fsync(fd) }
    func pread(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int, _ offset: Int64) -> Int {
        Darwin.pread(fd, buffer, count, off_t(offset))
    }
}
