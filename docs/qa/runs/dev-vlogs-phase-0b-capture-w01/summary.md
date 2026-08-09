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
  capture/audio/media harness. A standalone AppKit/Foundation helper, compiled
  into the mode-0700 run root without an explicit signing step or AVFoundation,
  asks LaunchServices to open the exact canonical Debug app URL as a new active
  instance. The script accepts only a matching returned bundle URL, executable
  URL, bundle identifier, token-bound process digest, and W05 marker/executable/
  inode/start/command identity. The helper publishes its strict fixed-schema
  result without replacement through one verified run-root descriptor; the
  script consumes one no-follow descriptor snapshot through that same helper,
  accepts only normalized closed fields, and then publishes one exclusive
  atomic acknowledgment. The target sets regular activation policy during
  `applicationWillFinishLaunching`, but makes no target-side activation request
  and cannot inspect Camera status until its no-follow, owner/mode/type/size-
  checked acknowledgment matches its own token-bound process digest and
  `NSApplication.isActive` is true. Invalid, timed-out, and cancelled
  acknowledgments are distinct closed redacted results. The one terminal event
  reports the furthest completed closed stage, including
  `launch_identity_acknowledged`; unknown AVFoundation status remains distinct
  from every pre-harness failure. The route creates no HoldType window, scene,
  or visible content; normal Debug and hardware-capture routes do not activate.
  Its injected authorization owner calls the
  genuine video `requestAccess` API exactly once only from a not-determined
  status, waits under an independent 120-second operational bound, and emits
  one closed redacted granted, already-authorized, denied, restricted, timeout,
  cancelled, or post-activation unknown-status terminal category. Fake tests
  cover callback absence, cancellation before every active/status/request
  observation, ignored late callbacks without a post-terminal status read,
  exact-one start/terminal evidence, and monotonic stage reporting. This command was not
  run here and no Camera authorization prompt or decision is claimed.
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
- A naturally completed harness prints its terminal line, clears its task, and
  records harness completion before scheduling one termination request on the
  next main-queue turn. This lets the authorization task unwind without
  cancelling or awaiting itself. If external quit wins the scheduling race,
  the queued request becomes a no-op and no duplicate cleanup or reply occurs.
  An external quit during active work uses
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
- Stored-video comparison failures now retain one closed redacted preservation
  dimension for each existing typed comparator failure, with a generic
  `unknown` only for foreign errors. The single failure terminal also retains
  the already-proven camera probe, passthrough completion, final probe,
  realized closed codec/format evidence, and numeric probe metrics; timeout and
  cancellation remain distinct, and no preservation failure can emit Ready or
  retry. For this Phase 0B Debug evidence lane only, the accepted trust boundary
  treats one random run-owned mode-0700 temp root as trusted against undetected
  same-UID namespace replacement; this is not a same-UID adversary-resistance
  claim and does not weaken product storage or deletion rules. Cleanup ownership
  and exact root paths are installed before creation, then raw and retained root
  identities are captured immediately. A no-follow descriptor walk pins the
  trusted base, raw source, destination, and snapshot. SHA-256 over the pinned
  source is rechecked after schema validation and after exclusive publication,
  detecting same-size in-place mutation as well as identity replacement. The
  closed handoff authority reports only root/snapshot device and inode, snapshot
  digest, a random root token, and the fixed JSONL name. The retained mode-0400
  snapshot survives raw EXIT cleanup. Its production consumer reads and
  validates that one pinned snapshot, rechecks identity and digest, and makes one
  bounded descriptor-relative cleanup attempt. Observed root, snapshot, digest,
  owner, schema, or cleanup mismatches fail closed without an uncertain success
  claim. Failed publication retains both bounded run-owned roots so the exact
  implicated raw or snapshot object remains available; same-size mutation
  specifically retains the mutated raw `events.jsonl`. Consumer mismatch and
  partial-cleanup failures retain the handoff root and any surviving pinned
  snapshot object. Evidence reports only the sanitized residual class and
  random root tokens for fixture-owned audit, never a full private path.
  The validator accepts exactly one matching start and one protected Swift
  terminal, rejects duplicate/unknown/missing keys and non-finite or out-of-range
  values, and closes every emitted failure, preservation, Ready, device, metric,
  stage-evidence, and redaction combination. It accepts the protected safe-ID
  grammar including leading hyphen or underscore, and a finite nominal FPS of
  zero only when the corresponding finite derived FPS is positive. Valid
  ordinary failures, strict preservation failures, Ready, and cancellation
  survive raw cleanup and are consumed once. Timeout and preparation-time
  INT/TERM cases are bounded and leave no run-owned root or process. INT/TERM
  during pinned publisher or consumer execution terminates only the two exact
  owned process identities and retains the implicated raw/handoff evidence;
  unrelated sentinel processes and files remain untouched. This handoff was
  fake-verified only.

