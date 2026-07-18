import Darwin
import Foundation

nonisolated struct OpenAIMultipartScratchTimestamp:
    Comparable,
    Equatable,
    Sendable {
    let seconds: Int64
    let nanoseconds: Int64

    static func < (
        lhs: OpenAIMultipartScratchTimestamp,
        rhs: OpenAIMultipartScratchTimestamp
    ) -> Bool {
        lhs.seconds < rhs.seconds
            || (lhs.seconds == rhs.seconds && lhs.nanoseconds < rhs.nanoseconds)
    }

    func isAtLeast(
        _ ageInSeconds: Int64,
        before reference: OpenAIMultipartScratchTimestamp
    ) -> Bool {
        guard self <= reference else {
            return false
        }
        let cutoff = reference.seconds.subtractingReportingOverflow(ageInSeconds)
        guard !cutoff.overflow else {
            return false
        }
        return self <= OpenAIMultipartScratchTimestamp(
            seconds: cutoff.partialValue,
            nanoseconds: reference.nanoseconds
        )
    }
}

nonisolated enum OpenAIMultipartScratchKind: Equatable, Sendable {
    case markedV1
    case legacy

    var minimumAgeInSeconds: Int64 {
        switch self {
        case .markedV1:
            60 * 60
        case .legacy:
            24 * 60 * 60
        }
    }
}

nonisolated enum OpenAIMultipartScratchDirectoryEntry: Equatable, Sendable {
    case name(String)
    case invalidName
}

nonisolated struct OpenAIMultipartScratchDeletionSnapshot: Equatable, Sendable {
    let identity: OpenAITranscriptionFileIdentity
    let referenceTime: OpenAIMultipartScratchTimestamp
    let minimumAgeInSeconds: Int64
}

nonisolated protocol OpenAIMultipartScratchCandidate: AnyObject {
    func makeDeletionSnapshot(
        referenceTime: OpenAIMultipartScratchTimestamp,
        minimumAgeInSeconds: Int64,
        shouldStartOperation: () -> Bool
    ) -> OpenAIMultipartScratchDeletionSnapshot?
    func removeIfUnchanged(
        _ snapshot: OpenAIMultipartScratchDeletionSnapshot,
        shouldStartOperation: () -> Bool
    ) -> Bool
    func close()
}

nonisolated protocol OpenAIMultipartScratchDirectory: AnyObject {
    func nextEntry(
        shouldStartOperation: () -> Bool
    ) throws -> OpenAIMultipartScratchDirectoryEntry?
    func openCandidate(
        named fileName: String,
        kind: OpenAIMultipartScratchKind,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchCandidate)?
    func close()
}

nonisolated protocol OpenAIMultipartScratchFileSystem {
    func openNamespace(
        at directoryURL: URL,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchDirectory)?
}

nonisolated struct OpenAIMultipartScratchScavengeSummary:
    Equatable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    enum StopReason: Equatable, Sendable {
        case complete
        case namespaceUnavailable
        case directoryFailure
        case entryLimit
        case removalLimit
        case byteLimit
        case timeLimit
        case clockFailure
    }

    let inspectedEntryCount: Int
    let removedFileCount: Int
    let accountedByteCount: Int64
    let stopReason: StopReason

    var description: String {
        "OpenAIMultipartScratchScavengeSummary(<redacted>)"
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .struct
        )
    }
}

