import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSForegroundVoiceWorkflowTests {
    @Test
    func sharedControllerCarriesExactSceneLeaseAndFinishAuthority() async throws {
        let fixture = try await WorkflowFixture(
            permission: .granted,
            acquireLease: false
        )
        let controller = IOSForegroundVoiceController(
            client: fixture.workflow.client,
            sceneRegistry: fixture.registry
        )
        await controller.activate()
        let start = try #require(
            controller.actionCommands.first {
                $0.action == .startStandard
            }
        )

        #expect(controller.submit(start) == .unavailable)
        #expect(controller.submit(start, from: fixture.facade) == .accepted)
        try await waitUntil { controller.presentation.phase == .listening }
        let finish = try #require(
            controller.actionCommands.first {
                $0.action == .finishUtterance
            }
        )
        #expect(controller.submit(finish) == .accepted)
        try await waitUntil { controller.presentation.phase == .inactive }

        #expect(controller.presentation.failure == .tooShort)
        #expect(fixture.stopReasons == [.done])
        #expect(fixture.facade.promptPresentation == .available)
    }

    @Test
    func startRunsFrozenPreflightOrderAndDoneReachesExactRecorder() async throws {
        let fixture = try await WorkflowFixture(permission: .undetermined)
        let token = IOSForegroundVoiceWorkflowAttemptToken()
        let task = Task { @MainActor in
            await fixture.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: fixture.lease
                ),
                token: token,
                progress: { progress in
                    fixture.events.record("progress-\(progress)")
                }
            )
        }

        try await waitUntil {
            fixture.events.contains("recording-start")
        }
        #expect(fixture.workflow.finishUtterance(token) == .accepted)
        let resolution = await task.value

        #expect(resolution.failure == .tooShort)
        #expect(fixture.stopReasons == [.done])
        #expect(fixture.audioWasDeactivated)
        #expect(fixture.finalizationFinishCount == 1)
        #expect(fixture.permissionRequestCount == 1)
        #expect(fixture.registry.snapshot.isForegroundActive)
        #expect(fixture.facade.promptPresentation == .available)

        let values = fixture.events.values
        assertOrdered(
            [
                "capture-reconcile",
                "lifecycle-recover",
                "pending-load",
                "latest-load",
                "settings-load",
                "library-load",
                "consent-observe",
                "consent-continue",
                "credential-resolve",
                "permission-request",
                "history-stop",
                "audio-activate",
                "start-boundary",
                "input-freeze",
                "recording-make",
                "recording-start",
                "recording-stop-done",
                "finalization-finish",
                "audio-deactivate",
            ],
            in: values
        )
        #expect(!values.contains("provider-process"))
    }

    @Test
    func invalidTranslationStopsAfterSettingsAndLibrary() async throws {
        let fixture = try await WorkflowFixture(
            settings: .defaults,
            permission: .granted
        )
        let resolution = await fixture.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .translate,
                sceneLease: fixture.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )

        #expect(resolution.observation.setup == .needsSetup(.translation))
        let values = fixture.events.values
        #expect(values.contains("settings-load"))
        #expect(values.contains("library-load"))
        #expect(!values.contains("consent-observe"))
        #expect(!values.contains("credential-resolve"))
        #expect(!values.contains("permission-read"))
        #expect(!values.contains("audio-activate"))
        #expect(!values.contains("recording-make"))
    }

    @Test
    func lastActiveSceneLossInterruptsCaptureAndNeverProcesses() async throws {
        let fixture = try await WorkflowFixture(permission: .granted)
        let token = IOSForegroundVoiceWorkflowAttemptToken()
        let task = Task { @MainActor in
            await fixture.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: fixture.lease
                ),
                token: token,
                progress: { _ in }
            )
        }

        try await waitUntil {
            fixture.events.contains("recording-start")
        }
        #expect(fixture.facade.updateActivity(.inactive) == .accepted)
        let resolution = await task.value

        #expect(resolution.outcome == .interrupted)
        #expect(fixture.stopReasons == [.interrupted])
        #expect(fixture.audioWasDeactivated)
        #expect(!fixture.events.contains("provider-process"))
        #expect(fixture.workflow.finishUtterance(token) == .unavailable)
    }

    @Test
    func providerFreeObservationProjectsDiscardOnlyCaptureRecovery() async throws {
        let fixture = try await WorkflowFixture(permission: .granted)
        let capture = try await fixture.persistenceOwner.createCapture(
            attemptID: UUID(),
            outputIntent: .standard
        )
        capture.release()

        let observation = await fixture.workflow.client.observe()

        #expect(observation.recovery == .captureDiscardOnly)
        #expect(!fixture.events.contains("credential-resolve"))
        #expect(!fixture.events.contains("permission-read"))
        #expect(!fixture.events.contains("provider-process"))
    }

    @Test
    func durableRecoveryBlocksSettingsLibraryAndProviderPreflight() async throws {
        let fixture = try await WorkflowFixture(permission: .granted)
        let capture = try await fixture.persistenceOwner.createCapture(
            attemptID: UUID(),
            outputIntent: .standard
        )
        capture.release()

        let resolution = await fixture.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: fixture.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )

        #expect(resolution.observation.recovery == .captureDiscardOnly)
        #expect(!fixture.events.contains("settings-load"))
        #expect(!fixture.events.contains("library-load"))
        #expect(!fixture.events.contains("consent-observe"))
        #expect(!fixture.events.contains("credential-resolve"))
    }

    @Test
    func settingsFailureBlocksLibraryAndEveryLaterBoundary() async throws {
        let fixture = try await WorkflowFixture(
            settingsLoads: [.failure],
            permission: .granted
        )

        _ = await fixture.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: fixture.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )

        #expect(fixture.events.contains("settings-load"))
        #expect(!fixture.events.contains("library-load"))
        #expect(!fixture.events.contains("consent-observe"))
        #expect(!fixture.events.contains("permission-read"))
        #expect(!fixture.events.contains("audio-activate"))
    }

    @Test
    func invalidStandardConfigurationBlocksBeforeConsent() async throws {
        var settings = IOSAppSettings.defaults
        settings.transcriptionConfiguration = TranscriptionConfiguration(
            language: .custom,
            customLanguageCode: "invalid!"
        )
        let fixture = try await WorkflowFixture(
            settings: settings,
            permission: .granted
        )

        let resolution = await fixture.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: fixture.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )

        #expect(resolution.observation.setup == .needsSetup(.transcription))
        #expect(fixture.events.contains("library-load"))
        #expect(!fixture.events.contains("consent-observe"))
    }

    @Test
    func consentDeclineAndStaleAcceptanceNeverReachCredential() async throws {
        let declined = try await WorkflowFixture(
            permission: .granted,
            consentContinuationAllowed: false
        )
        _ = await declined.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: declined.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(declined.events.contains("consent-continue"))
        #expect(!declined.events.contains("credential-resolve"))

        let stale = try await WorkflowFixture(
            permission: .granted,
            consentRevalidation: [false]
        )
        _ = await stale.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: stale.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(stale.events.contains("consent-revalidate"))
        #expect(!stale.events.contains("credential-resolve"))
    }

    @Test
    func missingAndStaleCredentialsBlockPermissionAndHistory() async throws {
        let missing = try await WorkflowFixture(
            permission: .granted,
            credentialAvailable: false
        )
        let missingResolution = await missing.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: missing.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(missingResolution.observation.setup == .needsSetup(.openAI))
        #expect(!missing.events.contains("permission-read"))

        let stale = try await WorkflowFixture(
            permission: .granted,
            credentialRevalidation: [false]
        )
        _ = await stale.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: stale.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(stale.events.contains("permission-read"))
        #expect(!stale.events.contains("history-stop"))
        #expect(!stale.events.contains("audio-activate"))
    }

    @Test
    func deniedAndTimedOutPermissionNeverReachHistoryOrAudio() async throws {
        let denied = try await WorkflowFixture(permission: .denied)
        _ = await denied.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: denied.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(!denied.events.contains("permission-request"))
        #expect(!denied.events.contains("history-stop"))

        let timedOut = try await WorkflowFixture(
            permission: .undetermined,
            permissionOutcome: .timedOut
        )
        _ = await timedOut.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: timedOut.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(timedOut.permissionRequestCount == 1)
        #expect(!timedOut.events.contains("history-stop"))
        #expect(!timedOut.events.contains("audio-activate"))
    }

    @Test
    func historyCueSceneAndRecorderShortCircuitsStayFailClosed() async throws {
        let history = try await WorkflowFixture(
            permission: .granted,
            historyStops: false
        )
        _ = await history.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: history.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(!history.events.contains("audio-activate"))

        let cue = try await WorkflowFixture(
            permission: .granted,
            startBoundarySucceeds: false
        )
        _ = await cue.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: cue.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(cue.events.contains("audio-deactivate"))
        #expect(!cue.events.contains("recording-make"))

        let scene = try await WorkflowFixture(
            permission: .granted,
            deactivateSceneAtStartBoundary: true
        )
        _ = await scene.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: scene.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(scene.events.contains("start-boundary-cancel"))
        #expect(!scene.events.contains("recording-make"))

        let recorder = try await WorkflowFixture(
            permission: .granted,
            recordingIsActive: false
        )
        _ = await recorder.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: recorder.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(recorder.events.contains("recording-start"))
        #expect(recorder.stopReasons == [.cancelled])
        #expect(!recorder.events.contains("provider-process"))
    }

    @Test
    func postPermissionSettingsAndConsentRevalidationBlockHistory() async throws {
        var changed = IOSAppSettings.defaults
        changed.localTextCleanupEnabled = false
        let settings = try await WorkflowFixture(
            settingsLoads: [
                .value(.defaults),
                .value(.defaults),
                .value(.defaults),
                .value(changed),
            ],
            permission: .granted
        )
        _ = await settings.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: settings.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(!settings.events.contains("history-stop"))

        let consent = try await WorkflowFixture(
            permission: .granted,
            consentRevalidation: [true, false]
        )
        _ = await consent.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: consent.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(!consent.events.contains("history-stop"))
    }

    @Test
    func postCueLibraryCredentialAndSceneRevalidationBlockRecorder() async throws {
        var changedLibrary = IOSLibraryContent.defaults
        changedLibrary.replacementRules = [
            TextReplacementRule(search: "alpha", replacement: "beta")
        ]
        let library = try await WorkflowFixture(
            libraryLoads: [
                .value(.defaults), .value(.defaults), .value(.defaults),
                .value(.defaults), .value(.defaults),
                .value(changedLibrary),
            ],
            permission: .granted
        )
        _ = await library.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: library.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(library.events.contains("start-boundary"))
        #expect(!library.events.contains("recording-make"))

        let credential = try await WorkflowFixture(
            permission: .granted,
            credentialRevalidation: [true, false]
        )
        _ = await credential.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: credential.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(credential.events.contains("start-boundary"))
        #expect(!credential.events.contains("recording-make"))

        let scene = try await WorkflowFixture(
            permission: .granted,
            deactivateSceneAtStartBoundary: true
        )
        _ = await scene.workflow.start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: .standard,
                sceneLease: scene.lease
            ),
            token: IOSForegroundVoiceWorkflowAttemptToken(),
            progress: { _ in }
        )
        #expect(!scene.events.contains("recording-make"))
    }

    @Test
    func tailIsPreemptedByInterruptionAndMaximumDuration() async throws {
        var settings = IOSAppSettings.defaults
        settings.voiceSessionPreferences.recordingStopTailDuration = .seconds2

        let interrupted = try await WorkflowFixture(
            settings: settings,
            permission: .granted
        )
        let interruptedToken = IOSForegroundVoiceWorkflowAttemptToken()
        let interruptedTask = Task { @MainActor in
            await interrupted.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: interrupted.lease
                ),
                token: interruptedToken,
                progress: { _ in }
            )
        }
        try await waitUntil {
            interrupted.events.contains("recording-start")
        }
        #expect(
            interrupted.workflow.finishUtterance(interruptedToken)
                == .accepted
        )
        await Task.yield()
        _ = interrupted.facade.updateActivity(.inactive)
        _ = await interruptedTask.value
        #expect(interrupted.stopReasons == [.interrupted])

        let maximum = try await WorkflowFixture(
            settings: settings,
            permission: .granted
        )
        let maximumToken = IOSForegroundVoiceWorkflowAttemptToken()
        let maximumTask = Task { @MainActor in
            await maximum.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: maximum.lease
                ),
                token: maximumToken,
                progress: { _ in }
            )
        }
        try await waitUntil { maximum.events.contains("recording-start") }
        #expect(maximum.workflow.finishUtterance(maximumToken) == .accepted)
        await Task.yield()
        maximum.emitTerminal(.maximumDuration)
        _ = await maximumTask.value
        #expect(maximum.stopReasons == [.maximumDuration])
    }

    @Test
    func controllerCancelPreemptsConfiguredTail() async throws {
        var settings = IOSAppSettings.defaults
        settings.voiceSessionPreferences.recordingStopTailDuration = .seconds2
        let fixture = try await WorkflowFixture(
            settings: settings,
            permission: .granted,
            acquireLease: false
        )
        let controller = IOSForegroundVoiceController(
            client: fixture.workflow.client,
            sceneRegistry: fixture.registry
        )
        await controller.activate()
        let start = try #require(controller.actionCommands.first {
            $0.action == .startStandard
        })
        #expect(controller.submit(start, from: fixture.facade) == .accepted)
        try await waitUntil { controller.presentation.phase == .listening }
        let finish = try #require(controller.actionCommands.first {
            $0.action == .finishUtterance
        })
        #expect(controller.submit(finish) == .accepted)
        let cancel = try #require(controller.actionCommands.first {
            $0.action == .cancelUtterance
        })
        #expect(controller.submit(cancel) == .accepted)
        try await waitUntil { controller.presentation.phase == .inactive }
        #expect(fixture.stopReasons == [.cancelled])
    }

    @Test
    func finalizationExpirationAndStopCueOrderingNeverDispatchEarly() async throws {
        let expired = try await WorkflowFixture(
            permission: .granted,
            completedCapture: true,
            expireFinalizationImmediately: true,
            preacceptConsent: true
        )
        let expiredToken = IOSForegroundVoiceWorkflowAttemptToken()
        let expiredTask = Task { @MainActor in
            await expired.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: expired.lease
                ),
                token: expiredToken,
                progress: { _ in }
            )
        }
        try await waitUntil { expired.events.contains("recording-start") }
        #expect(expired.workflow.finishUtterance(expiredToken) == .accepted)
        _ = await expiredTask.value
        #expect(!expired.events.contains("pending-prepare"))
        #expect(!expired.events.contains("provider-process"))

        let ordered = try await WorkflowFixture(
            permission: .granted,
            completedCapture: true,
            preacceptConsent: true
        )
        let orderedToken = IOSForegroundVoiceWorkflowAttemptToken()
        let orderedTask = Task { @MainActor in
            await ordered.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: ordered.lease
                ),
                token: orderedToken,
                progress: { _ in }
            )
        }
        try await waitUntil { ordered.events.contains("recording-start") }
        #expect(ordered.workflow.finishUtterance(orderedToken) == .accepted)
        _ = await orderedTask.value
        assertOrdered(
            [
                "recording-stop-done",
                "stop-boundary",
                "audio-deactivate",
                "pending-prepare",
                "provider-process",
            ],
            in: ordered.events.values
        )
    }

    @Test
    func aggregateLossCancelsInitialAndRetryProcessorWork() async throws {
        let initial = try await WorkflowFixture(
            permission: .granted,
            completedCapture: true,
            processorSuspendsUntilCancelled: true,
            preacceptConsent: true
        )
        let initialToken = IOSForegroundVoiceWorkflowAttemptToken()
        let initialTask = Task { @MainActor in
            await initial.workflow.start(
                IOSForegroundVoiceWorkflowStartRequest(
                    outputIntent: .standard,
                    sceneLease: initial.lease
                ),
                token: initialToken,
                progress: { _ in }
            )
        }
        try await waitUntil { initial.events.contains("recording-start") }
        #expect(initial.workflow.finishUtterance(initialToken) == .accepted)
        try await waitUntil { initial.events.contains("provider-process") }
        _ = initial.facade.updateActivity(.inactive)
        let initialResolution = await initialTask.value
        #expect(initialResolution.observation.recovery == .pendingRetryOrDiscard)

        let retry = try await WorkflowFixture(
            permission: .granted,
            processorSuspendsUntilCancelled: true,
            preacceptConsent: true
        )
        _ = try await retry.seedPending()
        let controller = IOSForegroundVoiceController(
            client: retry.workflow.client,
            sceneRegistry: retry.registry
        )
        await controller.activate()
        let retryCommand = try #require(controller.actionCommands.first {
            $0.action == .retryPending
        })
        #expect(controller.submit(retryCommand) == .accepted)
        try await waitUntil { retry.events.contains("provider-process") }
        _ = retry.facade.updateActivity(.inactive)
        try await waitUntil { controller.presentation.phase == .inactive }
        #expect(controller.presentation.recovery == .pendingRetryOrDiscard)
        #expect(controller.presentation.outcome == .recoverableFailure)
    }

    @Test
    func pendingDiscardAndRetryMappingRemainProviderFreeUntilExplicitRetry()
        async throws {
        let fixture = try await WorkflowFixture(
            permission: .granted,
            preacceptConsent: true
        )
        _ = try await fixture.seedPending()
        let controller = IOSForegroundVoiceController(
            client: fixture.workflow.client,
            sceneRegistry: fixture.registry
        )
        await controller.activate()
        #expect(controller.presentation.recovery == .pendingRetryOrDiscard)
        #expect(!fixture.events.contains("provider-process"))

        let discard = try #require(controller.actionCommands.first {
            $0.action == .discard
        })
        #expect(controller.submit(discard) == .accepted)
        try await waitUntil { fixture.events.contains("pending-discard") }
        try await waitUntil { controller.presentation.recovery == .none }
        #expect(!fixture.events.contains("provider-process"))
    }

    @Test
    func localCheckpointAndSavingResultExposeOnlyMatchingRetry() async throws {
        let local = try await WorkflowFixture(
            permission: .granted,
            completedCapture: true,
            processorResolution: .localRecoveryPending(
                failure: .localPersistence,
                stage: .postProcessing,
                disposition: .processingCheckpoint
            ),
            localRetryResolution: .localRecoveryPending(
                failure: .localPersistence,
                stage: .postProcessing,
                disposition: .processingCheckpoint
            ),
            preacceptConsent: true,
            acquireLease: false
        )
        let localController = IOSForegroundVoiceController(
            client: local.workflow.client,
            sceneRegistry: local.registry
        )
        await localController.activate()
        let localStart = try #require(localController.actionCommands.first {
            $0.action == .startStandard
        })
        #expect(
            localController.submit(localStart, from: local.facade) == .accepted
        )
        try await waitUntil {
            localController.presentation.phase == .listening
        }
        let localFinish = try #require(
            localController.actionCommands.first {
                $0.action == .finishUtterance
            }
        )
        #expect(localController.submit(localFinish) == .accepted)
        try await waitUntil {
            localController.presentation.recovery
                == .localCheckpoint(.postProcessing)
        }
        let localRetry = try #require(localController.actionCommands.first {
            $0.action == .retryLocalCheckpoint
        })
        #expect(localController.submit(localRetry) == .accepted)
        try await waitUntil { local.events.contains("local-retry") }

        let savingExpectation = try makeSavingExpectation()
        let saving = try await WorkflowFixture(
            permission: .granted,
            completedCapture: true,
            processorResolution: .acceptance(
                .savingResult(savingExpectation)
            ),
            savingRetryResult: .savingResult(savingExpectation),
            preacceptConsent: true,
            acquireLease: false
        )
        let savingController = IOSForegroundVoiceController(
            client: saving.workflow.client,
            sceneRegistry: saving.registry
        )
        await savingController.activate()
        let savingStart = try #require(savingController.actionCommands.first {
            $0.action == .startStandard
        })
        #expect(
            savingController.submit(savingStart, from: saving.facade)
                == .accepted
        )
        try await waitUntil {
            savingController.presentation.phase == .listening
        }
        let savingFinish = try #require(
            savingController.actionCommands.first {
                $0.action == .finishUtterance
            }
        )
        #expect(savingController.submit(savingFinish) == .accepted)
        try await waitUntil {
            savingController.presentation.recovery == .savingResult
        }
        #expect(savingController.presentation.outcome == nil)
        let savingRetry = try #require(
            savingController.actionCommands.first {
                $0.action == .retrySavingResult
            }
        )
        #expect(savingController.submit(savingRetry) == .accepted)
        try await waitUntil { saving.events.contains("saving-retry") }
    }

    @Test
    func workflowValuesRedactConfigurationAndPrivateAuthorities() async throws {
        let sentinel = "PRIVATE-PROMPT-9f42"
        var settings = IOSAppSettings.defaults
        settings.transcriptionConfiguration.freeformPrompt = sentinel
        let fixture = try await WorkflowFixture(
            settings: settings,
            permission: .granted
        )
        let configuration = IOSForegroundVoiceWorkflowConfiguration(
            settings: settings,
            library: .defaults
        )
        let start = IOSForegroundVoiceWorkflowStartRequest(
            outputIntent: .standard,
            sceneLease: fixture.lease
        )
        let values = [
            String(describing: fixture.workflow),
            String(reflecting: fixture.workflow),
            String(describing: configuration),
            String(reflecting: configuration),
            String(describing: start),
            String(reflecting: start),
            String(describing: IOSForegroundVoiceWorkflowCredentialProof()),
            String(reflecting: IOSForegroundVoiceWorkflowCredentialProof()),
        ]

        #expect(values.allSatisfy { !$0.contains(sentinel) })
        #expect(configuration.customMirror.children.isEmpty)
        #expect(start.customMirror.children.isEmpty)
    }
}

