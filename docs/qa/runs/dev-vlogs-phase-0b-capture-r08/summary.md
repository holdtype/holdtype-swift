# Dev Vlogs Phase 0B Continuity Capture R08

Packet: `DV-P0B-CAPTURE-R08`

Result: **fail** (`invalid_configuration`, stage
`event_log_path_mismatch`).

## Scope and authority

This was one discover/evidence-only, no-retry Continuity Camera cell under
`DV-DRAFT-4@2f3266a` and Phase 0B `E02/E04/E06/E07/E08`. Runtime authority was
`f3ae739`; native-source owners were accepted through W02 `f7ff6bf`, lifecycle
through `f141be6`, diagnostic handoff through W07-R3 `a90f888`, and typed
pre-attempt configuration diagnosis through W08 `d1f5f5f` with accepted
summary/review `b418c08`. E07 evidence `719e995` remains deterministic and
fake-backed only; this runtime makes no shipping audio-lease claim.

No product, source, project, specification, registry, permission, UI,
external-storage, provider, Keychain, or TCC change was authorized or made. No
`requestAccess`, permission mode, System Settings action, fallback, or retry
occurred.

## Runtime result

- Fresh bounded bundled AVFoundation enumeration reported exactly one
  connected, non-suspended, not-in-use Continuity Camera. Its explicit stable
  identity was selected ephemerally and is not retained.
- The accepted hardware command was invoked exactly once for the planned
  10-second cell with permission, test-hook, and provider variables absent.
- The app emitted one closed operator terminal:
  `failed category=invalid_configuration`. W08 published and the accepted
  one-shot consumer consumed exactly one validated configuration diagnostic at
  `event_log_path_mismatch`.
- The failure occurred before an app attempt-start event. Camera authorization
  inspection, the single dictation-audio owner, camera configuration, capture,
  probes, passthrough finalization, and preservation were not reached. No
  Camera authorization result is inferred from the user's prior setting.
- No microphone or camera-session audio input started, no media or Ready clip
  was created, and every realized media or quantitative field remains
  unavailable/evidence-only.

This is a functional fail and a `debug-spike defect`. The retained diagnostic
identifies the failed configuration dimension but does not establish why the
resolved event-log path mismatched. No device, signing, TCC, app resolver, or
filesystem cause is attributed.

## Cleanup

The app and script exited within the accepted bound. The accepted script
removed its exact raw root; the validated consumer removed its exact diagnostic
snapshot and handoff root. No run-owned HoldType, script, enumerator, helper,
media, raw root, or handoff root remained. The private enumeration/orchestration
root was removed after the redacted facts were retained. One unrelated
pre-existing Phase 0B temporary root and all unrelated processes were
preserved.

Recording Cache, ActiveRecordings, TranscriptionRecovery, the broad HoldType
application-support file count, and the default Dev Vlogs destination matched
their pre-run counts. No external or remote storage was used. The single
scoped idle guard remained live through runtime, handoff consumption, evidence
collection, validation, and raw cleanup, then was stopped and its exit
verified.

## Deviations

The packet used the repository's accepted script spelling
`dev_vlogs_phase_0b_spike.sh`; the packet text's underscored `phase_0_b`
spelling does not exist. The first bounded enumerator launch command referenced
a nonexistent timeout location and exited before starting the enumerator; the
correct discovered timeout executable was then used for the sole enumeration.
Neither correction invoked hardware mode or consumed a capture attempt.

No material runtime deviation occurred. The one hardware invocation and one
diagnostic consumption were not retried.

## Residual

Primary residual class: `debug-spike defect`. The one hardware route stopped
at pre-attempt configuration stage `event_log_path_mismatch`. Authorization,
capture, media, passthrough, preservation, and quantitative facts remain
unavailable. No deeper causal attribution and no retry are authorized by this
packet.

Next dependency: `DV-P0B-CAPTURE-R08-REVIEW`.
