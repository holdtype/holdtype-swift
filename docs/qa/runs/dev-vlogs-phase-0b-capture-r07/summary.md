# Dev Vlogs Phase 0B Continuity Capture R07

Packet: `DV-P0B-CAPTURE-R07`

Result: **fail** (`invalid_configuration`).

## Scope and authority

This was one discover/evidence-only, no-retry Continuity Camera cell under
`DV-DRAFT-4@2f3266a` and Phase 0B `E02/E04/E06/E07/E08`. Runtime authority was
`67349ec`; the native-source owners were accepted through `f7ff6bf`, lifecycle
through `f141be6`, and the diagnostic handoff through W07-R3 `a90f888` and its
independent review. E07 non-regression evidence was reused only from the
accepted deterministic fake lane `719e995`; this runtime makes no shipping
audio-lease claim.

No product, source, project, specification, registry, permission, UI,
external-storage, provider, or Keychain change was authorized or made. No
`requestAccess`, permission mode, System Settings action, TCC operation,
fallback, or retry occurred.

## Runtime result

- Fresh bounded bundled AVFoundation enumeration reported one Continuity
  Camera and exactly one connected, non-suspended eligible Continuity Camera.
  Its exact identity was selected ephemerally and is not retained.
- The accepted hardware command was invoked exactly once for the planned
  10-second cell with permission/test/provider variables absent.
- The app emitted one closed operator terminal:
  `failed category=invalid_configuration`. It did not emit the attempt-start
  event. Camera authorization inspection, audio start, camera configuration,
  capture, probes, passthrough finalization, and preservation were not reached.
- Because the route stopped before authorization inspection, the current
  app-scoped Camera authorization result is unknown from R07. Enumeration does
  not establish authorization.
- The W07 publisher returned `publisher_validation_mismatch`; no validated
  snapshot was published and the one-shot consumer was therefore not invoked.
  A bounded post-terminal inspection found only the expected empty private
  directory shells: no raw event file, audio, video, or finalized media existed.
- No microphone owner or camera-session audio input was started by the failed
  route. No Ready clip was produced.

This is a functional fail and a `debug-spike defect`. The closed category does
not identify which configuration check failed, so R07 does not attribute the
failure to the device, signing, TCC, app configuration resolver, or filesystem.

## Cleanup

The app and script exited within the bound and no HoldType process remained.
The accepted publisher intentionally retained the implicated empty raw and
handoff roots after its mismatch. After recording the terminal and proving
both exact run tokens, private ownership/mode, zero files, zero links, and the
expected empty directory topology, this packet removed only those two exact
run-owned empty roots with non-recursive directory removal. One unrelated
pre-existing Phase 0B temporary root and all unrelated processes were
preserved.

Recording Cache, ActiveRecordings, TranscriptionRecovery, the broad HoldType
application-support file count, and the default Dev Vlogs destination matched
their pre-run counts. No external or remote storage was used. The scoped idle
guard remained live through evidence validation and exact cleanup, then was
stopped and its exit verified.

## Deviations

A read-only preflight first used the obsolete underscored script spelling and
received a not-found result before the accepted script path was used. A signed
Debug entitlement extraction check initially used an invalid dotted-key
query; direct plist inspection then verified the unchanged Camera and audio
input entitlements. Neither action enumerated, launched, or captured.

The material runtime deviation is the W07 publication failure. Its implicated
roots were exact, empty, and removed only after bounded classification as
described above; no consumer authority was fabricated.

## Residual

Primary residual class: `debug-spike defect`. The one hardware route terminated
at `invalid_configuration` before attempt evidence, and W07 publication failed
because no valid two-event source was available. Exact configuration cause,
authorization state, media facts, preservation dimension, and quantitative
measurements remain unavailable. No retry is authorized by this packet.

Next dependency: `DV-P0B-CAPTURE-R07-REVIEW`.
