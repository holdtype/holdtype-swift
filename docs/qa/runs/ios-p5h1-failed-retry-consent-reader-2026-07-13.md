# iOS P5H-1 Failed-Retry Consent And Reader QA

Date: 2026-07-13
Milestone: P5H-1 hidden failed-History Retry safety migration

## Decision

P5H-1 is complete in commits `c6b6eb9`, `1d6bf10`, and `aa97cdf`.

New failed-History Retry work reads protected audio through the neutral bounded
reader instead of materializing a new scratch URL. Transcription, optional
Correction, and Translation run through the same composition-owned provider-
consent stage executor as foreground Voice. Missing, stale, withdrawn, or lost
authorization cannot publish a provider result; required-stage authorization
loss preserves the failed row and routes the user to Privacy & Permissions.

This is a hidden safety checkpoint. Production provider disclosure remains
version `1`; Voice and Privacy copy, the History placeholder, Storage &
Recovery controls, and public failed-row Retry availability are unchanged. No
accepted or failed foreground History ownership is activated. The legacy
scratch scavenger remains only to remove artifacts created by older builds; new
Retry work creates no such scratch artifact.

## Commit Evidence

- `c6b6eb9` — migrated failed-History Retry to the neutral audio reader and
  covered exact metadata, bounded reads, invalid metadata, service injection,
  public error mapping, and absence of a new source copy.
- `1d6bf10` — made required-stage authorization loss a distinct durable runtime
  outcome that preserves prior failure ownership and returns the Privacy &
  Permissions setup route.
- `aa97cdf` — composed failed-History Retry with the exact process-owned consent
  coordinator and gated Transcription, Correction, and Translation launch and
  one-shot result consumption.

## Automated Evidence

- Full serialized strict Persistence regression
  - Result: 1,101 tests in 57 suites passed with complete strict concurrency and
    warnings as errors.
  - Log: `/tmp/p5h1-persistence-serialized-strict.log`.
- Full serialized strict iOS Core regression
  - Result: 102 tests in 9 suites passed with complete strict concurrency and
    warnings as errors.
  - Log: `/tmp/p5h1-ioscore-serialized-strict.log`.
- Focused neutral-reader regression
  - `IOSOpenAIFailedHistoryRetryProviderTests` passed: 4 tests in 1 suite.
  - It proves exact reader metadata, bounded audio access without a source
    copy, failure before provider/audio work for invalid metadata, injected
    non-network services, and payload-free error mapping.
- Focused Persistence consent-loss regression
  - `pipelineAuthorizationLossPreservesPriorFailureAndReturnsPrivacyRoute` and
    `authorizationLossIsDistinctForRequiredProviderStages` passed: 2 tests in 2
    suites.
  - It proves no failed-row ownership loss and an explicit Privacy &
    Permissions route for required-stage authorization loss.
- Focused iOS warnings-as-errors integration run
  - Result: 10 passed, 0 failed, 0 skipped on iPhone 16 / iOS 18.6 simulator,
    device `71E5A24E-74E4-49EE-BDFB-026C4C15CCCC`.
  - Result bundle: `/tmp/p5h1-consent-focused3-20260713.xcresult`.
  - Covered the exact containing-app composition and failed-History service
    integration, including missing consent before reservation/credential work,
    cancellation after dispatch, withdrawal versus late result, and passive
    failure composition.

## Safety And Privacy

All verification used local package tests, fakes, and the iOS simulator. It did
not request microphone permission, activate or record from a live audio
session, access a live Keychain item, use a real API key, or contact OpenAI.
Provider text, prompts, credentials, audio bytes, repository paths, and consent
capabilities remain outside durable failed rows, ordinary logs, App Group, and
the keyboard extension.

## Assessment

P5H-1 closes the hidden failed-Retry reader and consent prerequisite only. It
does not qualify a History release. P5H-2 and P5H-3 must remain behind
production disclosure version `1` and app-only foreground ownership; P5H-4
must land native History plus Storage & Recovery controls before the same
atomic checkpoint selects captured mode, activates disclosure version `2`, and
publishes its matching copy.
