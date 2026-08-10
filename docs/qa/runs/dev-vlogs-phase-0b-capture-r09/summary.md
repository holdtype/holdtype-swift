# Dev Vlogs Phase 0B Continuity Capture R09

Packet: `DV-P0B-CAPTURE-R09`

Result: **fail** (`video_preservation_failed`, dimension `reading_failed`).

## Scope and authority

This was one discover/evidence-only, no-retry Continuity Camera cell under
`DV-DRAFT-4@2f3266a` and Phase 0B `E02/E04/E06/E07/E08`. Runtime authority was
registry checkpoint `d3a5b2d`; native-source owners were accepted through W02
`f7ff6bf`, lifecycle through `f141be6`, hardware evidence handoff through
W07-R3 `a90f888`, and event-path validation through W09-R1 `7342f18`.
Accepted E07 evidence `719e995` remains deterministic and fake-backed only;
this runtime makes no shipping audio-lease or product-dictation claim.

No product, source, test, script, project, specification, registry, permission,
UI, external-storage, provider, Keychain, or TCC change was authorized or made.
No `requestAccess`, permission mode, System Settings action, fallback, or retry
occurred.

## Runtime result

- One bounded bundled AVFoundation enumeration reported exactly one connected,
  non-suspended, not-in-use Continuity Camera. Its explicit stable identity was
  selected ephemerally and is not retained.
- The accepted hardware command was invoked exactly once for the planned
  10-second cell with permission, test-hook, and provider variables absent.
- One attempt started and one terminal event followed. Camera capture success
  proves the accepted camera route passed its status-only `authorized` branch;
  the route never invoked `requestAccess`.
- The existing Debug dictation-audio recorder was started once. The camera
  capture owner added one video input and no camera-session audio input.
- The camera-only probe passed its strict playable one-video/zero-audio
  expectation. Passthrough finalization completed, and the final probe passed
  its strict playable one-video/one-audio expectation.
- Negotiated camera and final video were `avc1` at 1920x1080 with identity
  preferred transform. Final audio subtype was AAC. Nominal and derived
  cadence, timestamp bounds, and estimated data rates are retained as
  `evidence_only` observations.
- Strict `stored_sample_exact_v1` preservation failed with the emitted closed
  dimension `reading_failed`. The evidence does not establish which lower-level
  reader, comparator condition, platform behavior, or media artifact caused
  that dimension. No sample counts or encoded-byte totals were emitted.
- The terminal was Failed and Ready count was zero. Media playability and
  passthrough do not upgrade the failed preservation gate.

This is a functional fail with residual class `debug-spike defect`.

## Cleanup

The app and script exited within the accepted bound. The accepted script
removed its exact raw root and all raw audio/video/final media. The validated
one-shot consumer consumed the single handoff snapshot once and removed its
exact handoff root. No run-owned HoldType, script, enumerator, helper, media,
raw root, handoff root, or orchestration root remained. One unrelated
pre-existing Phase 0B temporary root and all unrelated processes were
preserved.

Recording Cache, ActiveRecordings, TranscriptionRecovery, the broad HoldType
application-support path set, and the default Dev Vlogs destination matched
their pre-run metadata-only baselines. No external or remote storage was used.
The single scoped idle guard remained live through runtime, handoff
consumption, evidence collection, validation, and private-root cleanup, then
was stopped and its exit verified.

## Deviations

One pre-runtime build-only command used the nonexistent local spelling
`dev_vlogs_phase_0_b_spike.sh` and exited before any script, app, camera, or
microphone action. The corrected accepted spelling then completed build-only.

After the sole enumerator had completed, zsh rejected assignment to its
read-only `status` parameter. The already-produced private JSON was validated
and parsed without another enumeration. A plist linter did not accept that JSON
form; a strict JSON parser did. Neither issue caused a second enumeration or
hardware invocation.

No retry, fallback, second hardware invocation, or additional capture occurred.

## Residual

Primary residual class: `debug-spike defect`. The sole attempt reached camera
probe, passthrough, and final probe, then failed strict preservation at the
emitted `reading_failed` dimension. The failure is not attributed beyond that
closed evidence. Sample counts, encoded bytes, file sizes, exact media
durations, start latency, finalization time, CPU, memory, sync offset, and drift
remain unavailable/evidence-only.

Next dependency: `DV-P0B-CAPTURE-R09-REVIEW`.
