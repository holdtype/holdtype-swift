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

## Verification

| Check | Result |
| --- | --- |
| Swift structure gate | Pass; all new Swift files remain at or below the 500-line hard limit. |
| Focused macOS fake tests | Pass; 68 logical tests include 24 authorization/helper/handshake/lifecycle/event tests covering exact LaunchServices configuration, descriptor-relative result publication, strict one-snapshot schema and identity validation, the executable script parser/acknowledgment route, permission-only parser-hook dispatch, hard-bounded descriptor-relative cleanup and adversarial root replacement, helper success/rejection/timeout/cancellation/late-callback exact-once behavior, no-follow acknowledgment safety, cancellation-before-observation, policy/acknowledgment/active/status/request ordering, every authorization status, exact-one terminal evidence, early launch routing, and normal/hardware owner isolation. The remaining 44 preserve accepted launch, deferred natural termination and external-quit races, R03 lifecycle/errors, native-source, passthrough, probe, preservation, one-audio-owner, Ready gating, and redaction. |
| Debug macOS build | Pass through script build-only mode; hardware mode not run. |
| Release macOS build | Pass; Debug source compiles out. Existing unrelated concurrency warnings remain. |
| Debug build settings | `Info-Debug.plist`, Debug capture entitlements, and `DEBUG` selected. |
| Release build settings | Existing `Info.plist` and `HoldType.entitlements` remain selected. |
| Built Debug artifact | Camera and Microphone purpose strings present; audio-input and camera entitlements present. |
| Built Release artifact | Existing Microphone purpose string present; Camera purpose string absent. |
| Script checks | Shell syntax, help/default-help, invalid/extra/mutually-exclusive argument rejection, bounded build-only execution, timeout-wrapped build-settings inspection, and planned-duration-plus-300-second hardware supervision passed. The helper compiles and its injected self-test covers exact configuration, descriptor-relative no-replacement publication, immutable snapshot validation, and success/rejection/timeout/cancellation/late-callback arbitration. Camera-request supervision uses one absolute monotonic 420-second deadline established immediately after permission run-root creation, before its identity probe and the permission route's bounded Debug build/settings work. An exact 11-second tail inside that same deadline is reserved before work begins: at most 6 seconds for identity-safe process cleanup, 2 seconds for one no-follow descriptor-relative sensitive-artifact scrub and same-inode retention proof, and 3 seconds for exclusive quarantine, descriptor-relative owned-content deletion, and root-absence proof. Every cleanup subprocess receives only its remaining cap; complete identity producer/consumer pipelines execute inside one hard-wrapper-owned process group, whose TERM, KILL-after, reap, and disappearance proof fit that cap. The earlier work cutoff bounds compilation, parsing, acknowledgment, app supervision, signaling, and reap without consuming the cleanup tail. The initial bounded no-follow descriptor probe pins the canonical parent and root device/inode/owner/mode in shell memory. Cleanup reopens and fstat-matches both identities. Each sensitive artifact, regular child, directory child, and final root tombstone moves descriptor-relatively through exclusive `renameatx_np(RENAME_EXCL)` quarantine and is revalidated after the atomic move before unlink or rmdir; directories receive a second exclusive final quarantine while their proven descriptor remains open. A same-type replacement, symlink, parent replacement, ownership/type/link mismatch, or unknown top-level name is retained and forces status 70 rather than being deleted. Normal cleanup proves the original root absent; ownership uncertainty first proves sensitive artifacts absent from the same original inode, retains it, and fails with status 70. Scrub, quarantine, or removal timeout/failure likewise returns 70 with a truthful private-root residual. Deterministic reduced-deadline fakes cover normal removal, uncertainty retention, root and parent replacement, post-open swap, tombstone collision/mismatch, same-owner/mode/type sensitive and regular replacement, directory replacement after open, final-tombstone replacement, sensitive symlink/hardlink/type and unexpected-name rejection, and a TERM-ignoring complete pipeline consumer plus child with no group residue, as well as deadline expiry and INT/TERM cleanup. The executable parser hook is reachable only after explicit permission-mode selection; hook-set help, invalid, missing-camera hardware, mutually exclusive, and build-only behavior match their ordinary routes. The exact-binary baseline, W05 multi-process marker registry, fresh identity-safe signaling, quiet rescan, and permission-only valid/extra-key/wrong-digest parser behavior remain covered. The token exists transiently in the sanitized launch environment, helper memory, and exclusive acknowledgment artifact; the result stores only its digest. Neither token nor raw result enters argv or logs. Only the direct helper child is waited/reaped; LaunchServices app processes remain registry-owned non-children. The hardware tail is byte-identical to `169e895`, `b071056`, and `48c0d5c`; the W05/W06 process-ownership behavior outside the R4 pipeline-boundary hardening remains protected. Neither real hardware nor permission-request mode was run. |
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
review step must invoke the repaired exact-URL LaunchServices Camera-request
command with the same signed Debug identity before any capture retry can claim
foreground activation, a prompt, or an authorization result.
