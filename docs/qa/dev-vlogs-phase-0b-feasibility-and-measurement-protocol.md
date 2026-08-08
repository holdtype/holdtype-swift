# Dev Vlogs Phase 0B Feasibility and Measurement Protocol

Status: bounded Draft evidence protocol; not product implementation authority.

Pinned product basis: `docs/specs/features/dev-vlogs.md`, revision
`DV-DRAFT-4`.

Phase: `DV-P0B` after `DV-P0A-QUALITY-REVIEW` accepts the pinned Draft.

## Purpose and boundary

This protocol tests the technical assumptions that must be reconciled before
Dev Vlogs can become Active. It authorizes read-only feasibility work and
debug-only spikes. It does not authorize a shipping feature toggle, capture
from ordinary user actions, product UI, a new shipping dependency, a CLI, or
publication work.

The existing dictation, transcription, correction, translation, output,
History, Recording Cache, shared Settings, Keychain, diagnostics, updates,
unrelated menu behavior, iOS, and website/marketing domains remain protected.
Every spike must use controlled, non-sensitive input and a sanitized
environment with no live OpenAI request or live Keychain access.

Numeric low-space and start-latency product thresholds remain
evidence-derived. This protocol must measure them and must not invent them.
The selected camera and macOS negotiate the source-video format. Phase 0B must
prove that HoldType neither downscales nor additionally encodes that video
during source finalization. The pending incompatible-source Build fallback is
outside this source-capture decision and does not block Phase 0B source
evidence.

## Stable evidence gates

| Evidence ID | Gate | Output |
| --- | --- | --- |
| `DV-P0B-E01` | Read-only source and platform feasibility | Ownership/API map and blocker list |
| `DV-P0B-E02` | Debug-only camera, dictation-audio, and mux spike | Playable media probes and lifecycle evidence |
| `DV-P0B-E03` | Storage and finalization spike | Capacity, bookmark, interruption, and recovery evidence |
| `DV-P0B-E04` | Controlled runtime hardware matrix | Completed matrix with unavailable-hardware residuals |
| `DV-P0B-E05` | SwiftUI-first live-preview feasibility | Gate result and visual/runtime evidence after the required skill is available |
| `DV-P0B-E06` | Quantitative measurements | Latency, sync/drift, resource, byte-rate, and overhead dataset |
| `DV-P0B-E07` | Dictation non-regression | Baseline comparison and failure-independence results |
| `DV-P0B-E08` | Cleanup and residual closure | Cleanup receipt and classified residuals |

Phase 0B is evidence work only. Passing these gates does not activate the
product contract.

## 1. Read-only source and platform feasibility — `DV-P0B-E01`

Before writing a spike, record the smallest complete ownership and platform
map for:

- the current single dictation microphone owner and finalized audio artifact;
- the dictation start/stop/finalization seams needed for a debug-only observer;
- camera discovery, stable device identity, connect/disconnect, busy-device,
  and Continuity Camera signals on supported macOS targets;
- camera-only capture, timestamps, fragmented movie output, composition/mux,
  media probing, and video-passthrough/remux support;
- bookmark-backed destination access, useful available capacity, mount state,
  and external-volume interruption signals;
- the existing sanitized runtime and fake-backed dictation verification paths.

The map must distinguish required platform adapters from visible UI. It must
identify any entitlement, signing, hardware, supported-target, or shared-owner
dependency. It must not edit shipping source or reinterpret an adjacent
contract.

Pass when the candidate chain has supported platform APIs and a bounded
debug-only integration seam without a new shipping dependency. Fail with an
exact blocker when the chain requires a second microphone owner, changes
dictation artifact ownership, or requires semantic change outside the Dev
Vlogs envelope.

## 2. Debug-only camera/audio/mux spike — `DV-P0B-E02`

Use an isolated Debug-only harness or non-shipping spike target. It must not be
reachable from the normal app command surface and must be removed or explicitly
retained as test-only ownership before Phase 0B closes.

For each applicable success case:

1. Start the existing dictation audio authority once.
2. Start camera-only capture for the selected device and record monotonic event
   timestamps.
