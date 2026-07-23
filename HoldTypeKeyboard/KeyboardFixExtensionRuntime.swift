import Foundation

@MainActor
final class KeyboardFixExtensionRuntime {
    struct ActiveRequest {
        let identity: KeyboardFixRequestIdentity
        let actionTitle: String
        let expiresAt: Date
    }

    struct PendingCancellation {
        let requestID: UUID
        let expiresAt: Date
        let completionStatus: KeyboardFixExtensionStatus
    }

    var presentation = KeyboardFixExtensionPresentation.unavailable {
        didSet {
            guard oldValue != presentation else { return }
            onPresentationChanged?(presentation)
        }
    }

    var onPresentationChanged: ((KeyboardFixExtensionPresentation) -> Void)?

    let dependencies: KeyboardFixExtensionRuntimeDependencies
    var metadata: KeyboardFixMetadataSnapshot?
    var activeRequest: ActiveRequest?
    var pendingCancellation: PendingCancellation?
    private var resultObserver: KeyboardDictationBridgeObserver?
    private var cancellationObserver: KeyboardDictationBridgeObserver?
    private var pollTimer: Timer?
    private var requestRevision: UInt64 = 0
    init(dependencies: KeyboardFixExtensionRuntimeDependencies) {
        self.dependencies = dependencies
    }
    func start() {
        guard resultObserver == nil, cancellationObserver == nil else {
            refreshAvailability()
            return
        }
        resultObserver = dependencies.observeResults { [weak self] in
            self?.handleResultSignal()
        }
        cancellationObserver = dependencies.observeCancellations {
            [weak self] in
            self?.poll()
        }
        reloadMetadata()
        if activeRequest == nil {
            recoverLatestResult()
        } else {
            beginPolling()
            poll()
        }
    }
    func stop() {
        resultObserver = nil
        cancellationObserver = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }
    func reloadMetadata() {
        do {
            metadata = try dependencies.loadMetadata()
        } catch {
            metadata = nil
            dependencies.diagnostics.record(
                .eligibility,
                outcome: .bridgeUnavailable
            )
        }
        refreshAvailability(resetTransientStatus: true)
    }

    func refreshAvailability(
        resetTransientStatus: Bool = false
    ) {
        guard activeRequest == nil else { return }
        let actions = metadata?.enabledActions ?? []
        if !dependencies.hasFullAccess() {
            presentation = KeyboardFixExtensionPresentation(
                actions: actions,
                status: .unavailable(
                    message: "Allow Full Access to use Fixes."
                )
            )
        } else if dependencies.dictationIsBusy() {
            presentation = KeyboardFixExtensionPresentation(
                actions: actions,
                status: .unavailable(
                    message: "Finish dictation before using Fixes."
                )
            )
        } else if metadata == nil {
            presentation = .unavailable
        } else if dependencies.currentTarget() == nil {
            presentation = KeyboardFixExtensionPresentation(
                actions: actions,
                status: .unavailable(
                    message: "Select text in the current field."
                )
            )
        } else {
            let readyStatus: KeyboardFixExtensionStatus
            if !resetTransientStatus {
                switch presentation.status {
                case .failure, .applied:
                    readyStatus = presentation.status
                case .ready, .unavailable, .processing, .cancelling:
                    readyStatus = .ready
                }
            } else {
                readyStatus = .ready
            }
            presentation = KeyboardFixExtensionPresentation(
                actions: actions,
                status: readyStatus
            )
        }
    }

