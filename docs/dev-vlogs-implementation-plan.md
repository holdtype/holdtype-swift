# HoldType Dev Vlogs Implementation Plan

Status: active delivery plan. Phase 0C and Phase 1 setup/UI are accepted;
the approved Publish presentation slice is current.

Date: 2026-08-11

Pinned product basis: `docs/specs/features/dev-vlogs.md`, revision
`DV-ACTIVE-5`.

Active persistent-goal registry:
[`docs/dev-vlogs-execution-registry.md`](dev-vlogs-execution-registry.md).

This document sequences delivery under the Active/Evolving Dev Vlogs contract.
The contract is product authority; this plan does not replace it. Capability
acceptance remains scenario- and residual-gated. The immediate consumer of
Phase 0C is the Release-path Phase 1 menu/window/Off/Setup slice.

## 1. Outcome

Add an optional macOS-only workflow that records a short camera clip alongside
an eligible HoldType dictation, stores clips locally by day and trigger app,
lets the user review and remove source material in Finder, and explicitly
builds every remaining clip for one selected day/application scope into a
shareable video.

The product should feel like a developer journal attached to a workflow the
user already performs. It must not become a general screen recorder, a hidden
ambient recorder, or a second failure dependency for dictation.

## 2. Contract Change Envelope

- Task: deliver Dev Vlogs through Phase 4, beginning with the smallest
  Release-path setup slice.
- Change mode: scoped `evolve` under `DV-ACTIVE-5`; reconcile only when evidence
  proves a contract omission or discrepancy.
- User-authorized outcome: Active Dev Vlogs implementation authority and
  outcome-first delivery, explicitly authorized on 2026-08-11.
- Authorized domains: Dev Vlogs enablement, eligibility, camera capture,
  storage, local archive, review, builds, export, macOS Share, and the separate
  Dev Vlogs window. Direct publication is outside the active goal.
- Authorized UI clarification: use the repository's existing normal-window
  infrastructure, with a Settings-like sidebar/detail structure and SwiftUI
  visible content only.
- Protected adjacent domains: dictation, transcription, output delivery,
  Recording Cache, Transcript History, shared Settings behavior, current
  required setup, menu-bar compactness, Keychain, diagnostics, updates, and all
  iOS behavior.
- Shared owners that may later be extended without changing other consumers:
  app scene composition, active-app identification, permission adapters,
  recording finalization, and app-window activation.
- Authority status: Active/Evolving; implementation authority is present while
  capability acceptance remains gated by the active acceptance map.
- Stability baseline: existing macOS behavior is released and protected; Dev
  Vlogs is new and evolving.
- Required evidence: the capability-specific evidence in the active acceptance
  map, proportional tests/review, and runtime SwiftUI QA for visible slices.
- Allowed specification delta: only the named Dev Vlogs behavior and explicit,
  narrow integration clauses in affected active contracts.
- Forbidden specification delta: weakening normal audio cleanup, changing
  dictation exact-once behavior, adding hidden capture, moving feature toggles
  into Permissions, or changing iOS.
- Material user decisions: none inside the approved Finder-owned daily Publish
  slice. `DV-BUILD-6` fails incompatible passthrough builds with no
  output.
- Current contract revision: `DV-ACTIVE-5`.
- Required review and QA: proportional `DV-P0C-REVIEW` before Phase 1
  implementation acceptance; focused evidence per delivered capability; real
  macOS UI/device/storage QA before the corresponding acceptance or release
  claim.

## 3. Accepted Product Baseline

The plan treats these points as already agreed:

- Dev Vlogs is off by default.
- The feature is opened from `Dev Vlogs…` in the menu bar and lives in a
  separate normal macOS window.
- The window follows the Settings information-architecture pattern because it
  contains several distinct sections. It does not become another section of
  Settings.
- The repository's existing SwiftUI scene/window path should be reused. All
  visible window content, navigation, preview, playback, controls, and feedback
  are SwiftUI.
- AppKit may appear only behind narrow non-visual macOS adapters where the
  platform requires it. The existing Fixes `NSPanel` exception does not apply.