## Verification

| Check | Result |
| --- | --- |
| Swift structure gate | Pass; all new Swift files remain at or below the 500-line hard limit. |
| Focused macOS fake tests | Pass; accepted authorization/helper/handshake/lifecycle coverage remains alongside exhaustive typed preservation mapping and the production-route handoff suite. The handoff suite accepts every protected ordinary failure plus valid preservation-failure, Ready, cancelled, leading-hyphen/underscore case-ID, and nominal-zero/derived-positive FPS forms; proves post-EXIT one-shot consumption after raw cleanup; rejects ownership, same-size/source/post-publication mutation, duplicate/unknown/partial schema, private-data, and numeric fixtures; audits universal implicated-residual retention across publisher and consumer mismatch classes; and covers bounded timeout, preparation signals, plus publisher/consumer INT/TERM with exact owned-process and unrelated-sentinel proof. Existing launch, deferred termination, R03 lifecycle/errors, native-source, passthrough, probes, sample preservation, one-audio-owner, Ready gating, and redaction remain covered. |
| Debug macOS build | Pass through script build-only mode; hardware mode not run. |
| Release macOS build | Pass; Debug source compiles out. Existing unrelated concurrency warnings remain. |
| Debug build settings | `Info-Debug.plist`, Debug capture entitlements, and `DEBUG` selected. |
| Release build settings | Existing `Info.plist` and `HoldType.entitlements` remain selected. |
| Built Debug artifact | Camera and Microphone purpose strings present; audio-input and camera entitlements present. |
| Built Release artifact | Existing Microphone purpose string present; Camera purpose string absent. |
| Script checks | Shell syntax, help/default-help, invalid/extra/mutually-exclusive argument rejection, bounded build-only execution, timeout-wrapped build-settings inspection, and planned-duration-plus-300-second hardware supervision passed. The helper compiles and its injected self-test covers exact configuration, descriptor-relative no-replacement publication, immutable snapshot validation, and success/rejection/timeout/cancellation/late-callback arbitration. Camera-request supervision remains unchanged from the accepted permission-lane basis. Hardware mode additionally requires one exact predeclared JSONL source, pins separate raw and retained authorities under the canonical trusted temp base, proves content stability with a descriptor-stable digest, and completes the closed-schema exclusive handoff under a five-second TERM/KILL bound before raw cleanup. The explicit consumer accepts the reported identity/digest authority, consumes the pinned snapshot once, and performs one bounded trusted-root cleanup attempt. Every detected mismatch retains its bounded implicated residual; output names only sanitized classes and random tokens, with no full path or private payload. Publisher and consumer worker/producer identities are explicit and TERM-to-KILL bounded. Non-hardware modes do not enter this route. Neither real hardware nor permission-request mode was run. |
| Diff hygiene | Pass; changed paths are confined to the repair packet and `git diff --check` is clean. |

The script accepts hardware execution only through the explicit `--hardware`
mode with a camera ID, and Camera authorization only through the mutually
exclusive `--request-camera-permission` command. Neither mode was executed.

This classifier repair does not infer or retroactively relabel the raw R02
camera-start failure. It makes a future separately authorized run diagnostic.
The AUTH-R03 unknown evidence also remains unchanged; only a future separately
authorized permission run can produce the new closed stage evidence.

## Residual

Real camera/microphone/TCC, Continuity Camera, device-busy/disconnect, codec,
playability, timing, sync/drift, and quantitative evidence remain deferred to a
separately authorized controlled hardware run. The shipping shared-audio lease
is not implemented by this Debug spike. One separately authorized runtime and
review step is still required before the repaired typed preservation evidence
and validated event handoff can support a new hardware claim. The Debug-only
trusted-root model does not claim protection from a malicious same-UID namespace
actor. Green fixtures leave no root or process; deliberate mismatch fixtures
audit the reported retained token and remove that residual themselves. This
repair does not retroactively classify the accepted R06 preservation failure.
