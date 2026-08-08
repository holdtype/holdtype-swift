# Dev Vlogs Phase 0B Capture W01

Status: Debug harness implementation and fake verification complete.

Evidence boundary: build and injected-fake evidence only. This run did not
launch the harness, request Camera or Microphone permission, access capture
hardware, or produce media. It makes no claim about TCC, built-in/USB/Continuity
Camera behavior, real codecs, latency, synchronization, drift, or resource use.

## Implemented boundary

- An explicit Debug environment gate defaults off. A Debug entry point selects
  the harness-only SwiftUI scene graph before constructing either app path.
  The gated path therefore constructs neither the ordinary app delegate and
  its eager runtimes nor product Settings, Fixes, History, or failure-prompt
  scenes; the ungated path remains the ordinary app composition.
- The harness creates one unique run directory under a caller-provided safe
  temporary root, starts the existing audio-recorder service with a prepared
  run-owned `.m4a`, and never enters normal dictation, provider, output,
  History, Recovery, or Recording Cache ownership.
- Camera capture selects one explicit stable device ID, adds video input only,
  uses capability-checked movie and sample outputs, records monotonic and
  available sample timing, sets a ten-second movie fragment interval, and has
  bounded exact-once setup and terminal paths. Injected steady-capture runtime
  and disconnect failures stop capture, restore configuration, and complete
  once even when no start or stop continuation is pending.
- Native composition/export aligns the camera and audio artifacts from
  monotonic capture markers without claiming an audio first-sample timestamp.
  Export callback/timeout arbitration resumes the caller after cancellation
  even when an injected exporter never invokes its completion callback.
  The media probe requires one playable, decoded-sample-backed video track and
  one audio track, candidate dimensions/rate/codecs, positive durations, and
  finite timestamp bounds.
- A naturally completed harness clears its task before requesting termination,
  so success and camera-start failure exit without cancelling or awaiting the
  completing task itself. An external quit during active work uses
  `terminateLater` while camera/audio cleanup and terminal logging receive a
  bounded opportunity; completion, timeout, and late callbacks reply exactly
  once in injected tests.
- Camera errors retain one closed redacted category through the terminal JSONL
  event and compact operator summary. Raw AVFoundation classification requires
  the authoritative framework error domain, recognizes the two current SDK
  authorization codes plus the supported busy/disconnect codes, and separates
  a disconnect before start/first-frame evidence from a steady-capture
  interruption. Start succeeds only after movie-recording and first-frame
  evidence arrive, in either order. The first typed observer or delegate error
  remains authoritative across pending start, steady cleanup, later stop, and
  the single terminal event; late callbacks cannot replace it. Foreign-domain
  numeric collisions and unknown codes produce only the generic camera-unknown
  category. Evidence remains limited to run/
  case/attempt IDs, monotonic time, category/action/result enums, redacted
  device class/label, and numeric metrics; raw codes/domains, platform errors,
  paths, device identities, and private descriptions are not serialized.

## Verification

| Check | Result |
| --- | --- |
| Swift structure gate | Pass; all new Swift files remain at or below the 500-line hard limit. |
| Focused macOS fake tests | Pass; 34 tests cover pre-composition launch routing, harness-only scene structure, typed and raw domain/context camera-category mapping, pre-continuation observer failure, both recording/first-frame start orders, no-first-frame timeout, typed steady-stop terminal propagation, authorization/busy/disconnect SDK codes, foreign-domain collisions, malicious private error material, natural completion without self-await, bounded external-quit cleanup, one audio owner, steady-capture failure cleanup, late-duplicate safety, callback-free export timeout/cancellation, alignment, strict probe validation, and event redaction. |
| Debug macOS build | Pass through script build-only mode; hardware mode not run. |
| Release macOS build | Pass; Debug source compiles out. Existing unrelated concurrency warnings remain. |
| Debug build settings | `Info-Debug.plist`, Debug capture entitlements, and `DEBUG` selected. |
| Release build settings | Existing `Info.plist` and `HoldType.entitlements` remain selected. |
| Built Debug artifact | Camera and Microphone purpose strings present; audio-input and camera entitlements present. |
| Built Release artifact | Existing Microphone purpose string present; Camera purpose string absent. |
| Script checks | Shell syntax, help, invalid/overflowing duration and missing-camera-ID rejection, bounded build-only execution, timeout-wrapped hardware build-settings inspection, exact run-owned supervisor cleanup, and planned-duration-plus-300-second outer bound passed structurally; hardware mode was not run. |
| Diff hygiene | Pass; changed paths are confined to the repair packet and `git diff --check` is clean. |

The script accepts hardware execution only through the explicit `--hardware`
mode with a camera ID. That mode was not executed.

This classifier repair does not infer or retroactively relabel the raw R02
camera-start failure. It makes a future separately authorized run diagnostic.

## Residual

Real camera/microphone/TCC, Continuity Camera, device-busy/disconnect, codec,
playability, timing, sync/drift, and quantitative evidence remain deferred to a
separately authorized controlled hardware run. The shipping shared-audio lease
is not implemented by this Debug spike.