- Camera and vlog capture run as a best-effort branch parallel to dictation.
  Their failure never blocks or invalidates a usable dictation result.
- The initial app policy recommends explicit selected apps and stores identity
  by bundle identifier.
- One preferred camera is remembered across disconnect/reconnect and is never
  silently replaced.
- The selected camera and macOS negotiate source video. HoldType adds no
  resolution/FPS downgrade or additional source-video encode, and exposes no
  capture-quality selector. Native 1080p or another negotiated format may be
  preserved without becoming a HoldType preset or a sensor-RAW promise.
- The default destination is `~/Movies/HoldType Dev Vlogs`; the user can choose
  an external drive. An unavailable destination never causes a silent internal
  fallback.
- Source clips are grouped by local day and trigger app, with local metadata
  that can be rebuilt without transcript content.
- Clip deletion is explicit. Build/export is non-destructive and initially
  user-initiated.
- Direct publication is deferred until local capture, review, and export are
  reliable.

## 4. Window Information Architecture

### 4.1 Structural pattern

Create a dedicated SwiftUI scene using the same broad pattern as
`SettingsScene`:

- one normal `Window` registered in the app scene tree;
- one menu-bar command that dismisses the popover, activates HoldType, and
  opens the window;
- one window-local navigation owner;
- a `NavigationSplitView` with a stable sidebar and detail pane;
- a title that follows the selected section, for example
  `HoldType: Dev Vlogs — Storage`;
- deterministic SwiftUI previews for meaningful states without live camera,
  disk, permissions, or timers.

Reuse the scene-opening and visual conventions, not the large Settings state
owner itself. Dev Vlogs needs a separate domain model so camera, destination,
library, build, and publication state cannot accidentally affect Settings or
dictation lifecycle.

The repository-required `build-macos-apps:swiftui-patterns` skill is available
and governs UI design and implementation. It reinforces the dedicated utility
window, explicit window-scoped navigation, native sidebar/detail structure,
short menu label, and SwiftUI-first boundary used here.

The capture spike must also prove a SwiftUI-first live-preview path. If the
supported macOS targets cannot deliver an acceptable live camera preview
without a platform view adapter, that limitation must be demonstrated and the
adapter must remain the smallest possible AVFoundation rendering boundary;
navigation, controls, state, overlays, and feedback stay in SwiftUI.

### 4.2 Proposed sections

| Section | Responsibility | First delivery |
| --- | --- | --- |
| Overview | Feature enablement and readiness first; current-day summary and primary recovery/build actions only as their owners ship | Immediate passive Off/Setup slice |
| Capture | Preferred camera, bounded preview, visible recording behavior | Later Phase 1 setup increment after its lifecycle is truthful |
| Applications | Selected-app allowlist or all-apps-with-exclusions policy | Later Phase 1 setup increment |
| Storage | Destination, bookmark health, free space, archive size, Finder actions | Later Phase 1 setup increment; no numeric thresholds without evidence |
| Publish | Day and application scope, Finder review/Refresh, Original output, build progress/result, Reveal, and Share | Real archive-backed workflow; no separate Library or clip editor |

The first implementation should not render empty placeholder sections for work
that is not delivered. Stable navigation entries become visible when their
contained workflow is usable. Overview may summarize a blocked permission or
storage state, but the detailed recovery stays in its owning section.

### 4.3 Permission presentation boundary

Dev Vlogs may present these genuine statuses in their owning sections without
adding a separate Permissions navigation destination:

- Camera: genuine macOS authorization state, request action, and System
  Settings recovery.
- Microphone: the existing genuine permission status, shown as shared with
  Dictation rather than introducing a second microphone gate or request owner.

It must not contain:

- the `Enable Dev Vlogs` switch;
- application allowlist/exclusion controls;
- remote-processing disclosure;
- destination choice, mount state, bookmark state, or free-space health;
- a fictional permission for building or publishing.

Feature enablement belongs in Overview. Camera permission belongs in Capture.
Destination access belongs in Storage. Any privacy explanation about local
camera archives belongs near enablement and capture setup.

## 5. Technical Ownership Plan

