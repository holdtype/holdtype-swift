import Foundation

typealias KeyboardFixPollScheduler = (
    @escaping @MainActor () -> Void
) -> Timer?

@MainActor
struct KeyboardFixExtensionRuntimeDependencies {
    let loadMetadata: () throws -> KeyboardFixMetadataSnapshot?
    let publishRequest: (KeyboardFixRequestRecord) throws -> Void
    let postRequestChanged: () -> Void
    let publishCancellationRequest: (
        KeyboardFixCancellationRecord
    ) throws -> Void
    let postCancellationChanged: () -> Void
    let consumeCancellationAcknowledgement: (
        UUID,
        Date
    ) throws -> KeyboardFixCancellationRecord?
    let openContainingApp: (
        URL,
        @escaping @MainActor () -> Void
    ) -> Void
    let loadLatestResult: (Date) throws -> KeyboardFixResultRecord?
    let consumeTerminalResult: (
        KeyboardFixRequestIdentity,
        Date
    ) throws -> KeyboardFixResultRecord?
    let observeResults: (
        @escaping @MainActor () -> Void
    ) -> KeyboardDictationBridgeObserver?
    let observeCancellations: (
        @escaping @MainActor () -> Void
    ) -> KeyboardDictationBridgeObserver?
    let schedulePoll: KeyboardFixPollScheduler
    let now: () -> Date
    let makeRequestID: () -> UUID
    let currentTarget: () -> KeyboardFixExtensionTarget?
    let applyOutput: (
        String,
        KeyboardFixRequestIdentity
    ) -> Bool
    let hasFullAccess: () -> Bool
    let dictationIsBusy: () -> Bool

    static func live(
        currentTarget: @escaping () -> KeyboardFixExtensionTarget?,
        applyOutput: @escaping (
            String,
            KeyboardFixRequestIdentity
        ) -> Bool,
        openContainingApp: @escaping (
            URL,
            @escaping @MainActor () -> Void
        ) -> Void,
        hasFullAccess: @escaping () -> Bool,
        dictationIsBusy: @escaping () -> Bool
    ) -> Self {
        Self(
            loadMetadata: {
                try KeyboardFixBridgeStore.appGroup().loadMetadata()
            },
            publishRequest: { request in
                try KeyboardFixBridgeStore.appGroup()
                    .publishRequest(request)
            },
            postRequestChanged: {
                KeyboardFixBridgeSignal.postRequestChanged()
            },
            publishCancellationRequest: { cancellation in
                try KeyboardFixBridgeStore.appGroup()
                    .publishCancellationRequest(cancellation)
            },
            postCancellationChanged: {
                KeyboardFixBridgeSignal.postCancellationChanged()
            },
            consumeCancellationAcknowledgement: {
                requestID,
                date in
                try KeyboardFixBridgeStore.appGroup()
                    .consumeCancellationAcknowledgement(
                        matching: requestID,
                        at: date
                    )
            },
            openContainingApp: openContainingApp,
            loadLatestResult: { date in
                try KeyboardFixBridgeStore.appGroup()
                    .loadLatestResult(at: date)
            },
            consumeTerminalResult: { identity, date in
                try KeyboardFixBridgeStore.appGroup()
                    .consumeTerminalResult(
                        matching: identity,
                        at: date
                    )
            },
            observeResults: { action in
                KeyboardDictationBridgeObserver(
                    name: KeyboardFixBridgeConfiguration.resultNotification,
                    action: action
                )
            },
            observeCancellations: { action in
                KeyboardDictationBridgeObserver(
                    name:
                        KeyboardFixBridgeConfiguration
                            .cancellationNotification,
                    action: action
                )
            },
            schedulePoll: { action in
                let timer = Timer(
                    timeInterval: 0.25,
                    repeats: true
                ) { _ in
                    Task { @MainActor in action() }
                }
                RunLoop.main.add(timer, forMode: .common)
                return timer
            },
            now: { Date() },
            makeRequestID: { UUID() },
            currentTarget: currentTarget,
            applyOutput: applyOutput,
            hasFullAccess: hasFullAccess,
            dictationIsBusy: dictationIsBusy
        )
    }
}