3. Stop both branches through the controlled attempt boundary.
4. Give the debug finalizer bounded read access to the completed dictation
   audio artifact without changing its owner or cleanup policy.
5. Finalize one source clip, changing container if needed and adding dictation
   audio only through a video-passthrough path. Do not request a lower source
   resolution/frame rate, downsample, or additionally encode the video.
6. Probe the camera-only and finalized assets and establish playable video and
   audio tracks, media duration, realized dimensions, nominal frame rate,
   codec/media subtype, relevant format description, timestamp bounds, and
   evidence that the encoded source video was preserved.
7. Release the temporary audio access and classify every intermediate artifact.

Use visible and audible sync markers near the start and end of controlled test
content so initial offset and end drift can be measured. Do not use real
dictation text or retain captured speech as durable QA evidence.

Functional pass criteria:

- exactly one microphone capture owner exists;
- the final clip contains one playable video track and one playable audio
  track, and the final video preserves the realized negotiated source without
  a HoldType downsample or additional video encode;
- one attempt cannot finalize more than one Ready clip;
- timeout, cancel, camera failure, and mux failure terminate in a truthful
  recoverable or failed state without changing the dictation result;
- temporary audio access ends on every terminal path.

Latency, offset, drift, finalization time, and resource values are
evidence-only measurements until Phase 0C. They do not pass merely by being
small and do not fail merely by being large without an accepted threshold.

The smallest no-reencode evidence must compare the camera-only and finalized
video tracks. Record dimensions, nominal frame rate, codec/media subtype,
relevant format description, timestamp bounds, and container/track/sample
evidence sufficient to distinguish copied encoded video from decode/re-encode.
The spike may select the narrowest supported platform probe, but it must not
claim passthrough from matching dimensions or codec names alone. If it cannot
produce a playable clip or prove preservation, the source cell fails with an
exact platform/API or product dependency; it must not silently transcode.

## 3. Storage spike — `DV-P0B-E03`

Exercise the candidate archive only inside a run-owned test directory on each
available destination class. Never use Recording Cache, Transcript History, a
real user archive, remote storage, or an unrelated folder.

The spike must cover:

- internal storage;
- an external SSD when available;
- an external HDD when available;
- bookmark creation/resolution, stale or unavailable destination, writability,
  useful available capacity, and reconnect;
- active capture, finalization, validated promotion to the final local name,
  and cleanup of run-owned temporary artifacts;
- disconnect/unplug during capture and during finalization;
- read-only or unavailable destination and no silent fallback;
- low-capacity behavior through a bounded test volume or injected capacity
  seam, never by filling a user's disk;
- peak temporary bytes during finalization, final clip bytes, recovered
  fragment bytes, and finalization overhead.

Pass when unavailable/insufficient destinations skip or stop only the vlog
branch, no silent internal fallback occurs, finalized files are playable, and
interrupted artifacts receive a truthful Ready, Incomplete, or Failed
classification. Fail on unclassified loss, overwrite outside the run root,
false Ready state, or any effect on protected storage owners.

This gate measures the inputs for warning and hard-stop capacity. It does not
choose numeric product thresholds. Phase 0C must derive them so the hard stop
reserves at least one maximum-duration attempt under a safe bound established
from measured negotiated-source behavior, plus measured finalization overhead.
If the matrix does not establish a safe bound, the threshold remains open.

## 4. Controlled runtime hardware matrix — `DV-P0B-E04`

Use one clean run per applicable cell. Repeat a failure once only when needed
to distinguish a deterministic result from an environmental outlier.

Before the first runtime action, start a scoped `caffeinate` process, record
its PID, and use only the sanitized-Keychain test launch or the isolated
debug-only harness. Stop the guard and every run-owned app/harness process in
cleanup.

### Success matrix

| Dimension | Required cases |
| --- | --- |
| Camera | Built-in camera; USB camera if available; connected iPhone Continuity Camera |
| Destination | Internal storage; external SSD if available; external HDD if available |
| Duration | Short: 10 seconds; typical: 60 seconds; maximum: 15 minutes |
| Output | Realized camera/macOS-negotiated source format; playable audio/video tracks; proven video preservation through source finalization |