The names below describe responsibilities, not required final type names.

### 5.1 Domain and persistence

- `DevVlogsSettings`: enabled state, preferred camera identity, app policy,
  and destination reference.
- `VlogClip`: stable identity, source attempt identity, trigger-app snapshot,
  media bounds, health, duration, size, and lifecycle.
- `VlogDay`: an index over clips grouped by local date and app.
- `VlogBuild`: ordered source IDs, accepted export policy, lifecycle, and
  immutable export references.
- `PublicationAttempt`: deferred destination-specific state that references one
  completed export.
- A focused settings store persists small non-secret preferences.
- A bookmark-backed destination store owns durable folder access.
- A local manifest repository owns archive metadata and reconstruction.

No media bytes or per-clip records should be serialized into `UserDefaults`.
No vlog object should be stored in Transcript History or Recording Cache.

### 5.2 Capture branch

- A trigger snapshot captures the frontmost external app before HoldType opens
  one of its own surfaces.
- An eligibility evaluator freezes the app decision at dictation start.
- A camera service owns discovery, stable identity, connection state, preview,
  and camera-only capture.
- The existing dictation recorder remains the only microphone capture owner.
- A narrowly specified audio-artifact lease lets the vlog finalizer read the
  completed dictation audio without taking over its durability or cleanup
  policy.
- A media finalizer aligns the camera video and leased audio, validates both
  tracks, and publishes one source clip or a truthful recoverable failure.
- Every camera preparation, file finalization, media probe, and export boundary
  is bounded or cancellable.

The exact shared-audio lease is a contract gate. Implementation must not add a
second microphone recorder or retain the dictation artifact longer through an
unrecorded side effect.

### 5.3 Archive and builds

- A destination coordinator resolves the bookmark, validates writability and
  useful capacity, and reacts to mount changes without trusting them as final
  proof.
- An archive repository writes active artifacts under protected temporary
  ownership, validates final media, and then publishes the final clip name.
- A library owner presents indexed state and reconciles Finder-side moves or
  deletions without recreating data.
- A build service consumes immutable source clips and a saved recipe, writes a
  new export, and never overwrites sources or earlier successful exports.
- Publication adapters consume completed exports only and remain absent from
  the capture and build core.

## 6. Delivery Sequence

### Phase 0A — Close the decision brief — complete

Goal: settle the product forks in Section 11 that materially affect capture,
storage, and the initial UI.

Work:

1. Record the user's answers in the Dev Vlogs spec.
2. Define the exact Phase 0 measurement matrix while keeping product
   thresholds evidence-derived.
3. Decide which sections appear in the first usable window and its default
   landing section.
4. Keep the contract Draft until feasibility evidence and residuals are
   truthfully dispositioned.

Exit:

- no unresolved product choice blocks the spike;
- the spike has measurable pass/fail criteria;
- no product implementation has started.

### Phase 0B — Capture and storage feasibility spike — terminal with residuals

Goal: prove the high-risk technical chain without exposing unfinished product
behavior.

Spike matrix:

- built-in camera, common USB camera, and Continuity Camera when available;
- camera-only start synchronized with the existing dictation audio artifact;
- short, typical, and 15-minute attempts;
- start latency, audio/video offset, drift, CPU, memory, and produced byte rate;
- internal destination and external SSD/HDD;
- destination unplug during capture and finalization;
- camera disconnect, camera busy, sleep/wake, quit, and process interruption;
- playable-track validation and fragment recovery;
- realized camera/macOS-negotiated dimensions, frame rate, codec/format, and
  video-passthrough evidence through source finalization.

The spike may use a debug-only harness, fixtures, and logs. It must not ship a
feature toggle, capture from ordinary user actions, or weaken dictation
durability.

Closeout:

- the corrected bounded hardware result produced playable camera `1V/0A`,
  playable final `1V/1A`, completed AVFoundation passthrough, and preserved one
  dictation microphone owner; only the debug-only
  `camera_source / sample_size_timing_metadata` read failed;
