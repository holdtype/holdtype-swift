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
- A separate explicit `--request-camera-permission` script command reuses that
  same early-isolated signed Debug app identity without constructing the
  capture/audio/media harness. Only this route first changes the same process
  to the regular activation policy, requests activation, and boundedly waits
  for the app to become active before evaluating Camera authorization. Failure
  to set the policy or activate returns the existing closed unknown result and
  never calls the authorization owner. The route creates no HoldType window,
  scene, or visible content; normal Debug and hardware-capture routes do not
  activate. Its injected authorization owner calls the
  genuine video `requestAccess` API exactly once only from a not-determined
  status, waits under an independent 120-second operational bound, and emits
  one closed redacted granted, already-authorized, denied, restricted, timeout,
  cancelled, or unknown terminal category. Fake tests cover callback absence,
  cancellation, and ignored late callbacks. This command was not run here and
  no Camera authorization prompt or decision is claimed.
- The harness creates one unique run directory under a caller-provided safe
  temporary root, starts the existing audio-recorder service with a prepared
  run-owned `.m4a`, and never enters normal dictation, provider, output,
  History, Recovery, or Recording Cache ownership.
- Camera capture selects one explicit stable device ID, adds video input only,
  uses capability-checked movie and sample outputs, and leaves format, codec,
  dimensions, and cadence negotiation to macOS under the default `.high`
  session behavior. It records monotonic and available sample timing, sets a
  ten-second movie fragment interval, and has bounded exact-once setup and
  terminal paths. Injected steady-capture runtime and disconnect failures stop
  capture and complete once even when no start or stop continuation is pending.
- Native composition aligns the complete camera and audio tracks from
  monotonic capture markers without claiming an audio first-sample timestamp,
  preserves the source video transform, and exports only with compatible
  QuickTime passthrough. Passthrough incompatibility and export failure are
  distinct terminal results; there is no fallback video encode. Export
  callback/timeout arbitration resumes the caller after cancellation even when
  an injected exporter never invokes its completion callback.
- Separate bounded probes require the camera artifact to contain one playable,
  decoded-sample-backed video track and zero audio tracks, and the final
  artifact to contain one playable video and one playable audio track. They
  report realized codec, dimensions, transform, cadence, durations, and finite
  timestamp bounds without a fixed format whitelist. Ready additionally
  requires a bounded stored-format sample comparison proving equal format and
  transform metadata, ordered encoded payload and sample boundaries, count,
  bytes, duration, and PTS/DTS under exactly one expected insertion offset. No
  raw samples or digest leave the run directory.
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
  remains authoritative during pending start. Explicit stop classifies a
  pending steady disconnect or runtime error before terminal cleanup, preserving
  that same typed interruption through the concrete stop route and single
  terminal event; late callbacks cannot replace it. Foreign-domain numeric
  collisions and unknown codes produce only the generic camera-unknown category.
  Evidence remains limited to run/
  case/attempt IDs, monotonic time, category/action/result enums, redacted
  device class/label, and numeric metrics; raw codes/domains, platform errors,
  paths, device identities, and private descriptions are not serialized.

## Verification

| Check | Result |
| --- | --- |
| Swift structure gate | Pass; all new Swift files remain at or below the 500-line hard limit. |
| Focused macOS fake tests | Pass; 56 logical tests include 11 authorization-mode tests covering activation-policy/activation/status/request ordering, fail-closed activation, zero activation for normal and hardware routes, every authorization status, exact-one request, grant/denial/restriction callbacks, callback-absent timeout, cancellation, ignored late callbacks, exact-one terminal evidence, early launch routing, and owner isolation, while preserving the 45 accepted launch, R03 lifecycle/error, native-source, passthrough, probe, preservation, one-audio-owner, Ready-gating, and redaction tests. |
| Debug macOS build | Pass through script build-only mode; hardware mode not run. |
| Release macOS build | Pass; Debug source compiles out. Existing unrelated concurrency warnings remain. |
| Debug build settings | `Info-Debug.plist`, Debug capture entitlements, and `DEBUG` selected. |
| Release build settings | Existing `Info.plist` and `HoldType.entitlements` remain selected. |
| Built Debug artifact | Camera and Microphone purpose strings present; audio-input and camera entitlements present. |
| Built Release artifact | Existing Microphone purpose string present; Camera purpose string absent. |
| Script checks | Shell syntax, help/default-help, invalid/extra/mutually-exclusive argument rejection, bounded build-only execution, timeout-wrapped build-settings inspection, exact run-owned supervisor cleanup, planned-duration-plus-300-second hardware bound, and the separate sanitized 120-plus-300-second Camera-request bound passed structurally; neither hardware nor permission-request mode was run. |
| Diff hygiene | Pass; changed paths are confined to the repair packet and `git diff --check` is clean. |

The script accepts hardware execution only through the explicit `--hardware`
mode with a camera ID, and Camera authorization only through the mutually
exclusive `--request-camera-permission` command. Neither mode was executed.

This classifier repair does not infer or retroactively relabel the raw R02
camera-start failure. It makes a future separately authorized run diagnostic.

## Residual

Real camera/microphone/TCC, Continuity Camera, device-busy/disconnect, codec,
playability, timing, sync/drift, and quantitative evidence remain deferred to a
separately authorized controlled hardware run. The shipping shared-audio lease
is not implemented by this Debug spike. One separately authorized runtime and
review step must invoke the repaired explicit Camera-request command with the
same signed Debug identity before any capture retry can claim a prompt or
authorization result.
