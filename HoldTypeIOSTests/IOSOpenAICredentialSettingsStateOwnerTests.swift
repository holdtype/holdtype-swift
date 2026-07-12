import Foundation
import HoldTypeIOSCore
import SwiftUI
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSOpenAICredentialSettingsStateOwnerTests {
    @Test func constructionIsPassiveAndFirstDetailLoadIsMarkerOnly()
        async {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [credentialStatus(.savedLastKnown)]
        )
        let client = fixture.makeClient()
        let owner = IOSOpenAICredentialSettingsStateOwner(client: client)

        #expect(owner.state == .notLoaded)
        #expect(owner.operation == .idle)
        #expect(await fixture.calls() == .zero)

        await owner.activateForDetailAppearance()

        #expect(
            owner.state == .ready(credentialStatus(.savedLastKnown))
        )
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 1,
                    statusUpdates: 1
                )
        )

        await owner.activateForDetailAppearance()
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 2,
                    statusUpdates: 1
                )
        )
    }

    @Test func unavailableInfrastructureNeverMeansNotConfigured() async {
        let owner = IOSOpenAICredentialSettingsStateOwner(client: nil)

        #expect(owner.state == .unavailable)
        await owner.activateForDetailAppearance()
        await owner.refresh()
        #expect(!(await owner.saveOrReplace("sk-unused")))
        #expect(!(await owner.remove()))
        #expect(owner.state == .unavailable)
        #expect(owner.notice == nil)
        #expect(owner.failure == nil)
    }

    @Test func saveAndRemovePublishOnlyPassiveStatusAndPartialSuccess()
        async {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
                credentialStatus(
                    .availableInThisProcess,
                    statusNeedsRefresh: true
                ),
                credentialStatus(.notConfigured),
            ],
            savePlan: .success(.appliedStatusNeedsRefresh),
            removePlan: .success(.applied)
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        #expect(await owner.saveOrReplace("  candidate-key  "))
        #expect(
            owner.state == .ready(
                credentialStatus(
                    .availableInThisProcess,
                    statusNeedsRefresh: true
                )
            )
        )
        #expect(owner.notice == .savedStatusNeedsRefresh)
        #expect(owner.failure == nil)
        #expect(await fixture.savedCandidates() == ["candidate-key"])

        #expect(await owner.remove())
        #expect(owner.state == .ready(credentialStatus(.notConfigured)))
        #expect(owner.notice == .removed)
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 3,
                    saveOrReplace: 1,
                    remove: 1,
                    statusUpdates: 1
                )
        )

        await owner.activateForDetailAppearance()
        #expect(owner.notice == nil)
        #expect(owner.failure == nil)
    }

    @Test func failedRefreshUsesMarkerOnlyStatusAndClosedError()
        async throws {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
                credentialStatus(.unavailableWhileLocked),
            ],
            refreshPlan: .coordinatorFailure(
                .credentialAccessFailed(
                    .unavailableWhileLocked,
                    markerRestorationFailed: false
                )
            )
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        await owner.refresh()

        #expect(
            owner.state == .ready(
                credentialStatus(.unavailableWhileLocked)
            )
        )
        #expect(owner.failure == .unavailableWhileLocked)
        #expect(owner.notice == nil)
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 2,
                    refresh: 1,
                    statusUpdates: 1
                )
        )

        await fixture.publishStatus(
            credentialStatus(.availableInThisProcess)
        )
        try await eventually {
            owner.state
                == .ready(credentialStatus(.availableInThisProcess))
        }
        #expect(owner.failure == .unavailableWhileLocked)

        await fixture.setRefreshPlan(
            .success(credentialStatus(.availableInThisProcess))
        )
        await owner.refresh()
        #expect(owner.failure == nil)
        #expect(owner.notice == .checked)
    }

    @Test func failedRefreshRemainsVisibleOverOlderRuntimeCache()
        async throws {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.availableInThisProcess),
                credentialStatus(.availableInThisProcess),
            ],
            refreshPlan: .coordinatorFailure(
                .credentialAccessFailed(
                    .unavailableWhileLocked,
                    markerRestorationFailed: false
                )
            )
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        await owner.refresh()

        #expect(
            owner.state
                == .ready(credentialStatus(.availableInThisProcess))
        )
        #expect(owner.failure == .unavailableWhileLocked)

        await fixture.publishStatus(
            credentialStatus(.availableInThisProcess)
        )
        for _ in 0..<10 { await Task.yield() }
        #expect(owner.failure == .unavailableWhileLocked)

        await fixture.setRefreshPlan(
            .success(credentialStatus(.availableInThisProcess))
        )
        await owner.refresh()
        #expect(owner.failure == nil)
    }

    @Test func unreadableKeychainFailureSurvivesCacheOnlyUpdate()
        async throws {
        let available = credentialStatus(.availableInThisProcess)
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [available, available],
            refreshPlan: .coordinatorFailure(
                .credentialAccessFailed(
                    .invalidStoredCredential,
                    markerRestorationFailed: false
                )
            )
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        await owner.refresh()
        #expect(owner.failure == .savedCredentialUnreadable)

        await fixture.publishStatus(available)
        for _ in 0..<10 { await Task.yield() }
        #expect(owner.failure == .savedCredentialUnreadable)

        await fixture.setRefreshPlan(.success(available))
        await owner.refresh()
        #expect(owner.failure == nil)
        #expect(owner.notice == .checked)
    }

    @Test func failedSavePreservesStatusAndRedactsUnknownError()
        async throws {
        let sentinel = "sk-owner-must-not-retain-this-sentinel"
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
                credentialStatus(.savedLastKnown),
            ],
            savePlan: .secretFailure(sentinel)
        )
        let client = fixture.makeClient()
        let owner = IOSOpenAICredentialSettingsStateOwner(client: client)
        await owner.activateForDetailAppearance()

        #expect(!(await owner.saveOrReplace(sentinel)))
        #expect(
            owner.state == .ready(credentialStatus(.savedLastKnown))
        )
        #expect(owner.failure == .operationFailed)
        #expect(owner.notice == nil)

        await fixture.publishStatus(credentialStatus(.savedLastKnown))
        try await eventually {
            owner.state == .ready(credentialStatus(.savedLastKnown))
                && owner.failure == .operationFailed
        }

        var output = ""
        dump(owner, to: &output)
        dump(client, to: &output)
        output += String(describing: owner)
        output += String(reflecting: owner)
        output += String(describing: client)
        output += String(reflecting: client)
        #expect(!output.contains(sentinel))
    }

    @Test func failedNavigationSaveKeepsSceneDraftAndFailureOnReentry()
        async throws {
        let sentinel = "sk-scene-retry-draft"
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
                credentialStatus(.savedLastKnown),
                credentialStatus(.savedLastKnown),
            ],
            savePlan: .secretFailure("redacted-fixture-error")
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        var sceneDraft = IOSOpenAICredentialEditorDraft { nil }
        sceneDraft.beginFocusSession()
        sceneDraft.value = sentinel
        await owner.activateForDetailAppearance()

        let candidate = sceneDraft.candidateForManualCommit()
        #expect(candidate == sentinel)
        #expect(!(await owner.saveOrReplace(try #require(candidate))))
        await owner.activateForDetailAppearance()

        #expect(sceneDraft.value == sentinel)
        #expect(owner.failure == .operationFailed)
    }

    @Test func busyOwnerSuppressesOverlappingSceneActions() async throws {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
                credentialStatus(.availableInThisProcess),
            ],
            suspendSave: true
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        let save = Task { await owner.saveOrReplace("one-shared-key") }
        try await eventually {
            await fixture.calls().saveOrReplace == 1
        }
        #expect(owner.operation == .saving)

        await owner.refresh()
        #expect(!(await owner.remove()))
        #expect(!(await owner.saveOrReplace("second-key")))
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 1,
                    saveOrReplace: 1,
                    statusUpdates: 1
                )
        )

        await fixture.resumeSave()
        #expect(await save.value)
        #expect(owner.operation == .idle)
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 2,
                    saveOrReplace: 1,
                    statusUpdates: 1
                )
        )
    }

    @Test func externalCoordinatorStatusUpdatesReachAnOpenDetail()
        async throws {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [credentialStatus(.availableInThisProcess)]
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        await fixture.publishStatus(credentialStatus(.providerRejected))
        try await eventually {
            owner.state == .ready(credentialStatus(.providerRejected))
        }

        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 1,
                    statusUpdates: 1
                )
        )
    }

    @Test func statusObservedWhileBusyReconcilesAfterTheAction()
        async throws {
        let fixture = CredentialSettingsClientFixture(
            passiveStatuses: [
                credentialStatus(.savedLastKnown),
            ],
            suspendSave: true
        )
        let owner = IOSOpenAICredentialSettingsStateOwner(
            client: fixture.makeClient()
        )
        await owner.activateForDetailAppearance()

        let save = Task { await owner.saveOrReplace("one-key") }
        try await eventually {
            await fixture.calls().saveOrReplace == 1
        }
        await fixture.publishStatus(credentialStatus(.providerRejected))
        for _ in 0..<10 { await Task.yield() }
        #expect(owner.operation == .saving)
        await fixture.resumeSave()
        #expect(await save.value)

        try await eventually {
            owner.state == .ready(credentialStatus(.providerRejected))
        }
        #expect(
            await fixture.calls()
                == CredentialSettingsClientCalls(
                    passiveStatus: 2,
                    saveOrReplace: 1,
                    statusUpdates: 1
                )
        )
    }

    @Test func draftNormalizesAndRedactsSecretMaterial() {
        let sentinel = "sk-local-draft-secret"
        var draft = IOSAPIKeyDraft(value: "  \(sentinel)\n")

        #expect(draft.normalizedValue == sentinel)
        var output = ""
        dump(draft, to: &output)
        output += String(describing: draft)
        output += String(reflecting: draft)
        #expect(!output.contains(sentinel))

        draft.clear()
        #expect(draft.value.isEmpty)
        #expect(draft.normalizedValue.isEmpty)
    }

    @Test func editorViewReflectionCannotTraverseSceneDraft() {
        let sentinel = "sk-view-reflection-secret"
        var sceneDraft = IOSOpenAICredentialEditorDraft { nil }
        sceneDraft.value = sentinel
        let binding = Binding(
            get: { sceneDraft },
            set: { sceneDraft = $0 }
        )
        let view = IOSOpenAISettingsView(editorDraft: binding)

        var output = ""
        dump(view, to: &output)
        output += String(describing: view)
        output += String(reflecting: view)
        #expect(!output.contains(sentinel))
    }

    @Test func editorDraftReadsClipboardOnlyFromExplicitPaste() {
        let sentinel = "sk-explicit-paste-only"
        var clipboardReads = 0
        var editorDraft = IOSOpenAICredentialEditorDraft {
            clipboardReads += 1
            return "  \(sentinel)  "
        }

        editorDraft.value = "typed-without-paste"
        #expect(clipboardReads == 0)
        #expect(editorDraft.normalizedValue == "typed-without-paste")

        let didPaste = editorDraft.pasteFromClipboard()
        #expect(didPaste)
        #expect(clipboardReads == 1)
        #expect(editorDraft.normalizedValue == sentinel)

        var output = ""
        dump(editorDraft, to: &output)
        output += String(describing: editorDraft)
        output += String(reflecting: editorDraft)
        #expect(!output.contains(sentinel))
    }

    @Test func emptyClipboardPastePreservesExistingDraft() {
        var clipboardReads = 0
        var editorDraft = IOSOpenAICredentialEditorDraft {
            clipboardReads += 1
            return "  \n "
        }
        editorDraft.value = "existing-draft"

        let didPaste = editorDraft.pasteFromClipboard()
        #expect(!didPaste)
        #expect(clipboardReads == 1)
        #expect(editorDraft.value == "existing-draft")
    }

    @Test func oneFocusSessionProducesOnlyOneManualCommitCandidate() {
        var editorDraft = IOSOpenAICredentialEditorDraft { nil }
        editorDraft.beginFocusSession()
        editorDraft.value = "one-key"

        let submitCandidate = editorDraft.candidateForManualCommit()
        let focusLossCandidate = editorDraft.candidateForManualCommit()
        #expect(submitCandidate == "one-key")
        #expect(focusLossCandidate == nil)

        editorDraft.beginFocusSession()
        let explicitRetryCandidate = editorDraft.candidateForManualCommit()
        #expect(explicitRetryCandidate == "one-key")
    }

    @Test func alternateActionSuppressesFocusLossCommit() {
        var editorDraft = IOSOpenAICredentialEditorDraft { "pasted-key" }
        editorDraft.beginFocusSession()
        editorDraft.value = "typed-key"
        editorDraft.suppressManualCommitForCurrentFocusSession()

        let focusLossCandidate = editorDraft.candidateForManualCommit()
        #expect(focusLossCandidate == nil)
        let didPaste = editorDraft.pasteFromClipboard()
        #expect(didPaste)
        #expect(editorDraft.value == "pasted-key")
    }
}