- under the user's direct instruction, “Записала и записала... Просто не нужно
  дополнительно обрабатывать видео.”, that standalone forensic read is not a
  product gate. Shipping acceptance instead requires configured passthrough,
  no HoldType video re-encode/downsample, both playable assets, and truthful
  realized-format reporting;
- controlled storage mechanics succeeded, but R05 changed protected metadata
  and the exact cause remains unknown;
- UI R01 is terminal `not_available` with Camera `notDetermined`; live frames,
  Stop, mirroring, release, and reacquisition remain unproven;
- fake-backed paired E07 dictation non-regression is accepted; the shipping
  shared-audio lease and real product integration are not accepted;
- representative latency, sync/drift, resource, byte-rate, and finalization-
  overhead datasets remain incomplete, so no numeric thresholds are accepted;
- W10 is unreviewed supporting work and does not prove a runtime result;
- no Phase 0B expansion is admitted without separate user approval.

### Phase 0C — Activate the product contract — complete / review pending

Goal: turn the Draft into implementation authority before the first product
code edit. Completed by `DV-ACTIVE-1`; independent review is pending.

Required spec work:

1. Advance Dev Vlogs beyond `DV-DRAFT-4` to `DV-ACTIVE-1`, record
   the accepted spike evidence, add acceptance scenario IDs, and mark the
   contract Active.
2. Amend `privacy-and-permissions.md` with optional Camera permission and one
   explicit local Dev Vlogs archive exception; preserve normal audio-retention
   defaults.
3. Amend `settings-and-secret-storage.md` only for shared preferences or status
   that genuinely belong there. Keep the feature window separate.
4. Amend `menu-bar-app-shell.md` for `Dev Vlogs…` and compact capture/degraded
   indication.
5. Amend `microphone-text-input.md` for the bounded shared-audio lease without
   changing transcription ownership.
6. Amend `recording-durability-and-interruption.md` for separate vlog recovery
   ownership and explicit Delete authority.
7. Add a QA acceptance map for setup, capture, storage, library, and later
   build flows.

Disposition:

- the final reconciled Spec Basis and Contract Delta are explicit;
- implementation authority is pinned to `DV-ACTIVE-1`;
- proportional `DV-P0C-REVIEW` remains the next acceptance step;
- Phase 0B residuals gate dependent capability claims, not Phase 1 passive
  window/Off/Setup delivery.

### Phase 1 — Foundation and setup vertical slice

Goal: first ship the separate window and truthful Off/Setup state without
recording clips or requesting Camera; then add setup capabilities in bounded
increments whose dependent state can be represented truthfully.

Immediate Release-path slice:

- add `Dev Vlogs…` to the utility group while preserving all existing commands
  and compactness;
- add a separate normal SwiftUI window titled `HoldType: Dev Vlogs`;
- open Overview by default with window-scoped selection;
- present off-by-default Off/Setup truth;
- ensure opening/reopening the window never starts capture, starts preview, or
  requests Camera permission;
- do not add empty sections or placeholder controls that imply unavailable
  capabilities.

Later Phase 1 setup increments:

- add genuine Camera permission status/request/recovery;
- show shared Microphone status without duplicating its owner;
- add camera discovery, remembered identity, disconnect/reconnect state, and an
  explicit bounded preview;
- add application policy editing by bundle identifier;
- add default and custom destinations, bookmark persistence, free-capacity
  checks, and Finder access;
- present feature, camera, app-policy, and storage states in their correct
  sections.

Immediate-slice exit:

- the Release menu item opens the dedicated window;
- Overview opens first and truthfully shows Off/Setup;
- passive opening/reopening neither captures nor requests Camera;
- existing menu commands and ordinary dictation behavior remain unchanged;
- product tests and Computer Use cover the changed action-state-result chain.

Full Phase 1 exit:

- enabling does not start capture;
- Ready requires camera, destination, and at least one effective eligible app
  under the chosen policy;
- denied Camera or missing destination leaves dictation unaffected;
- SwiftUI previews and unit tests cover off, setup-required, ready, and
  degraded states;
- real runtime QA verifies sidebar navigation, title changes, permission
  recovery, preview start/stop, destination choice, and window reopen behavior.

### Phase 2 — One-clip capture vertical slice