@MainActor
private final class WorkflowFixture {
    let events = WorkflowEventRecorder()
    let registry: IOSVoiceSceneRegistry
    let facade: IOSVoiceSceneFacade
    let lease: IOSVoiceSceneStartLease!
    let root: URL
    let persistenceOwner: IOSForegroundVoicePersistenceOwner
    let historyCoordinator: IOSAcceptedHistoryCoordinator
    let consentCoordinator: IOSProviderConsentCoordinator
    private let pendingBox: WorkflowPendingBox
    private(set) var workflow: IOSForegroundVoiceWorkflow!

    private(set) var stopReasons: [IOSForegroundVoiceWorkflowCaptureStopReason] = []
    private(set) var audioWasDeactivated = false
    private(set) var finalizationFinishCount = 0
    private(set) var permissionRequestCount = 0
    private(set) var terminalHandler: (@MainActor @Sendable (
        IOSForegroundVoiceWorkflowCaptureStopReason
    ) -> Void)?
    private var permission: IOSMicrophonePermissionStatus

    init(
        settings: IOSAppSettings = .defaults,
        settingsLoads: [WorkflowLoad<IOSAppSettings>]? = nil,
        libraryLoads: [WorkflowLoad<IOSLibraryContent>] = [
            .value(.defaults)
        ],
        permission: IOSMicrophonePermissionStatus,
        permissionOutcome:
            IOSForegroundVoiceWorkflowPermissionOutcome? = nil,
        consentContinuationAllowed: Bool = true,
        consentRevalidation: [Bool] = [true],
        credentialAvailable: Bool = true,
        credentialRevalidation: [Bool] = [true],
        historyStops: Bool = true,
        startBoundarySucceeds: Bool = true,
        deactivateSceneAtStartBoundary: Bool = false,
        recordingStarts: Bool = true,
        recordingIsActive: Bool = true,
        completedCapture: Bool = false,
        expireFinalizationImmediately: Bool = false,
        processorSuspendsUntilCancelled: Bool = false,
        processorResolution: IOSForegroundVoiceProcessingResolution? = nil,
        localRetryResolution: IOSForegroundVoiceProcessingResolution =
            .notStarted(.localPersistence),
        savingRetryResult: IOSForegroundVoiceAcceptanceResult? = nil,
        preacceptConsent: Bool = false,
        acquireLease: Bool = true
    ) async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        persistenceOwner = IOSForegroundVoicePersistenceOwner(
            applicationSupportDirectoryURL: root
        )
        historyCoordinator = IOSAcceptedHistoryCoordinator(
            applicationSupportDirectoryURL: root
        )
        var lifecycleDisposition = await historyCoordinator
            .recoverContainingAppLifecycle(.processLaunch)
        for _ in 0..<12
        where lifecycleDisposition == .pendingLocalRecovery {
            lifecycleDisposition = await historyCoordinator
                .recoverContainingAppLifecycle(.processLaunch)
        }
        guard lifecycleDisposition == .complete else {
            throw WorkflowFixtureError.unsupportedTestPath
        }
        consentCoordinator = IOSProviderConsentCoordinator(
            applicationSupportDirectoryURL: root
        )
        registry = IOSVoiceSceneRegistry()
        facade = registry.registerScene(initialActivity: .active)
        if acquireLease {
            guard let lease = facade.acquireStartLease() else {
                throw WorkflowFixtureError.missingSceneLease
            }
            self.lease = lease
        } else {
            lease = nil
        }
        self.permission = permission
        pendingBox = WorkflowPendingBox()
        if preacceptConsent {
            let observation = await consentCoordinator.observe()
            _ = try await consentCoordinator.accept(
                using: observation,
                decisionAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        }

        let settingsSequence = WorkflowLoadSequence(
            settingsLoads ?? [.value(settings)]
        )
        let librarySequence = WorkflowLoadSequence(libraryLoads)
        let consentValidationSequence = WorkflowValueSequence(
            consentRevalidation
        )
        let credentialValidationSequence = WorkflowValueSequence(
            credentialRevalidation
        )

        let events = events
        let owner = persistenceOwner
        let pendingBox = pendingBox
        let consent = consentCoordinator
        let registry = registry
        workflow = IOSForegroundVoiceWorkflow(
            dependencies: IOSForegroundVoiceWorkflowDependencies(
                sceneRegistry: registry,
                reconcileCaptureSources: {
                    events.record("capture-reconcile")
                    return await owner.reconcileCaptureSourcesAtLaunch()
                },
                recoverContainingAppLifecycle: {
                    events.record("lifecycle-recover")
                    return true
                },
                loadPending: {
                    events.record("pending-load")
                    if let pending = pendingBox.load() {
                        return IOSPendingRecordingObservation(
                            recording: pending,
                            availability: .available
                        )
                    }
                    return try await owner.load()
                },
                loadLatest: {
                    events.record("latest-load")
                    return try await owner.loadLatestResult()
                },
                loadSettings: {
                    events.record("settings-load")
                    return try settingsSequence.next()
                },
                loadLibrary: {
                    events.record("library-load")
                    return try librarySequence.next()
                },
                observeConsent: {
                    events.record("consent-observe")
                    return await consent.observe()
                },
                continueConsent: { _, observation in
                    events.record("consent-continue")
                    guard consentContinuationAllowed else { return nil }
                    return try? await consent.accept(
                        using: observation,
                        decisionAt: Date(timeIntervalSince1970: 1_800_000_000)
                    )
                },
                revalidateConsent: { observation in
                    events.record("consent-revalidate")
                    return consentValidationSequence.next()
                        && consent.makeAuthorization(
                        from: observation
                    ) != nil
                },
                resolveCredential: {
                    events.record("credential-resolve")
                    return credentialAvailable
                        ? .available(
                            IOSForegroundVoiceWorkflowCredentialProof()
                        )
                        : .needsSetup
                },
                revalidateCredential: { _ in
                    events.record("credential-revalidate")
                    return credentialValidationSequence.next()
                },
                permission: IOSForegroundVoiceWorkflowPermissionClient(
                    read: { [weak self] in
                        events.record("permission-read")
                        return self?.permission ?? .unavailable
                    },
                    requestIfUndetermined: { [weak self] in
                        events.record("permission-request")
                        guard let self else { return .unavailable }
                        permissionRequestCount += 1
                        _ = facade.updateActivity(.inactive)
                        let outcome = permissionOutcome ?? .granted
                        if outcome == .granted {
                            self.permission = .granted
                        }
                        _ = facade.updateActivity(.active)
                        return outcome
                    }
                ),
                stopHistoryPlayback: {
                    events.record("history-stop")
                    return historyStops
                },
                activateAudio: { [weak self] in
                    events.record("audio-activate")
                    return IOSForegroundVoiceWorkflowAudioLease(
                        freezeAndValidate: {
                            events.record("input-freeze")
                        },
                        observe: { _ in
                            IOSForegroundVoiceWorkflowObservation(cancel: {})
                        },
                        deactivate: {
                            events.record("audio-deactivate")
                            self?.audioWasDeactivated = true
                        }
                    )
                },
                playStartBoundary: { [weak self] _ in
                    events.record("start-boundary")
                    if deactivateSceneAtStartBoundary {
                        _ = self?.facade.updateActivity(.inactive)
                    }
                    return startBoundarySucceeds
                },
                cancelStartBoundary: {
                    events.record("start-boundary-cancel")
                },
                playStopBoundary: { _ in
                    events.record("stop-boundary")
                },
                makeRecording: { [weak self] _, _ in
                    events.record("recording-make")
                    return IOSForegroundVoiceWorkflowRecording(
                        start: {
                            events.record("recording-start")
                            return recordingStarts
                        },
                        stop: { reason in
                            let name = switch reason {
                            case .done: "done"
                            case .cancelled: "cancelled"
                            case .interrupted: "interrupted"
                            case .maximumDuration: "maximum"
                            }
                            events.record("recording-stop-\(name)")
                            self?.stopReasons.append(reason)
                            guard completedCapture else {
                                return .discarded(.tooShort)
                            }
                            return .completed(
                                IOSForegroundVoiceWorkflowCaptureHandoff(
                                    prepare: { configuration in
                                        events.record("pending-prepare")
                                        let pending = try makePendingRecording(
                                            outputIntent: .standard,
                                            phase: .readyForTranscription,
                                            configuration: configuration
                                        )
                                        pendingBox.store(pending)
                                        return pending
                                    },
                                    release: {
                                        events.record("capture-release")
                                    }
                                )
                            )
                        },
                        isActive: { recordingIsActive },
                        observeTerminal: { [weak self] handler in
                            self?.terminalHandler = handler
                            return IOSForegroundVoiceWorkflowObservation(
                                cancel: {}
                            )
                        }
                    )
                },
                beginFinalization: { [weak self] expiration in
                    events.record("finalization-begin")
                    if expireFinalizationImmediately {
                        // Expiration is delivered synchronously to exercise
                        // the pre-close latch and no-provider guarantee.
                        // The real bridge may deliver at any later point.
                        expiration()
                    }
                    return IOSForegroundVoiceWorkflowFinalizationLease {
                        events.record("finalization-finish")
                        self?.finalizationFinishCount += 1
                    }
                },
                process: { _, _ in
                    events.record("provider-process")
                    if processorSuspendsUntilCancelled {
                        do {
                            try await Task.sleep(for: .seconds(3_600))
                        } catch {
                            return .notStarted(.cancelled)
                        }
                    }
                    return processorResolution
                        ?? .notStarted(.providerUnavailable)
                },
                retryLocalRecovery: { _ in
                    events.record("local-retry")
                    return localRetryResolution
                },
                recoverCapture: { capability, configuration in
                    events.record("capture-recover")
                    return try await owner.recoverCapture(
                        capability,
                        transcriptionConfiguration: configuration
                    )
                },
                discardCapture: { capability in
                    events.record("capture-discard")
                    try await owner.discardCapture(capability)
                },
                discardPending: { expectation in
                    events.record("pending-discard")
                    if pendingBox.remove(matching: expectation) {
                        return .discarded
                    }
                    return try await owner.discard(expected: expectation)
                },
                retrySavingResult: { _ in
                    events.record("saving-retry")
                    guard let savingRetryResult else {
                        throw WorkflowFixtureError.unsupportedTestPath
                    }
                    return savingRetryResult
                },
                sleep: { duration in
                    try await Task.sleep(for: duration)
                },
                makeUUID: { UUID() }
            )
        )
    }

