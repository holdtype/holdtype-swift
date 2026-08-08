# Residuals

## Hardware and environment

- `built-in-10s`: `not_available`; residual class `hardware unavailable`.
  No built-in AVCaptureDevice enumerated.
- `usb-10s`: `not_available`; residual class `hardware unavailable`. No USB
  AVCaptureDevice enumerated.
- `continuity-10s`: `not_available`; residual class `environment or signing
  residual`. The connected iPhone did not enumerate as a Continuity Camera.

## Unqualified functional gates

Because no explicit camera identity existed, no hardware case started. The
single microphone owner, video-only camera input, mux, playable audio/video,
candidate 1280x720/30 H.264/AAC result, one terminal clip, and capture-path
cleanup gates remain unqualified rather than passed.

Camera and Microphone TCC for the signed harness also remain unobserved. No
prompt appeared and TCC was not reset or changed.

## Evidence-only measurements

All requested latency, media, byte-rate, finalization, CPU, and memory values
remain unavailable. Sync offset and drift are specifically unavailable because
no capture ran and this packet did not use physical markers. They remain
Phase 0C inputs with disposition `evidence_only`, not failures against an
invented threshold.

## Operational deviation and repair

The first detached idle guard had already exited when final cleanup checked
it. No capture had started. The retained enumeration evidence was therefore
repeated once through the same bounded bundled helper while one same-shell
`caffeinate -dimsu` process was verified alive before and after enumeration,
then stopped. The guarded repeat returned the same zero-device matrix and its
temporary root was removed.

## Required next environment

A later packet needs a Mac where a built-in camera or explicit USB camera
enumerates, and the connected iPhone must become available to macOS as an
AVCaptureDevice Continuity Camera. Merely connecting the iPhone is not accepted
as camera evidence.