Goal: one eligible dictation produces at most one playable vlog clip while
dictation retains its current behavior.

Work:

- freeze trigger app, policy, camera, destination, and attempt identity at
  dictation start, then record the realized negotiated camera format for that
  attempt;
- prepare camera capture within the agreed bound;
- implement the shared-audio lease and independent vlog lifecycle;
- finalize and mux with configured AVFoundation video passthrough and no video
  decode, re-encode, or downsample;
- validate a playable camera asset with one video/no audio track and a playable
  finalized asset with one video/one audio track, then publish one source clip;
- persist the truthfully realized video format without requiring standalone
  sample-exact or sample-size/timing forensic proof;
- write minimal day/app manifests and compact redacted diagnostics;
- expose current capture or skipped/degraded state in the Dev Vlogs window and
  only the approved compact indication in the menu bar;
- recover or classify interrupted partials on launch without uploading them.

Exit:

- zero or one vlog clip exists for each eligible attempt; duplicates cannot be
  produced by racing stop/delegate/watchdog paths;
- every vlog failure leaves the dictation result unchanged;
- unknown/ineligible apps, busy/disconnected camera, missing destination, low
  space, and slow preparation all skip only the vlog branch;
- source media opens with playable video and the expected speech audio;
- logging and diagnostics contain no media, transcript, app content, or full
  local path.

### Phase 3 — Finder-owned daily source review

Goal: make accumulated daily sources understandable and controllable through
Finder without adding an in-app editor.

Work:

- index days newest first while preserving app folders as on-disk organization;
- show selected-scope clip count, duration, byte size, and health;
- open the exact selected day or application folder in Finder for Quick Look
  and source deletion;
- observe/coalesce selected-scope changes and provide explicit Refresh;
- reconcile Finder-side additions, moves, deletions, and corrupt sources;
- show aggregate archive usage and capacity warnings.

Exit:

- every displayed state is derived from a validated local owner;
- Publish exposes no Library, Delete, exclusion, reorder, or per-clip editor;
- Publish offers All Applications or one application present for the selected
  day;
- a deleted or moved Finder file becomes Missing without recreation;
- no cleanup action can touch Recording Cache, History, exports, or unrelated
  files;
- runtime QA covers populated, empty, missing, incomplete, and playback states.

### Phase 4 — Build, export, and Share

Goal: turn every remaining valid clip in one selected day/application scope
into one reproducible local video.

Entry dependency: `DV-ACTIVE-5` preserves `DV-BUILD-6`: selected-scope clips
that cannot be composed through direct-compatible video passthrough fail with
no output.

Work:

- create saved build recipes before rendering;
- reconstruct the selected day/application scope from disk at action time;
- order every remaining valid clip by recorded timestamp and stable clip ID;
- render according to the accepted `DV-BUILD-6` passthrough-only export policy, with
  progress, cancellation, retry, and bounded media operations;
- retain completed exports independently from later source deletion;
- add playback, Reveal in Finder, and the macOS Share surface.

Exit:

- the same recipe and source set produces deterministic order and composition;
- cancel/failure preserves sources and recipe;
- retry reuses existing valid work where possible;
- prior exports are never overwritten;
- the result plays in standard macOS media tooling and can be shared without a
  social account integration.

### Phase 5 — Publication adapters, deferred

Goal: add direct publication only after the local workflow is accepted.

Before starting, research current provider APIs, authentication, pricing,
duration/codec limits, resumable upload, and duplicate-post safeguards again.
Do not rely on the 2026 discovery snapshot as current provider authority.

Work:

- add one destination adapter at a time;
- store credentials only in Keychain through explicit account setup;
- model authentication, uploading, processing, published, failed, and outcome
  uncertain independently from Build;
- require final publication confirmation;
- add `Build & Publish…` only as orchestration over separately reliable Build
  and Publish commands.

Exit:

- local build works with no publication account;
- ambiguous provider results cannot create blind duplicate retries;
- publication state never changes clips, recipes, or exports.

## 7. Verification Strategy

### Automated boundaries

