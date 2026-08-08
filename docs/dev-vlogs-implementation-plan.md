# HoldType Dev Vlogs Implementation Plan

Status: planning only; implementation is not authorized.

Date: 2026-08-08

Pinned product basis: `docs/specs/features/dev-vlogs.md`, revision
`DV-DRAFT-3`.

Active persistent-goal registry:
[`docs/dev-vlogs-execution-registry.md`](dev-vlogs-execution-registry.md).

This document converts the Dev Vlogs discovery draft into a reviewable work
sequence. It is an implementation plan, not product authority. Before product
code changes, the Draft must be reconciled, its material decisions must be
settled, the affected active specs must be amended, and a new Active Dev Vlogs
contract revision must be accepted.

## 1. Outcome

Add an optional macOS-only workflow that records a short camera clip alongside
an eligible HoldType dictation, stores clips locally by day and trigger app,
lets the user review and remove source material, and explicitly builds selected
clips into a shareable video.

The product should feel like a developer journal attached to a workflow the
user already performs. It must not become a general screen recorder, a hidden
ambient recorder, or a second failure dependency for dictation.

## 2. Contract Change Envelope

- Task: plan Dev Vlogs implementation and identify the remaining product
  decisions.
- Change mode: `discover` until an accepted contract revision activates the
  feature; future implementation will be `evolve`.
- User-authorized outcome: a durable plan and decision brief only.
- Authorized domains: Dev Vlogs enablement, eligibility, camera capture,
  storage, local archive, review, builds, export, future publication, and the
  separate Dev Vlogs window.
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
- Authority status: Dev Vlogs remains Draft and is not implementation
  authority.
- Stability baseline: existing macOS behavior is released and protected; Dev
  Vlogs is new and evolving.
- Required evidence: Phase 0 capture measurements, current source ownership,
  active spec reconciliation, unit/integration tests, signed macOS permission
  evidence, external-drive tests, and runtime SwiftUI QA.
- Allowed specification delta: only the named Dev Vlogs behavior and explicit,
  narrow integration clauses in affected active contracts.
- Forbidden specification delta: weakening normal audio cleanup, changing
  dictation exact-once behavior, adding hidden capture, moving feature toggles
  into Permissions, or changing iOS.
- Material user decisions: Section 11.
- Current contract revision: `DV-DRAFT-2`.
- Required review and QA: contract review before implementation; focused media
  and persistence tests per phase; real macOS UI and device/storage QA before
  release claims.

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

Before future UI design or implementation, the implementing agent must load
the repository-required `build-macos-apps:swiftui-patterns` skill. It was not
available in the tool set used for this planning pass, so this document does
not substitute its own UI conventions for that required guidance.

The capture spike must also prove a SwiftUI-first live-preview path. If the
supported macOS targets cannot deliver an acceptable live camera preview
without a platform view adapter, that limitation must be demonstrated and the
adapter must remain the smallest possible AVFoundation rendering boundary;
navigation, controls, state, overlays, and feedback stay in SwiftUI.

### 4.2 Proposed sections

| Section | Responsibility | First delivery |
| --- | --- | --- |
| Overview | Feature enablement, readiness, current-day summary, primary recovery or build action | Setup MVP |
| Capture | Preferred camera, bounded preview, capture preset, visible recording behavior | Setup MVP |
| Applications | Selected-app allowlist or all-apps-with-exclusions policy | Setup MVP |
| Storage | Destination, bookmark health, free space, archive size, Finder actions | Setup MVP |
| Library | Days, app groups, clips, playback, inclusion, Reveal, Delete | Local clip MVP |
| Builds | Saved recipes, progress, retry, completed exports, Share | Build/export phase |
| Permissions | Genuine Camera status/action and shared Microphone status | Setup MVP |
| Publishing | Destination accounts and publication attempts | Deferred phase only |

The first implementation should not render empty placeholder sections for work
that is not delivered. Stable navigation entries become visible when their
contained workflow is usable. Overview may summarize a blocked permission or
storage state, but the detailed recovery stays in its owning section.