    func emitTerminal(
        _ reason: IOSForegroundVoiceWorkflowCaptureStopReason
    ) {
        terminalHandler?(reason)
    }

    func seedPending(
        outputIntent: DictationOutputIntent = .standard
    ) async throws -> IOSPendingRecording {
        let pending = try makePendingRecording(
            outputIntent: outputIntent,
            phase: .awaitingRecovery,
            configuration: .defaults
        )
        pendingBox.store(pending)
        return pending
    }
}

private enum WorkflowLoad<Value: Sendable>: Sendable {
    case value(Value)
    case failure
}

private final class WorkflowLoadSequence<Value: Sendable>:
    @unchecked Sendable {
    private let lock = NSLock()
    private let values: [WorkflowLoad<Value>]
    private var index = 0

    init(_ values: [WorkflowLoad<Value>]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func next() throws -> Value {
        try lock.withLock {
            let value = values[min(index, values.count - 1)]
            index += 1
            switch value {
            case .value(let result):
                return result
            case .failure:
                throw WorkflowFixtureError.configuredFailure
            }
        }
    }
}

private final class WorkflowValueSequence<Value: Sendable>:
    @unchecked Sendable {
    private let lock = NSLock()
    private let values: [Value]
    private var index = 0

    init(_ values: [Value]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func next() -> Value {
        lock.withLock {
            let value = values[min(index, values.count - 1)]
            index += 1
            return value
        }
    }
}

private final class WorkflowPendingBox: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: IOSPendingRecording?

    func load() -> IOSPendingRecording? {
        lock.withLock { pending }
    }

    func store(_ pending: IOSPendingRecording) {
        lock.withLock { self.pending = pending }
    }

    func remove(
        matching expectation: IOSPendingRecordingCASExpectation
    ) -> Bool {
        lock.withLock {
            guard let pending,
                  IOSPendingRecordingCASExpectation(recording: pending)
                    == expectation else {
                return false
            }
            self.pending = nil
            return true
        }
    }
}

private func makePendingRecording(
    outputIntent: DictationOutputIntent,
    phase: IOSPendingRecordingPhase,
    configuration: TranscriptionConfiguration
) throws -> IOSPendingRecording {
    let attemptID = UUID()
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
    return try IOSPendingRecording(
        attemptID: attemptID,
        audioRelativeIdentifier:
            IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                for: attemptID,
                format: .m4a
            ),
        createdAt: createdAt,
        updatedAt: createdAt,
        phase: phase,
        outputIntent: outputIntent,
        transcriptionID: phase.requiresTranscriptionID ? UUID() : nil,
        transcriptionModel: configuration.resolvedModel,
        transcriptionLanguageCode: configuration.resolvedLanguageCode,
        durationMilliseconds: 1_000,
        byteCount: 1_024
    )
}