Run every available camera across all three durations on internal storage. Run
the built-in camera across all three durations on every available external
destination. Run at least a short capture for each other available camera and
external-destination pairing. Record an explicit `not_available` residual for
missing built-in, USB, SSD, or HDD hardware rather than claiming it passed.

The connected iPhone Continuity Camera case is required while the device is
available. Record the exact connection mode and whether stable identity,
selection, interruption, and return can be observed without treating iPhone
Mirroring as camera evidence.

### Interruption matrix

Use short or typical controlled attempts unless a longer duration is necessary
to reproduce the condition:

- preferred camera disconnect and reconnect;
- camera busy in another controlled app or run-owned process;
- external destination unplug/disconnect during capture;
- external destination unplug/disconnect during finalization;
- sleep and wake;
- graceful quit;
- forced interruption of only the run-owned process;
- insufficient-capacity simulation;
- mux/probe failure injection.

For every interruption, record the vlog terminal classification, recoverable
artifact state, dictation result, cleanup result, and next allowed retry. Do
not terminate an app or process that the current run did not launch.

Operational safety timeouts are harness limits, not product thresholds. Device
enumeration and setup probes must stop after 30 seconds. A capture case must
stop no later than its planned duration plus five minutes. A media probe or
finalization attempt must stop after five minutes. A timeout is recorded as a
gate failure or evidence residual according to the classification rules below;
it is never allowed to wait indefinitely.

## 5. UI preview feasibility gate — `DV-P0B-E05`

This gate is blocked until `build-macos-apps:swiftui-patterns` is available and
has been read by the assigned UI feasibility owner. No UI prototype, preview
design, or visual implementation may begin before then. Capture and storage
evidence may proceed independently.

Once unblocked, the bounded gate must determine whether supported macOS targets
can provide a live preview while keeping the preview, controls, overlays,
layout, state, and feedback in SwiftUI. A narrow non-visual/rendering adapter
may be proposed only if the spike demonstrates the exact SwiftUI limitation.
It cannot own product navigation, controls, or visible feedback.

The gate passes when a SwiftUI-first preview starts and stops through explicit
test actions, releases the camera, and preserves the mirror-preview-only rule.
It fails if ordinary visible UI requires AppKit, the source is mirrored, camera
ownership leaks, or the limitation cannot be bounded to an allowed adapter.

Any runtime preview check must use the repository's Computer Use, `caffeinate`,
sanitized-Keychain launch, and run-owned process cleanup rules. Screenshots are
permitted only for the preview feasibility evidence and must contain no
sensitive content. This protocol does not decide the Dev Vlogs visual design.

## 6. Required measurements — `DV-P0B-E06`

Record one row per case with units and monotonic timestamps where applicable:

- run ID, case ID, product commit, spike commit, macOS/build version, machine
  model, power state, and thermal state;
- camera class, redacted device label, connection type, stable-identity result,
  destination class, file-system type, and duration class;
- user-action-to-dictation-audio-start, camera-request-to-first-frame, and
  user-action-to-first-frame latency;
- baseline dictation start latency without the vlog spike and the paired delta;
- initial audio/video offset and end-of-capture drift in milliseconds;
- actual duration, dimensions, average frame rate, dropped-frame count, video
  codec/media subtype, relevant video format description, audio codec, and
  track-playability result for camera-only and finalized assets;
- source-to-final video-preservation evidence, including the chosen
  container/track/sample proof and its result;
- process CPU mean, p95, and peak; resident-memory baseline and peak;
- raw video bytes, dictation-audio bytes, finalized clip bytes, recovered
  fragment bytes, bytes per recorded second, finalization time, peak bytes
  owned during finalization, and finalization overhead;
- interruption timestamp, terminal classification, retry result, and cleanup
  result;
- dictation completion/result state and whether vlog work delayed, blocked,
  cancelled, or changed it.

Start latency, sync/drift, CPU, memory, byte rate, and finalization overhead are
evidence-only observations in Phase 0B. Functional media validity, one-audio-
owner behavior, exact-once finalization, truthful storage recovery, and
dictation independence are pass/fail gates.

## 7. Dictation non-regression — `DV-P0B-E07`