### 4.3 Permissions boundary

The Dev Vlogs Permissions section may contain:

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

Feature enablement belongs in Overview. Destination access belongs in Storage.
Any privacy explanation about local camera archives belongs near enablement and
capture setup.

## 5. Technical Ownership Plan

The names below describe responsibilities, not required final type names.

### 5.1 Domain and persistence

- `DevVlogsSettings`: enabled state, preferred camera identity, app policy,
  selected preset, and destination reference.
- `VlogClip`: stable identity, source attempt identity, trigger-app snapshot,
  media bounds, health, duration, size, and lifecycle.
- `VlogDay`: an index over clips grouped by local date and app.
- `VlogBuild`: ordered source IDs, preset, lifecycle, and immutable export
  references.
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

### Phase 0A — Close the decision brief

Goal: settle the product forks in Section 11 that materially affect capture,
storage, and the initial UI.

Work:

1. Record the user's answers in the Dev Vlogs spec.
2. Define the exact Phase 0 measurement matrix and acceptable thresholds.
3. Decide which sections appear in the first usable window and its default
   landing section.
4. Keep the contract Draft until the feasibility evidence exists.

Exit:

- no unresolved product choice blocks the spike;
- the spike has measurable pass/fail criteria;
- no product implementation has started.

### Phase 0B — Capture and storage feasibility spike

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
- 720p/30 H.264/AAC as the first candidate preset.

The spike may use a debug-only harness, fixtures, and logs. It must not ship a
feature toggle, capture from ordinary user actions, or weaken dictation
durability.

Exit:

- one microphone owner and later muxing are demonstrated or rejected with
  evidence;
- bounded preparation does not delay dictation beyond the accepted budget;
- sync/drift and resource measurements support a candidate preset;
- external-drive interruption has a truthful recovery classification;
- any disproved assumption returns to the user as a concrete product fork.

### Phase 0C — Activate the product contract

Goal: turn the Draft into implementation authority before the first product
code edit.

Required spec work:

1. Advance Dev Vlogs beyond `DV-DRAFT-2`, record the accepted decisions and
   spike evidence, add acceptance scenario IDs, and mark the contract Active.
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

Exit:

- final reconciled Spec Basis is explicit;
- contract review accepts the delta and protected adjacent domains;
- implementation work is pinned to the new contract revision.

### Phase 1 — Foundation and setup vertical slice

Goal: open the separate window and reach a truthful Ready or blocked state
without recording clips yet.

Work:

- add the separate SwiftUI scene, menu command, navigation owner, and delivered
  sidebar sections;
- implement off-by-default settings and readiness state;
- add genuine Camera permission status/request/recovery;
- show shared Microphone status without duplicating its owner;
- add camera discovery, remembered identity, disconnect/reconnect state, and an
  explicit bounded preview;
- add application policy editing by bundle identifier;
- add default and custom destinations, bookmark persistence, free-capacity
  checks, and Finder access;
- present feature, camera, app-policy, and storage states in their correct
  sections.

Exit:

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

- freeze trigger app, policy, camera, destination, preset, and attempt identity
  at dictation start;
- prepare camera capture within the agreed bound;
- implement the shared-audio lease and independent vlog lifecycle;
- finalize, mux, validate, and publish one source clip;
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

### Phase 3 — Library, review, and deletion

Goal: make accumulated clips understandable and controllable before build is
introduced.

Work:

- index days newest first and group clips by trigger app;
- show clip count, duration, byte size, media health, and missing-file state;
- add SwiftUI local playback, Reveal in Finder, inclusion/exclusion, and
  explicit Delete;
- reconcile Finder-side moves/deletions and rebuild local indexes;
- protect active/finalizing/build-owned sources from destructive actions;
- show aggregate archive usage and capacity warnings.

Exit:

