# Dev Vlogs Phase 0B Capture W01

Status: Debug harness implementation and fake verification complete.

Evidence boundary: build and injected-fake evidence only. This run did not
launch the harness, request Camera or Microphone permission, access capture
hardware, or produce media. It makes no claim about TCC, built-in/USB/Continuity
Camera behavior, real codecs, latency, synchronization, drift, or resource use.

## Implemented boundary

- An explicit Debug environment gate defaults off. The gated delegate avoids
  constructing the ordinary app delegate and its eager dictation, Fixes, and
  floating-indicator runtimes.
- The harness creates one unique run directory under a caller-provided safe
  temporary root, starts the existing audio-recorder service with a prepared
  run-owned `.m4a`, and never enters normal dictation, provider, output,
  History, Recovery, or Recording Cache ownership.
- Camera capture selects one explicit stable device ID, adds video input only,
  uses capability-checked movie and sample outputs, records monotonic and
  available sample timing, sets a ten-second movie fragment interval, and has
  bounded exact-once setup and terminal paths.
- Native composition/export aligns the camera and audio artifacts from
  monotonic capture markers without claiming an audio first-sample timestamp.
  The media probe requires one playable, decoded-sample-backed video track and
  one audio track, candidate dimensions/rate/codecs, positive durations, and
  finite timestamp bounds.
- JSONL evidence is limited to run/case/attempt IDs, monotonic time, compact
  actions/results, redacted device class/label, and numeric metrics.

## Verification

| Check | Result |
| --- | --- |
| Swift structure gate | Pass; all new Swift files remain below the 500-line hard limit. |
| Focused macOS fake tests | Pass; launch isolation, one audio owner, exact-once finalization, failure cleanup, alignment, timeout cancellation, strict probe validation, and event redaction covered. |
| Debug macOS build | Pass through script build-only mode; hardware mode not run. |
| Release macOS build | Pass; Debug source compiles out. Existing unrelated concurrency warnings remain. |
| Debug build settings | `Info-Debug.plist`, Debug capture entitlements, and `DEBUG` selected. |
| Release build settings | Existing `Info.plist` and `HoldType.entitlements` remain selected. |
| Built Debug artifact | Camera and Microphone purpose strings present; audio-input and camera entitlements present. |
| Built Release artifact | Existing Microphone purpose string present; Camera purpose string absent. |
| Script checks | Shell syntax, help, missing-camera-ID rejection, bounded build-only execution, and cleanup guard passed. |
| Diff hygiene | Run at final checkpoint. |

The script accepts hardware execution only through the explicit `--hardware`
mode with a camera ID. That mode was not executed.

## Residual

Real camera/microphone/TCC, Continuity Camera, device-busy/disconnect, codec,
playability, timing, sync/drift, and quantitative evidence remain deferred to a
separately authorized controlled hardware run. The shipping shared-audio lease
is not implemented by this Debug spike.