private func makeSavingExpectation() throws
    -> IOSForegroundVoiceSavingResultExpectation {
    let preparation = try IOSAcceptedOutputDeliveryPreparation(
        deliveryID: UUID(),
        sessionID: UUID(),
        attemptID: UUID(),
        transcriptID: UUID(),
        rawAcceptedText: "accepted",
        outputIntent: .standard,
        automaticInsertionPreferenceEnabled: false,
        keepLatestResult: true,
        historyWrite: nil
    )
    return IOSForegroundVoiceSavingResultExpectation(
        preparation: preparation
    )
}

private final class WorkflowEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.withLock { storage }
    }

    func record(_ value: String) {
        lock.withLock { storage.append(value) }
    }

    func contains(_ value: String) -> Bool {
        lock.withLock { storage.contains(value) }
    }
}

private func assertOrdered(
    _ expected: [String],
    in values: [String]
) {
    var previous = -1
    for value in expected {
        guard let index = values.indices.first(
            where: { $0 > previous && values[$0] == value }
        ) else {
            Issue.record("Missing ordered event: \(value); got: \(values)")
            return
        }
        previous = index
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @escaping @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return }
        await Task.yield()
    }
    throw WorkflowFixtureError.timedOut
}

private enum WorkflowFixtureError: Error {
    case configuredFailure
    case missingSceneLease
    case unsupportedTestPath
    case timedOut
}