    func activate(actionIdentifier: String) {
        guard activeRequest == nil else {
            dependencies.diagnostics.record(
                .eligibility,
                actionIdentifier: actionIdentifier,
                outcome: .busy
            )
            refreshAvailability()
            return
        }
        guard dependencies.hasFullAccess() else {
            dependencies.diagnostics.record(
                .eligibility,
                actionIdentifier: actionIdentifier,
                outcome: .blocked
            )
            refreshAvailability()
            return
        }
        guard !dependencies.dictationIsBusy() else {
            dependencies.diagnostics.record(
                .eligibility,
                actionIdentifier: actionIdentifier,
                outcome: .busy
            )
            refreshAvailability()
            return
        }
        guard let metadata,
              let action = metadata.enabledActions.first(where: {
                  $0.identifier == actionIdentifier
              })
        else {
            dependencies.diagnostics.record(
                .eligibility,
                actionIdentifier: actionIdentifier,
                outcome: .unavailable
            )
            refreshAvailability()
            return
        }
        guard let target = dependencies.currentTarget() else {
            dependencies.diagnostics.record(
                .eligibility,
                actionIdentifier: actionIdentifier,
                outcome: .blocked
            )
            refreshAvailability()
            return
        }

        let now = dependencies.now()
        requestRevision = requestRevision == UInt64.max
            ? 1
            : requestRevision + 1
        guard let request = KeyboardFixRequestRecord(
            revision: requestRevision,
            requestID: dependencies.makeRequestID(),
            actionIdentifier: action.identifier,
            sourceText: target.selectedText,
            documentIdentifier: target.documentIdentifier,
            sourceFingerprint: target.fingerprint,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(
                KeyboardFixBridgeConfiguration.recordLifetime
            )
        ) else {
            presentation = KeyboardFixExtensionPresentation(
                actions: metadata.enabledActions,
                status: .failure(
                    message: "This selection cannot be processed."
                )
            )
            dependencies.diagnostics.record(
                .request,
                actionIdentifier: actionIdentifier,
                outcome: .failed
            )
            return
        }

        do {
            try dependencies.publishRequest(request)
        } catch {
            presentation = KeyboardFixExtensionPresentation(
                actions: metadata.enabledActions,
                status: .failure(
                    message: "HoldType could not send this Fix."
                )
            )
            dependencies.diagnostics.record(
                .request,
                actionIdentifier: action.identifier,
                requestID: request.requestID,
                outcome: .bridgeUnavailable
            )
            return
        }

        activeRequest = ActiveRequest(
            identity: request.identity,
            actionTitle: action.title,
            expiresAt: request.expiresAt
        )
        presentation = KeyboardFixExtensionPresentation(
            actions: metadata.enabledActions,
            status: .processing(actionIdentifier: action.identifier)
        )
        dependencies.diagnostics.record(
            .request,
            actionIdentifier: action.identifier,
            requestID: request.requestID,
            outcome: .started
        )
        beginPolling()
        dependencies.postRequestChanged()
        launchContainingApp(for: request)
    }

    func poll() {
        guard let activeRequest else { return }
        let now = dependencies.now()
        if pendingCancellation != nil {
            pollCancellation(at: now)
            return
        }
        guard now < activeRequest.expiresAt else {
            dependencies.diagnostics.record(
                .result,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .timedOut
            )
            requestCancellation(
                completingWith: .failure(
                    message: "The Fix timed out. Try again."
                )
            )
            return
        }

        let result: KeyboardFixResultRecord?
        do {
            result = try dependencies.loadLatestResult(now)
        } catch {
            finishActiveRequest(
                status: .failure(
                    message: "HoldType could not read this Fix."
                )
            )
            dependencies.diagnostics.record(
                .result,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .bridgeUnavailable
            )
            return
        }
        guard let result,
              result.matches(activeRequest.identity)
        else {
            return
        }
        guard result.isTerminal else {
            presentation = currentPresentation(
                status: .processing(
                    actionIdentifier: result.actionIdentifier
                )
            )
            return
        }

        let consumed: KeyboardFixResultRecord?
        do {
            consumed = try dependencies.consumeTerminalResult(
                activeRequest.identity,
                now
            )
        } catch {
            finishActiveRequest(
                status: .failure(
                    message: "HoldType could not finish this Fix."
                )
            )
            dependencies.diagnostics.record(
                .result,
                actionIdentifier:
                    activeRequest.identity.actionIdentifier,
                requestID: activeRequest.identity.requestID,
                outcome: .bridgeUnavailable
            )
            return
        }
        guard let consumed else { return }
        handleTerminal(consumed, activeRequest: activeRequest)
    }

    private func handleResultSignal() {
        if activeRequest == nil {
            recoverLatestResult()
        } else {
            poll()
        }
    }

    func beginPolling() {
        pollTimer?.invalidate()
        pollTimer = dependencies.schedulePoll { [weak self] in
            self?.poll()
        }
    }

    func finishActiveRequest(
        status: KeyboardFixExtensionStatus
    ) {
        activeRequest = nil
        pendingCancellation = nil
        pollTimer?.invalidate()
        pollTimer = nil
        presentation = currentPresentation(status: status)
    }

    func currentPresentation(
        status: KeyboardFixExtensionStatus
    ) -> KeyboardFixExtensionPresentation {
        KeyboardFixExtensionPresentation(
            actions: metadata?.enabledActions ?? [],
            status: status
        )
    }
}
