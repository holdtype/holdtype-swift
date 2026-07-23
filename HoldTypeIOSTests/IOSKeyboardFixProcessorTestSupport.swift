import Foundation
import HoldTypeDomain
@testable import HoldTypeIOS

typealias ProcessorTestRequest = HoldTypeIOS.KeyboardFixRequestRecord
typealias ProcessorTestResult = HoldTypeIOS.KeyboardFixResultRecord

enum IOSKeyboardFixProcessorTestError: Error {
    case invalidRequest
    case timedOut
}

final class IOSKeyboardFixTestBridgeProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var request: ProcessorTestRequest?
    private var consumedCountStorage = 0
    private var resultsStorage: [ProcessorTestResult] = []

    init(request: ProcessorTestRequest?) {
        self.request = request
    }

    var client: IOSKeyboardFixBridgeClient {
        IOSKeyboardFixBridgeClient(
            consumeRequest: { [self] _ in consume() },
            publishResult: { [self] result in publish(result) }
        )
    }

    var consumedCount: Int {
        lock.withLock { consumedCountStorage }
    }

    var results: [ProcessorTestResult] {
        lock.withLock { resultsStorage }
    }

    private func consume() -> ProcessorTestRequest? {
        lock.withLock {
            consumedCountStorage += 1
            defer { request = nil }
            return request
        }
    }

    private func publish(_ result: ProcessorTestResult) {
        lock.withLock {
            resultsStorage.append(result)
        }
    }
}

final class IOSKeyboardFixTestSignalProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var signalsStorage: [IOSKeyboardFixProcessorSignal] = []

    var client: IOSKeyboardFixSignalClient {
        IOSKeyboardFixSignalClient { [self] signal in
            lock.withLock {
                signalsStorage.append(signal)
            }
        }
    }

    var signals: [IOSKeyboardFixProcessorSignal] {
        lock.withLock { signalsStorage }
    }
}

final class IOSKeyboardFixTestBackgroundProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var expirationHandler: (@Sendable () -> Void)?
    private var beginCountStorage = 0
    private var endCountStorage = 0

    var client: IOSKeyboardFixBackgroundTaskClient {
        IOSKeyboardFixBackgroundTaskClient(
            begin: { [self] expirationHandler in
                lock.withLock {
                    beginCountStorage += 1
                    self.expirationHandler = expirationHandler
                }
                return IOSKeyboardFixBackgroundTaskToken()
            },
            end: { [self] _ in
                lock.withLock {
                    endCountStorage += 1
                    expirationHandler = nil
                }
            }
        )
    }

    var beginCount: Int {
        lock.withLock { beginCountStorage }
    }

    var endCount: Int {
        lock.withLock { endCountStorage }
    }

    func expire() {
        let handler = lock.withLock { expirationHandler }
        handler?()
    }
}

final class IOSKeyboardFixTestExecutionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, any Error>?
    private var cancellationPending = false
    private var executeCountStorage = 0
    private let output: String

    init(output: String = "  Exact transformed output\n") {
        self.output = output
    }

    var client: IOSKeyboardFixExecutionClient {
        IOSKeyboardFixExecutionClient { [self] _ in
            try await execute()
        }
    }

    var executeCount: Int {
        lock.withLock { executeCountStorage }
    }

    func open() {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume(returning: output)
    }

    private func execute() async throws -> String {
        lock.withLock {
            executeCountStorage += 1
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let shouldCancel = lock.withLock {
                    if cancellationPending {
                        cancellationPending = false
                        return true
                    }
                    self.continuation = continuation
                    return false
                }
                if shouldCancel {
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let continuation:
                CheckedContinuation<String, any Error>? = lock.withLock {
                guard let value = self.continuation else {
                    cancellationPending = true
                    return nil
                }
                self.continuation = nil
                return value
            }
            continuation?.resume(throwing: CancellationError())
        }
    }
}

final class IOSKeyboardFixTestInputProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var inputsStorage: [IOSKeyboardFixExecutionInput] = []

    var inputs: [IOSKeyboardFixExecutionInput] {
        lock.withLock { inputsStorage }
    }

    func record(_ input: IOSKeyboardFixExecutionInput) {
        lock.withLock {
            inputsStorage.append(input)
        }
    }
}

func makeProcessorTestRequest(
    actionIdentifier: String = TextFixAction.translateIdentifier,
    sourceText: String = "  Selected source\n",
    issuedAt: Date = Date(timeIntervalSince1970: 1_750_000_000),
    expiresAt: Date? = nil
) throws -> ProcessorTestRequest {
    guard let request = ProcessorTestRequest(
        revision: 7,
        requestID: UUID(),
        actionIdentifier: actionIdentifier,
        sourceText: sourceText,
        documentIdentifier: "document-identity",
        sourceFingerprint: "source-fingerprint",
        issuedAt: issuedAt,
        expiresAt: expiresAt
            ?? issuedAt.addingTimeInterval(
                HoldTypeIOS.KeyboardFixBridgeConfiguration.recordLifetime
            )
    ) else {
        throw IOSKeyboardFixProcessorTestError.invalidRequest
    }
    return request
}

func makeKeyboardFixProcessor(
    bridge: IOSKeyboardFixBridgeClient,
    now: Date,
    catalog: @escaping @Sendable () async throws -> TextFixCatalog = {
        .defaults
    },
    settings: @escaping @Sendable (TextFixAction) async throws ->
        IOSKeyboardFixSettingsReadiness = { _ in .ready },
    consent: @escaping @Sendable () async throws -> Bool = { true },
    credential: @escaping @Sendable () async throws -> Bool = { true },
    execute: @escaping @Sendable (IOSKeyboardFixExecutionInput) async throws ->
        String,
    background: IOSKeyboardFixBackgroundTaskClient = .foregroundOnly,
    signals: IOSKeyboardFixSignalClient = .silent
) -> IOSKeyboardFixProcessor {
    IOSKeyboardFixProcessor(
        bridge: bridge,
        catalog: IOSKeyboardFixCatalogClient(load: catalog),
        settings: IOSKeyboardFixSettingsClient(readiness: settings),
        consent: IOSKeyboardFixConsentV4Client(isAccepted: consent),
        credential: IOSKeyboardFixCredentialClient(isAvailable: credential),
        executor: IOSKeyboardFixExecutionClient(execute: execute),
        backgroundTask: background,
        clock: IOSKeyboardFixProcessorClock(now: { now }),
        signals: signals
    )
}

func processorEventually(
    _ predicate: @escaping @Sendable () -> Bool
) async throws {
    for _ in 0..<500 {
        if predicate() {
            return
        }
        await Task.yield()
    }
    throw IOSKeyboardFixProcessorTestError.timedOut
}
