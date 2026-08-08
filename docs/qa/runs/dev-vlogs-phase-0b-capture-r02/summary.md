# Dev Vlogs Phase 0B Capture R02

Status: terminal functional failure after explicit Continuity Camera selection.

Packet: `DV-P0B-CAPTURE-R02`

Pinned contract: `DV-DRAFT-3@ed108fa`

Product commit: `7597f3ae1dc255ee8f92cd137f0538283ba55bef`

Accepted capture harness repair: `ff70155aa0559678487eacb67bc16a62ce199b75`

## Outcome

Bundled, bounded AVCaptureDevice discovery enumerated exactly one Continuity
Camera. Its stable private identity was kept in memory, selected
deterministically, and passed to the accepted sanitized Debug harness. The
device exposed a 1280x720 format supporting 30 frames per second. No other
camera identity or fallback was used.

The harness built successfully and logged one attempt start followed by one
`attempt_terminal_camera_start` failure 196 milliseconds later. The existing
audio owner started once and produced only a 28-byte cancelled temporary audio
header. Camera capture did not start, so no video, mux, media probe, or terminal
clip existed.

The Debug app did not exit within its accepted termination-cleanup expectation.
A single Computer Use attachment attempt to the prohibited-activation harness
timed out and exposed no actionable TCC surface. The exact run-owned Debug
executable was then terminated; the outer hardware command exited 143 within
its 310-second operational bound.

Functional result: `fail`. Primary residual class: `debug-spike defect`. The
harness collapses the underlying permission, busy-device, configuration, or
other AVCaptureDevice start error into `camera_start`, so the environment/TCC
cause remains unresolved rather than inferred.

## Measurements disposition

The enumeration supports only the candidate-capability observation. No first
frame, media duration, dimensions, realized frame rate, codec, byte rate,
finalization time, CPU, memory, sync offset, or drift measurement exists. All
such quantitative fields remain `evidence_only`; no physical markers were
used.

## Cleanup receipt

- No run-owned HoldType, enumerator, watcher, harness, or idle-guard process
  remained.
- The pre-existing installed HoldType process set remained unchanged.
- The exact temporary packet root, residual inner harness root, and cancelled
  audio were removed after checksum and probe classification.
- No video or final media was produced or retained.
- No file newer than the run marker appeared in Recording Cache,
  ActiveRecordings, TranscriptionRecovery, or the default Dev Vlogs folder.
- No external or remote storage was accessed.

## Scope

This run changed no product source, specification, project setting, TCC state,
external volume, provider/Keychain state, UI, or ordinary dictation owner. It
makes no successful camera, mux, media-quality, sync, or shipping-lease claim.