Use the existing fake-backed or sanitized dictation verification path. Compare
paired baseline and spike-enabled attempts for start, stop, finalized audio
ownership, provider-dispatch eligibility, accepted output, cancellation, and
terminal cleanup. Exercise camera unavailable, busy, slow/timeout, destination
unavailable, destination disconnect, and mux failure.

Pass when every usable baseline dictation remains usable with the spike, the
same owner controls the dictation audio artifact, and vlog failure never
changes dictation state or output. Any regression is a Phase 0B blocker; do not
weaken the dictation contract or hide it as a latency observation.

## 8. Exact evidence artifacts

For one accepted run ID, retain this redacted structure:

```text
docs/qa/runs/dev-vlogs-phase-0b-<run-id>/
  summary.md
  source-feasibility.md
  environment.json
  matrix.csv
  measurements.csv
  artifacts.csv
  residuals.md
  media-probes/
    <case-id>.json
  events/
    <case-id>.jsonl
  preview/
    <case-id>.png
```

`preview/` exists only if `DV-P0B-E05` is unblocked and executed.
`artifacts.csv` records case ID, ephemeral local path class, byte counts,
checksum, media-probe result, recovery classification, and cleanup status. It
must not record a full user path.

Raw camera/audio/video files stay in one exact run-owned temporary directory
outside Git and are removed during cleanup. Do not commit media, device serial
numbers, full paths, dictated text, credentials, provider payloads, or verbose
unredacted logs. The retained event stream contains compact action, timestamp,
case ID, and terminal result only.

## 9. Result and residual classification

Each functional gate or matrix cell receives exactly one functional result:

- `pass`: every applicable functional gate passed;
- `fail`: a reproducible functional gate failed;
- `not_available`: named hardware or a required external condition was not
  available;
- `blocked_skill`: only for `DV-P0B-E05` while the required skill is absent.

Each quantitative latency, sync/drift, resource, byte-rate, or overhead field
also receives the disposition `evidence_only` until Phase 0C derives and
accepts a product threshold. A cell can therefore pass its functional gates
while its quantitative observations remain evidence-only.

Every non-pass functional result and each unresolved evidence-only dataset must
also use one residual class:

- platform/API feasibility blocker;
- protected-domain dependency;
- debug-spike defect;
- environment or signing residual;
- hardware unavailable;
- measurement outlier;
- product-threshold input awaiting Phase 0C;
- UI-skill gate;
- real product fork requiring user authority.

Do not turn an unavailable USB camera, SSD, or HDD into a pass. Do not turn a
large measurement into a failure before a threshold exists. Do not turn an
unplayable track, second microphone owner, false recovery state, or dictation
regression into evidence-only.

## 10. Cleanup — `DV-P0B-E08`

At the end of each runtime session:

1. stop capture and finalization through the harness when possible;
2. terminate only run-owned debug/HoldType processes and verify exit;
3. release camera, microphone, bookmark, file, and external-volume handles;
4. stop the scoped `caffeinate` process started for the runtime session;
5. remove only the exact run-owned temporary media directory after retained
   probes, checksums, byte counts, and classifications are recorded;
6. confirm no file was added to Recording Cache, Transcript History, the user's
   Dev Vlogs destination, or remote storage;
7. record cleanup status for every artifact and any exact residual.

Do not delete, move, overwrite, or clean unrelated local data, databases, or
remote/object storage. If a controlled physical disconnect or reconnection is
unavailable to automation, classify the exact cell instead of substituting a
different interaction or claiming success.

## Phase 0B closeout

Phase 0B may advance to review only when all available hardware cells and every
functional gate have terminal evidence, unavailable cells are explicit, raw
media cleanup is confirmed, and `DV-P0B-E05` is either completed after the
required skill becomes available or remains an exact dependency that prevents
the corresponding UI feasibility claim.

The review returns functional failures and protected-domain dependencies as
blockers. It carries quantitative evidence and honest environment residuals to
Phase 0C. Phase 0C, not this protocol, derives numeric start-latency and
low-space product thresholds from actual negotiated-source behavior before
proposing an Active contract. Evidence about direct-compatible Build
passthrough may be retained, but the unresolved `DV-BUILD-6` fallback remains
a separate user decision.
