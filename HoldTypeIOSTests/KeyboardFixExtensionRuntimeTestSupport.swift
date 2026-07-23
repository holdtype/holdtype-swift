import Foundation
import Testing

@MainActor
final class KeyboardFixExtensionRuntimeFixture {
    let metadata: KeyboardFixMetadataSnapshot
    var now = Date(timeIntervalSince1970: 1_750_000_000)
    var target: KeyboardFixExtensionTarget? = KeyboardFixExtensionTarget(
        documentIdentifier: "document-id",
        selectedText: "Selected text"
    )
    var hasFullAccess = true
    var dictationIsBusy = false
    var publishedRequest: KeyboardFixRequestRecord?
    var latestResult: KeyboardFixResultRecord?
    var postRequestCount = 0
    var openedURLs: [URL] = []
    var openFailure: (@MainActor () -> Void)?
    var cancellationRequest: KeyboardFixCancellationRecord?
    var cancellationAcknowledgement: KeyboardFixCancellationRecord?
    var postCancellationCount = 0
    var appliedOutputs: [String] = []
    var resultObserverAction: (@MainActor () -> Void)?
    var cancellationObserverAction: (@MainActor () -> Void)?
    var shouldFailPublishingRequest = false

    init() throws {
        metadata = try makeKeyboardFixMetadataSnapshot()
    }

    func makeRuntime(
        diagnostics: IOSRuntimeTextFixDiagnosticClient = .silent
    ) -> KeyboardFixExtensionRuntime {
        KeyboardFixExtensionRuntime(
            dependencies: KeyboardFixExtensionRuntimeDependencies(
                loadMetadata: { [unowned self] in metadata },
                publishRequest: { [unowned self] request in
                    if shouldFailPublishingRequest {
                        throw KeyboardFixExtensionRuntimeFixtureError
                            .injectedBridgeFailure
                    }
                    publishedRequest = request
                },
                postRequestChanged: { [unowned self] in
                    postRequestCount += 1
                },
                publishCancellationRequest: {
                    [unowned self] cancellation in
                    cancellationRequest = cancellation
                    if publishedRequest?.requestID
                        == cancellation.requestID {
                        publishedRequest = nil
                    }
                    if latestResult?.requestID
                        == cancellation.requestID {
                        latestResult = nil
                    }
                },
                postCancellationChanged: { [unowned self] in
                    postCancellationCount += 1
                },
                consumeCancellationAcknowledgement: {
                    [unowned self] requestID,
                    date in
                    guard let cancellationAcknowledgement,
                          cancellationAcknowledgement.requestID
                            == requestID,
                          cancellationAcknowledgement.isValid(at: date)
                    else {
                        return nil
                    }
                    self.cancellationAcknowledgement = nil
                    return cancellationAcknowledgement
                },
                openContainingApp: { [unowned self] url, onFailure in
                    openedURLs.append(url)
                    openFailure = onFailure
                },
                loadLatestResult: { [unowned self] date in
                    guard let latestResult,
                          latestResult.isValid(at: date)
                    else {
                        return nil
                    }
                    return latestResult
                },
                consumeTerminalResult: {
                    [unowned self] identity,
                    date in
                    guard let latestResult,
                          latestResult.matches(identity),
                          latestResult.isTerminal,
                          latestResult.isValid(at: date)
                    else {
                        return nil
                    }
                    self.latestResult = nil
                    return latestResult
                },
                observeResults: { [unowned self] action in
                    resultObserverAction = action
                    return nil
                },
                observeCancellations: { [unowned self] action in
                    cancellationObserverAction = action
                    return nil
                },
                schedulePoll: { _ in nil },
                now: { [unowned self] in now },
                makeRequestID: { UUID() },
                currentTarget: { [unowned self] in target },
                applyOutput: {
                    [unowned self] output,
                    identity in
                    guard target?.matches(identity) == true else {
                        return false
                    }
                    appliedOutputs.append(output)
                    return true
                },
                hasFullAccess: { [unowned self] in hasFullAccess },
                dictationIsBusy: {
                    [unowned self] in dictationIsBusy
                },
                diagnostics: diagnostics
            )
        )
    }

    func publishSuccess(
        output: String = "Improved text"
    ) throws {
        let request = try requireRequest()
        now = request.issuedAt.addingTimeInterval(1)
        latestResult = try makeKeyboardFixResult(
            request: request,
            outputText: output,
            publishedAt: now
        )
    }

    func requireRequest() throws -> KeyboardFixRequestRecord {
        guard let publishedRequest else {
            throw KeyboardFixExtensionRuntimeFixtureError.missingRequest
        }
        return publishedRequest
    }

    func requireCancellation() throws
        -> KeyboardFixCancellationRecord {
        guard let cancellationRequest else {
            throw KeyboardFixExtensionRuntimeFixtureError
                .missingCancellation
        }
        return cancellationRequest
    }

    func acknowledgeCancellation(
        requestID: UUID? = nil
    ) throws {
        let cancellation = try requireCancellation()
        let acknowledgedRequestID = requestID
            ?? cancellation.requestID
        let requested = try #require(
            KeyboardFixCancellationRecord(
                requestID: acknowledgedRequestID,
                issuedAt: cancellation.issuedAt,
                expiresAt: cancellation.expiresAt
            )
        )
        now = cancellation.issuedAt.addingTimeInterval(1)
        cancellationAcknowledgement = requested.acknowledging(at: now)
        cancellationObserverAction?()
    }
}

enum KeyboardFixExtensionRuntimeFixtureError: Error {
    case missingRequest
    case missingCancellation
    case injectedBridgeFailure
}