- Pure domain tests: eligibility, readiness, state machines, IDs, folder names,
  build recipes, retention policy, and error mapping.
- Persistence tests: settings migration, bookmark refresh, manifests, index
  reconstruction, atomic publication, Finder-side missing files, and corrupted
  metadata preservation.
- Capture tests: fake camera and clock, bounded preparation, exact-once stop,
  shared-audio lease ownership, late callbacks, and independent failure.
- Media fixtures: playable-track validation, offset/drift calculations,
  cancellation, fragmented partials, deterministic concatenation, and export
  retry.
- UI model tests: section navigation, title, readiness summaries, permission
  action visibility, destructive-action eligibility, and progress/error states.

### Runtime boundaries

- Real camera permission must be qualified on a signed build with the final
  purpose string and required release entitlement.
- Runtime camera checks cover built-in, USB, and Continuity devices where
  available; unavailable hardware remains an explicit evidence residual.
- External storage checks cover mount, rename/remount, read-only, low-space,
  unplug during capture, unplug during build, and reconnect.
- Every visible UI phase receives a Computer Use pass against the actual app,
  with the repository's `caffeinate`, sanitized Keychain, launch, and process
  cleanup rules.
- Capture and source-finalization evidence records configured passthrough,
  playable camera/final track counts, and the actual negotiated source format.
  Device, duration, byte rate, CPU, memory, start latency, sync offset, and
  drift remain proportional rollout/threshold evidence rather than standalone
  gates for the first shipping slice.

### Per-checkpoint baseline

When Swift work is later authorized, each checkpoint runs the smallest focused
tests plus:

```sh
python3 scripts/check_swift_structure.py
xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination 'platform=macOS' build
git diff --check
```

Run the matching test destination whenever test-covered behavior changes.

## 8. File and Component Shape

The future implementation should create one clear Dev Vlogs ownership boundary
under the existing app target, for example:

```text
HoldType/
  DevVlogs/
    DevVlogsScene.swift
    DevVlogsView.swift
    DevVlogsNavigation.swift
    Views/
    Models/
    Services/
```

This is a planning direction, not a required directory name. Before creating
it, confirm Xcode project membership and current source organization. Keep
individual files within `SWIFT.md` structure limits, give standalone SwiftUI
components deterministic previews, and keep AVFoundation, file-system,
permission, and sharing effects out of view bodies.

Likely existing integration points are:

- `HoldType/HoldTypeApp.swift` for scene registration;
- `HoldType/MenuBarView.swift` and `MenuBarPresentation` for the utility action
  and compact status;
- the active-app capture seam for trigger identity;
- the dictation finalization boundary for the audio lease;
- existing permission adapters for shared Microphone status and System Settings
  recovery;
- existing app-window activation and open-after-menu-dismissal patterns.

These paths establish ownership only. They do not authorize changing another
consumer's behavior.

## 9. Checkpoint Strategy

Use small master-branch checkpoints that leave a coherent, verified state:

1. proportional review of `DV-ACTIVE-1` and its acceptance map;
2. Release `Dev Vlogs…`, separate SwiftUI window, Overview, and truthful
   Off/Setup state;
3. remaining setup capabilities in dependency-ready increments;
4. one-clip capture vertical slice under `DV-ACTIVE-3`; standalone forensic
   sample-reader residuals do not block it;
5. library/review/delete;
6. passthrough build/export/share under resolved `DV-BUILD-6`.

Plan ordinary milestones around 60% shipping implementation, 25%
verification/review/QA, and 15% discovery/diagnostics/tooling/coordination.
This is a risk tripwire, not permission to skip demonstrated safety evidence.
No Phase 0B expansion is admitted without separate user approval, and support
work must not replace the next user-visible milestone.

Every semantic discovery updates the contract before dependent implementation.
Do not continue an implementation checkpoint against a stale contract revision.
Stage only task-owned paths and keep unrelated worktree changes untouched.

## 10. Release and Rollout Gates

- Feature remains off by default for new and existing users.
- Existing dictation build/test/runtime evidence remains green with Dev Vlogs
  disabled.
- Enabling Dev Vlogs does not change dictation readiness until an explicit
  dictation action starts.