- every displayed state is derived from a validated local owner;
- exclusion is non-destructive and Delete has exact scope;
- a deleted or moved Finder file becomes Missing without recreation;
- no cleanup action can touch Recording Cache, History, exports, or unrelated
  files;
- runtime QA covers populated, empty, missing, incomplete, and playback states.

### Phase 4 — Build, export, and Share

Goal: turn selected clips into one reproducible local video.

Work:

- create saved build recipes before rendering;
- default to Ready, non-excluded clips for one selected day in chronological
  order;
- provide the approved selection/reorder controls;
- render a new compatible H.264/AAC export with progress, cancellation, retry,
  and bounded media operations;
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
- Capture and export performance evidence records the actual preset, device,
  duration, byte rate, CPU, memory, start latency, sync offset, and drift.

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

1. accepted contract and QA map;
2. Phase 0 spike evidence, then remove or explicitly retain debug-only harness
   ownership;
3. domain/persistence foundation;
4. separate window and setup vertical slice;
5. one-clip capture vertical slice;
6. library/review/delete;
7. build/export/share;
8. each publication adapter separately.

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
| `DV-D01` | Default section and sidebar order | Overview first; then Capture, Applications, Storage, Library, Builds, Permissions | Overview can explain readiness without making permission the whole feature; detailed recovery remains easy to reach. |
| `DV-D02` | App-policy prominence | Selected apps is the recommended/default path; all-apps-with-exclusions is secondary | Safer privacy posture and matches the developer-tool use case. |
| `DV-D03` | Focus change during dictation | Freeze the trigger app at start; do not stop or move the vlog when focus later changes | One dictation maps to one clip and one folder without fragile focus tracking. |
| `DV-D04` | V1 audio source | Always the same dictation microphone | Avoids a second capture owner and keeps the spoken take consistent. |
| `DV-D05` | Source quality | Fixed 720p/30 H.264/AAC for V1; measure before accepting | Keeps storage and build behavior predictable while retaining useful social quality. |
| `DV-D06` | Mirroring | Mirror preview only; keep the source physically correct; defer build-time mirroring | Familiar setup preview without baking an irreversible presentation choice into source media. |
| `DV-D07` | Low-space policy | Derive numeric warning/hard-stop values from Phase 0 byte-rate measurements; hard-stop must reserve at least one max-length attempt plus finalization overhead | A guessed fixed threshold may be unsafe for the actual preset or too aggressive on smaller disks. |
| `DV-D08` | Automatic retention | No automatic deletion in V1; show usage and require explicit Delete | Preserves trust while the archive model is new. Add bounded retention later as an explicit opt-in policy. |
| `DV-D09` | First build editing | Selection and reorder, but no trim/timeline | Enough control to remove noise and shape the day without creating a video editor. |
| `DV-D10` | Transcript metadata | Do not persist transcript text beside clips in V1 | Keeps the video archive independent from transcript retention and avoids a second sensitive text index. |
| `DV-D11` | Command surface | App commands only for V1; no CLI | The requested user workflow is covered without prematurely freezing an automation API. |
| `DV-D12` | First publication target | Export, Reveal, and macOS Share only | Delivers the durable value before adding credentials and unstable provider APIs. |
| `DV-D13` | User-facing name | `Dev Vlogs` | Clear and compact; can be changed before contract activation without migration cost. |

## 12. Recommended First Release Cut

The smallest release worth shipping is Phases 0 through 4:

- separate Settings-like SwiftUI window;
- opt-in setup with Camera permission, selected apps, preferred camera, and
  destination;
- short best-effort camera clips tied to eligible dictations;
- day/app library with playback, Reveal, exclusion, and explicit Delete;
- explicit daily build with selection/reorder, 720p export, Reveal, and Share.

Direct publication, captions, transcript search, trim, timelines, automatic
highlights, automatic retention, 1080p, multiple cameras, and CLI automation
should remain later contracts. This cut is already useful as a private daily
archive and creates a stable export artifact that future social integrations
can consume.