nonisolated struct OpenAIMultipartScratchScavenger {
    static let maximumInspectedEntryCount = 256
    static let maximumRemovedFileCount = 32
    static let maximumAccountedByteCount: Int64 = 512 * 1_024 * 1_024
    static let maximumElapsedNanoseconds: UInt64 = 1_000_000_000

    private let namespaceURL: URL
    private let fileSystem: any OpenAIMultipartScratchFileSystem
    private let wallClock: @Sendable () -> OpenAIMultipartScratchTimestamp?
    private let monotonicClock: @Sendable () -> UInt64?

    init(
        namespaceURL: URL = OpenAIMultipartScratchNamespace.defaultDirectoryURL,
        fileSystem: any OpenAIMultipartScratchFileSystem =
            POSIXOpenAIMultipartScratchFileSystem(),
        wallClock: @escaping @Sendable () -> OpenAIMultipartScratchTimestamp? = {
            systemScratchTimestamp(clock: CLOCK_REALTIME)
        },
        monotonicClock: @escaping @Sendable () -> UInt64? = {
            systemScratchNanoseconds(clock: CLOCK_MONOTONIC)
        }
    ) {
        self.namespaceURL = namespaceURL
        self.fileSystem = fileSystem
        self.wallClock = wallClock
        self.monotonicClock = monotonicClock
    }

    func run() -> OpenAIMultipartScratchScavengeSummary {
        guard let referenceTime = wallClock(),
              let startTime = monotonicClock() else {
            return summary(stopReason: .clockFailure)
        }

        let directory: (any OpenAIMultipartScratchDirectory)?
        do {
            directory = try fileSystem.openNamespace(
                at: namespaceURL,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            )
        } catch {
            return summary(stopReason: .namespaceUnavailable)
        }
        guard withinTimeBudget(startTime: startTime) else {
            directory?.close()
            return summary(stopReason: .timeLimit)
        }
        guard let directory else {
            return summary(stopReason: .complete)
        }
        defer { directory.close() }

        var inspectedEntryCount = 0
        var removedFileCount = 0
        var accountedByteCount: Int64 = 0

        while true {
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard inspectedEntryCount < Self.maximumInspectedEntryCount else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .entryLimit
                )
            }

            let entry: OpenAIMultipartScratchDirectoryEntry?
            do {
                entry = try directory.nextEntry(
                    shouldStartOperation: {
                        withinTimeBudget(startTime: startTime)
                    }
                )
            } catch {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .directoryFailure
                )
            }
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard let entry else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .complete
                )
            }

            if case .name(let name) = entry, name == "." || name == ".." {
                continue
            }
            inspectedEntryCount += 1

            guard case .name(let fileName) = entry,
                  let kind = kind(for: fileName) else {
                continue
            }
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }

            let candidate: (any OpenAIMultipartScratchCandidate)?
            do {
                candidate = try directory.openCandidate(
                    named: fileName,
                    kind: kind,
                    shouldStartOperation: {
                        withinTimeBudget(startTime: startTime)
                    }
                )
            } catch {
                continue
            }
            guard let candidate else {
                continue
            }

            guard withinTimeBudget(startTime: startTime) else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard let deletionSnapshot = candidate.makeDeletionSnapshot(
                referenceTime: referenceTime,
                minimumAgeInSeconds: kind.minimumAgeInSeconds,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            ) else {
                candidate.close()
                continue
            }

            let byteCount = deletionSnapshot.identity.byteCount
            let addition = accountedByteCount.addingReportingOverflow(byteCount)
            guard !addition.overflow,
                  addition.partialValue <= Self.maximumAccountedByteCount else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .byteLimit
                )
            }
            accountedByteCount = addition.partialValue
            guard withinTimeBudget(startTime: startTime) else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }

            if candidate.removeIfUnchanged(
                deletionSnapshot,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            ) {
                removedFileCount += 1
            }
            candidate.close()
            guard removedFileCount < Self.maximumRemovedFileCount else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .removalLimit
                )
            }
        }
    }

    private func kind(for fileName: String) -> OpenAIMultipartScratchKind? {
        if OpenAIMultipartScratchNamespace.identifier(inV1FileName: fileName) != nil {
            return .markedV1
        }
        if OpenAIMultipartScratchNamespace.identifier(inLegacyFileName: fileName) != nil {
            return .legacy
        }
        return nil
    }

    private func withinTimeBudget(startTime: UInt64) -> Bool {
        guard let currentTime = monotonicClock(), currentTime >= startTime else {
            return false
        }
        return currentTime - startTime < Self.maximumElapsedNanoseconds
    }

    private func summary(
        inspected: Int = 0,
        removed: Int = 0,
        bytes: Int64 = 0,
        stopReason: OpenAIMultipartScratchScavengeSummary.StopReason
    ) -> OpenAIMultipartScratchScavengeSummary {
        OpenAIMultipartScratchScavengeSummary(
            inspectedEntryCount: inspected,
            removedFileCount: removed,
            accountedByteCount: bytes,
            stopReason: stopReason
        )
    }
}

nonisolated private func systemScratchTimestamp(
    clock: clockid_t
) -> OpenAIMultipartScratchTimestamp? {
    var value = timespec()
    guard Darwin.clock_gettime(clock, &value) == 0 else {
        return nil
    }
    return OpenAIMultipartScratchTimestamp(
        seconds: Int64(value.tv_sec),
        nanoseconds: Int64(value.tv_nsec)
    )
}

nonisolated private func systemScratchNanoseconds(clock: clockid_t) -> UInt64? {
    guard let value = systemScratchTimestamp(clock: clock),
          value.seconds >= 0,
          value.nanoseconds >= 0 else {
        return nil
    }
    let seconds = UInt64(value.seconds).multipliedReportingOverflow(
        by: 1_000_000_000
    )
    guard !seconds.overflow else {
        return nil
    }
    let total = seconds.partialValue.addingReportingOverflow(
        UInt64(value.nanoseconds)
    )
    return total.overflow ? nil : total.partialValue
}
