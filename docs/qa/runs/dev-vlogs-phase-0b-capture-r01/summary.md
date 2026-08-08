# Dev Vlogs Phase 0B Capture R01

Status: terminal preflight; all three camera-class cells are `not_available`.

Packet: `DV-P0B-CAPTURE-R01`

Pinned contract: `DV-DRAFT-3@ed108fa`

Product commit: `3e0f9d89cc894aafa0114c407f632f0235836241`

Accepted capture harness repair: `ff70155aa0559678487eacb67bc16a62ce199b75`

## Outcome

The isolated Debug harness built successfully and retained its Camera and
Microphone purpose strings plus camera and audio-input entitlements. Release
settings remained bound to the ordinary product Info.plist and entitlements.

A bounded Apple-native enumerator used AVCaptureDevice device type,
`isContinuityCamera`, and transport type rather than camera display names. It
found no built-in, USB, Continuity, or other external camera. A final repeat of
the same enumeration ran with one scoped `caffeinate -dimsu` process whose
liveness was verified immediately before and after enumeration.

No camera unique ID was available, so the accepted hardware harness was not
launched. This preserves the no-fallback rule. No Camera or Microphone prompt
appeared, no capture or finalization started, and no audio or video was
produced. The camera-only, one-audio-owner, mux, playable-track, exact-once
terminal-clip, and candidate-quality gates therefore remain unqualified.

## Hardware matrix

| Camera class | Connection evidence | Result | Residual class |
| --- | --- | --- | --- |
| Built-in | No AVCaptureDevice built-in camera enumerated | `not_available` | hardware unavailable |
| USB | No external AVCaptureDevice with USB transport enumerated | `not_available` | hardware unavailable |
| iPhone Continuity Camera | The connected iPhone did not enumerate as an AVCaptureDevice Continuity Camera | `not_available` | environment or signing residual |

The Continuity result is not iPhone Mirroring evidence and is not a pass.

## Measurements disposition

No capture measurements exist. Latency, duration, dimensions, nominal frame
rate, codecs, byte rate, finalization overhead, CPU, memory, sync offset, and
drift remain blank with disposition `evidence_only`. Sync and drift also lack
the physical markers required for measurement.

## Cleanup receipt

- No run-owned HoldType or enumerator process remained.
- The pre-existing installed HoldType process remained alive and untouched.
- No raw media existed before cleanup.
- Both exact run-owned temporary roots were removed.
- The final scoped idle guard was stopped after verified enumeration.
- No file newer than the run marker appeared in Recording Cache,
  ActiveRecordings, TranscriptionRecovery, or the default Dev Vlogs folder.
- No external or remote storage was accessed.

## Scope

This run changed no product source, specification, project setting, TCC state,
external volume, provider/Keychain state, UI, or ordinary dictation owner. It
makes no claim beyond bounded signing and camera-enumeration preflight.
