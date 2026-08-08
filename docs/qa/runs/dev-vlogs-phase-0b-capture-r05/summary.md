# Dev Vlogs Phase 0B Capture R05

Status: terminal functional failure before camera start.

Packet: `DV-P0B-CAPTURE-R05`

Pinned contract: `DV-DRAFT-4@2f3266a`

Product commit: `c298cdc23af686e014fef8059857914a4df99fd4`

Accepted native-source harness: `f7ff6bfd445dee1857514d21b5898ab85e59cb66`

## Outcome

Bounded bundled AVCaptureDevice discovery exposed exactly one connected,
non-suspended Continuity Camera with a stable identity. The private identity
was kept in memory, selected explicitly, and passed to the accepted Debug
hardware harness. No built-in or USB camera enumerated, and no fallback camera
was used.

One functional attempt started. The accepted harness started its single
run-owned dictation-audio owner, then returned the closed category
`camera_permission_required` before camera capture started. The audio owner was
cancelled through that terminal route. The harness exited naturally within the
310-second outer bound. No Camera prompt appeared.

Functional result: `fail`. Residual class: `environment or signing residual`.
The camera-only video, final audio/video, passthrough, encoded-sample,
preferred-transform, and Ready gates were not exercised and are not passed.

## Measurements disposition

No first frame or media existed. Realized dimensions, cadence, codecs,
durations, sample counts, encoded bytes, finalization time, byte rate, CPU,
memory, sync offset, and drift are unavailable with disposition
`evidence_only`. No controlled visible or audible markers were used.

## Cleanup receipt

- The accepted script removed its exact run-owned raw root.
- No camera video, final clip, or retained audio existed.
- No run-owned HoldType, enumerator, watcher, build, or capture process
  remained after evidence collection.
- The pre-existing installed HoldType process remained alive and untouched.
- The scoped `caffeinate -dimsu` guard remained live through enumeration,
  capture termination, evidence collection, and raw-root verification, then
  was stopped and verified exited.
- No new file appeared in HoldType Application Support, ActiveRecordings,
  TranscriptionRecovery, or the default Dev Vlogs destination.
- Recording Cache, History-owned paths, external storage, and remote storage
  were not used by this harness path.

## Scope

This run changed no product source, specification, project setting, TCC state,
external volume, provider/Keychain state, UI, iOS behavior, or ordinary
dictation owner. It makes no claim beyond bounded explicit-device enumeration,
one failed permission-gated functional attempt, and exact cleanup.