- Camera permission is never requested on app launch or passive window open.
- No hidden capture, silent camera substitution, or silent storage fallback is
  possible.
- Storage growth and destination health are visible before broad rollout.
- A release artifact is qualified, not only a local Debug build.
- Publication remains absent until its own provider-specific contract and QA
  are accepted.

## 11. Product Decision Brief

Recommended defaults are listed so the user may approve the set in one reply
or override individual items.

| ID | Decision | Recommended V1 answer | Why |
| --- | --- | --- | --- |
| `DV-D01` | Default section and sidebar order | Overview first; then Capture, Applications, Storage, Publish | Publish is the final local artifact-preparation workflow; no separate Library exists. |
| `DV-D02` | App-policy prominence | Selected apps is the recommended/default path; all-apps-with-exclusions is secondary | Safer privacy posture and matches the developer-tool use case. |
| `DV-D03` | Focus change during dictation | Freeze the trigger app at start; do not stop or move the vlog when focus later changes | One dictation maps to one clip and one folder without fragile focus tracking. |
| `DV-D04` | V1 audio source | Always the same dictation microphone | Avoids a second capture owner and keeps the spoken take consistent. |
| `DV-D05` | Source quality | Preserve the camera/macOS-negotiated source without a HoldType resolution/FPS downgrade or additional source-video encode; expose no capture-quality selector | Preserves what the camera and system actually provide without promising sensor RAW or turning native 1080p into a HoldType preset. |
| `DV-D06` | Mirroring | Mirror preview only; keep the source physically correct; defer build-time mirroring | Familiar setup preview without baking an irreversible presentation choice into source media. |
| `DV-D07` | Low-space policy | Derive numeric warning/hard-stop values from measured negotiated-source byte rates; hard-stop must reserve at least one max-length attempt under a safe measured bound plus finalization overhead | A guessed fixed threshold may be unsafe across actual camera formats; until a safe bound is proven, the numeric policy remains capability-gated. |
| `DV-D08` | Automatic retention | No automatic deletion in V1; source deletion is Finder-owned | Preserves trust while keeping HoldType non-destructive. |
| `DV-D09` | First build editing | No in-app editor; Finder edits the selected day/application source set | The output is every remaining selected-scope clip in deterministic order. |
| `DV-D10` | Transcript metadata | Do not persist transcript text beside clips in V1 | Keeps the video archive independent from transcript retention and avoids a second sensitive text index. |
| `DV-D11` | Command surface | App commands only for V1; no CLI | The requested user workflow is covered without prematurely freezing an automation API. |
| `DV-D12` | First publication target | Export, Reveal, and macOS Share only | Delivers the durable value before adding credentials and unstable provider APIs. |
| `DV-D13` | User-facing name | `Dev Vlogs` | Clear and compact; can be changed before contract activation without migration cost. |

Source capture is resolved. One separate Build decision remains:

| ID | Decision | Unranked alternatives | Status |
| --- | --- | --- | --- |
| `DV-BUILD-6` | Result when the selected scope's clips cannot be composed by direct-compatible video passthrough | Fail the Build truthfully with no output; preserve recipe, sources, and prior outputs; never silently transcode | Preserved by the direct correction and recorded in `DV-ACTIVE-5` |

## 12. Recommended First Release Cut

The smallest release worth shipping is Phases 0 through 4:

- separate Settings-like SwiftUI window;
- opt-in setup with Camera permission, selected apps, preferred camera, and
  destination;
- short best-effort camera clips tied to eligible dictations;
- Finder-owned daily source review with observation and Refresh;
- explicit all-remaining-clips daily build with the passthrough-only
  `DV-BUILD-6` export policy, Reveal, and Share.

Direct publication, captions, transcript search, trim, timelines, automatic
highlights, automatic retention, multiple cameras, and CLI automation should
remain later contracts. There is no explicit 1080p capture preset or
capture-quality-control feature; native negotiated 1080p or another source
format may still be preserved and must not be downsampled. This cut is already
useful as a private daily archive and creates a stable export artifact that
future social integrations can consume.