private struct CredentialSettingsClientCalls: Equatable, Sendable {
    var passiveStatus = 0
    var refresh = 0
    var saveOrReplace = 0
    var remove = 0
    var statusUpdates = 0

    static let zero = CredentialSettingsClientCalls()
}

private actor CredentialSettingsClientFixture {
    enum RefreshPlan: Sendable {
        case success(IOSOpenAICredentialStatus)
        case coordinatorFailure(IOSOpenAICredentialCoordinatorError)
        case secretFailure(String)
    }

    enum MutationPlan: Sendable {
        case success(IOSOpenAICredentialMutationOutcome)
        case coordinatorFailure(IOSOpenAICredentialCoordinatorError)
        case secretFailure(String)
    }

    private var passiveStatuses: [IOSOpenAICredentialStatus]
    private var lastPassiveStatus: IOSOpenAICredentialStatus
    private var refreshPlan: RefreshPlan
    private var savePlan: MutationPlan
    private var removePlan: MutationPlan
    private var recordedCalls = CredentialSettingsClientCalls.zero
    private var candidates: [String] = []
    private var shouldSuspendSave: Bool
    private var statusRevision: UInt64 = 0
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var statusUpdateContinuations: [
        AsyncStream<IOSOpenAICredentialStatusUpdate>.Continuation
    ] = []

    init(
        passiveStatuses: [IOSOpenAICredentialStatus],
        refreshPlan: RefreshPlan? = nil,
        savePlan: MutationPlan = .success(.applied),
        removePlan: MutationPlan = .success(.applied),
        suspendSave: Bool = false
    ) {
        let fallback = credentialStatus(.notCheckedInThisProcess)
        let initialStatus = passiveStatuses.last ?? fallback
        let resolvedRefreshPlan = refreshPlan ?? .success(initialStatus)
        self.passiveStatuses = passiveStatuses
        lastPassiveStatus = initialStatus
        self.refreshPlan = resolvedRefreshPlan
        self.savePlan = savePlan
        self.removePlan = removePlan
        shouldSuspendSave = suspendSave
    }

    nonisolated func makeClient() -> IOSOpenAICredentialSettingsClient {
        IOSOpenAICredentialSettingsClient(
            passiveStatus: { await self.readPassiveStatus() },
            refresh: { try await self.performRefresh() },
            saveOrReplace: { try await self.performSave($0) },
            remove: { try await self.performRemove() },
            statusUpdates: { await self.makeStatusUpdates() }
        )
    }

    func calls() -> CredentialSettingsClientCalls { recordedCalls }
    func savedCandidates() -> [String] { candidates }

    func publishStatus(_ status: IOSOpenAICredentialStatus) {
        statusRevision &+= 1
        lastPassiveStatus = status
        let update = IOSOpenAICredentialStatusUpdate(
            revision: statusRevision,
            status: status
        )
        for continuation in statusUpdateContinuations {
            continuation.yield(update)
        }
    }

    func resumeSave() {
        shouldSuspendSave = false
        saveContinuation?.resume()
        saveContinuation = nil
    }

    func setRefreshPlan(_ plan: RefreshPlan) {
        refreshPlan = plan
    }

    private func readPassiveStatus()
        -> IOSOpenAICredentialStatusUpdate {
        recordedCalls.passiveStatus += 1
        if !passiveStatuses.isEmpty {
            lastPassiveStatus = passiveStatuses.removeFirst()
        }
        return IOSOpenAICredentialStatusUpdate(
            revision: statusRevision,
            status: lastPassiveStatus
        )
    }

    private func makeStatusUpdates()
        -> AsyncStream<IOSOpenAICredentialStatusUpdate> {
        recordedCalls.statusUpdates += 1
        let (stream, continuation) = AsyncStream.makeStream(
            of: IOSOpenAICredentialStatusUpdate.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        statusUpdateContinuations.append(continuation)
        continuation.yield(
            IOSOpenAICredentialStatusUpdate(
                revision: statusRevision,
                status: lastPassiveStatus
            )
        )
        return stream
    }

    private func performRefresh()
        throws -> IOSOpenAICredentialStatusUpdate {
        recordedCalls.refresh += 1
        switch refreshPlan {
        case .success(let status):
            statusRevision &+= 1
            lastPassiveStatus = status
            return IOSOpenAICredentialStatusUpdate(
                revision: statusRevision,
                status: status
            )
        case .coordinatorFailure(let error):
            throw error
        case .secretFailure(let sentinel):
            throw CredentialSettingsSecretFixtureError(sentinel: sentinel)
        }
    }

    private func performSave(
        _ candidate: String
    ) async throws -> IOSOpenAICredentialMutationOutcome {
        recordedCalls.saveOrReplace += 1
        candidates.append(candidate)
        if shouldSuspendSave {
            await withCheckedContinuation { continuation in
                saveContinuation = continuation
            }
        }
        return try mutationOutcome(from: savePlan)
    }

    private func performRemove()
        throws -> IOSOpenAICredentialMutationOutcome {
        recordedCalls.remove += 1
        return try mutationOutcome(from: removePlan)
    }

    private func mutationOutcome(
        from plan: MutationPlan
    ) throws -> IOSOpenAICredentialMutationOutcome {
        switch plan {
        case .success(let outcome):
            return outcome
        case .coordinatorFailure(let error):
            throw error
        case .secretFailure(let sentinel):
            throw CredentialSettingsSecretFixtureError(sentinel: sentinel)
        }
    }
}

private struct CredentialSettingsSecretFixtureError:
    Error,
    CustomStringConvertible,
    Sendable
{
    let sentinel: String
    var description: String { "Credential fixture failed: \(sentinel)" }
}

private func credentialStatus(
    _ primary: IOSOpenAICredentialPrimaryStatus,
    statusNeedsRefresh: Bool = false,
    localMarkerIssue: IOSOpenAICredentialLocalMarkerIssue? = nil
) -> IOSOpenAICredentialStatus {
    IOSOpenAICredentialStatus(
        primary: primary,
        statusNeedsRefresh: statusNeedsRefresh,
        localMarkerIssue: localMarkerIssue
    )
}

@MainActor
private func eventually(
    _ predicate: @escaping @MainActor () async -> Bool
) async throws {
    for _ in 0..<200 {
        if await predicate() { return }
        await Task.yield()
    }
    throw CredentialSettingsTestTimeout()
}

private struct CredentialSettingsTestTimeout: Error {}
