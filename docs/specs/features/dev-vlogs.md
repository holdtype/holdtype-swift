# Dev Vlogs

Status: Active / Evolving implementation authority. Capability acceptance is
gated by the acceptance map and explicit residuals below.

Contract revision: `DV-ACTIVE-2`.

Revision note: `DV-ACTIVE-2` records the user-approved Publish information
architecture from the autonomous delivery plan committed at `3753db1`.
`Publish` is the final user-facing section and means local artifact
preparation, not remote publication. Before Library and media owners ship, the
Release path shows a truthful no-recordings state; populated, progress,
failure, cancellation, and result presentations are deterministic preview and
test inputs only. This revision does not resolve the incompatible-source fork
in `DV-BUILD-6`; the plan's no-hidden-transcode direction remains guidance
until its dependent implementation packet records the authorized resolution.

Revision note: `DV-ACTIVE-1` supersedes `DV-DRAFT-4` under the user's explicit
2026-08-11 authority. It activates implementation authority for the accepted
V1 domain while preserving capability-specific acceptance gates. The selected
camera and macOS negotiate the captured video format; HoldType must not
downsample or additionally encode source video. The final Build fallback when
passthrough is impossible remains the explicit pending `DV-BUILD-6` decision
and gates only Phase 4 incompatible-source behavior.

Implementation planning:
[`docs/dev-vlogs-implementation-plan.md`](../../dev-vlogs-implementation-plan.md).

Change mode: scoped `evolve` plus `reconcile` for the active V1 contract and
the narrow adjacent integration clauses named below.

## Goal

Dev Vlogs turns a normal HoldType dictation attempt into an optional local
developer-vlog clip. When the user starts dictating in an eligible app,
HoldType may record the selected camera at the same time and preserve a short
video with the same spoken audio.

The result is a low-friction local archive of real work moments. The user can
review and remove clips, then explicitly build selected clips into a single
video for personal archiving or publication.

The feature is additive. Dictation remains the primary HoldType workflow and
must keep working when any Dev Vlogs dependency fails.

## Product thesis

The distinctive idea is not another general-purpose screen recorder. It is a
camera journal whose clip boundaries already exist in the user's work: each
explicit HoldType dictation is one short take.

This should make the archive useful without requiring the user to remember to
start and stop a second recorder. It should also produce smaller, more
reviewable source material than continuous background capture.

## Contract boundary

The user has authorized implementation of the accepted V1 domain under
`DV-ACTIVE-2`. An Active/Evolving label is not proof that a capability is
implemented, accepted, or released; each capability remains governed by its
acceptance scenarios and current residuals.

Authorized V1 domains:

- feature enablement and eligibility;
- camera selection and camera capture;
- local vlog storage and app-based organization;
- clip review, build, export, and macOS Share; deferred publication concepts
  remain context only and are not implementation authority;
- the separate Dev Vlogs window and its menu entry.

Protected adjacent domains:

- microphone dictation, transcription, correction, translation, and text
  delivery;
- recording durability, Transcript History, and Recording Cache ownership;
- the current menu bar status hierarchy;
- the genuine-system-permission boundary in Permissions;
- Keychain, diagnostics, updates, and all iOS behavior.

The active privacy contract now includes one narrowly named local Dev Vlogs
archive exception for eligible camera video plus same-dictation audio. It does
not weaken normal dictation retention, Recording Cache defaults, History
ownership, or cleanup behavior.

### Contract Delta — `DV-ACTIVE-1`

- Change ID: `DV-DELTA-ACTIVE-1`.
- Change mode: scoped `evolve` plus `reconcile`.
- Authorized by: explicit user authority dated 2026-08-11 to activate Dev
  Vlogs and improve the project-local contract and coordination state.
- Domain and clause IDs: active Dev Vlogs V1 clauses and acceptance map;
  optional Camera/local-archive privacy exception; separate feature
  preferences/window; `Dev Vlogs…` menu entry; bounded shared-audio lease;
  separate vlog-media durability and Delete boundary.
- Previous behavior: `DV-DRAFT-4` was evidence-only and required Phase 0C
  activation before product implementation; Phase 0B failures were expressed
  as broad implementation gates.
- New or reconciled behavior: `DV-ACTIVE-1` is Active/Evolving implementation
  authority. Residuals gate only dependent capability claims. The Phase 1
  `Dev Vlogs…` menu item, separate SwiftUI window, Overview default, and
  truthful Off/Setup state are implementation-ready without capture, preview,
  storage-threshold, or Build acceptance.
- Evidence basis: accepted `DV-D01`–`DV-D13`; R09 playable camera `1V/0A`,
  playable final `1V/1A`, successful passthrough and failed strict preservation
  `reading_failed` with Ready=0; storage R05 mechanics plus unknown protected
  metadata change; UI R01 terminal `not_available`; accepted fake-backed E07;
  incomplete quantitative datasets; W10 as unreviewed supporting work only.
- Compatibility classification: additive macOS feature evolution; existing
  released HoldType behavior remains protected.
- Adjacent domains checked: permissions/privacy, Settings/secrets, menu shell,
  microphone input, recording durability, History, Recording Cache, Keychain,
  diagnostics, updates, unrelated menu commands, iOS, and marketing.
- QA and design impact: the active acceptance map below separates
  implementation readiness from acceptance evidence. The dedicated window and
  all visible content remain SwiftUI.
- Specification paths changed: this contract, its plan/index/Phase 0B closeout,
  five narrow adjacent contracts, and the execution-registry split.
- Independent review: pending `DV-P0C-REVIEW`.
- New contract revision or epoch: `DV-ACTIVE-1`.

### Contract Delta — `DV-ACTIVE-2`

- Change ID: `DV-DELTA-ACTIVE-2-PUBLISH-UI`.
- Change mode: scoped `evolve` plus `reconcile`.
- Authorized by: the user-approved Dev Vlogs product/design brief and
  autonomous delivery plan dated 2026-08-11, committed at `3753db1`.
- Domain and clause IDs: `DV-UI-3`, `DV-UI-6`, `DV-UI-9`, `DV-BUILD-*`
  presentation only, `DV-SHARE-1`, `DV-D01`, `DV-D09`, `DV-D12`, and
  `DV-D13`.
- Previous behavior: the future complete sidebar named separate Builds and
  Permissions sections, while publication was absent pending a deferred
  delivery.
- New or reconciled behavior: the complete sidebar is Overview, Capture,
  Applications, Storage, Library, Publish. Publish is the user-facing local
  artifact-preparation workflow; build recipes remain internal durable
  entities. Iteration 1 exposes Publish as the final current destination
  without adding an empty Library placeholder. Release runtime remains a
  truthful no-recordings state until Library/media owners exist; richer states
  are deterministic preview/test inputs only.
- Evidence basis: the approved plan at `3753db1`, accepted Phase 1 UI at
  `b9114a5`, and the accepted visual baseline at
  `docs/qa/runs/dev-vlogs-ui-polish/final/dev-vlogs-final.png`.
- Compatibility classification: additive macOS UI evolution inside the
  unreleased Dev Vlogs domain; existing released HoldType behavior and
  accepted Phase 1 setup semantics remain protected.
- Adjacent domains checked: ordinary dictation/transcription/output, Settings,
  permissions, Keychain, capture/media, Library/Delete, diagnostics, iOS,
  direct publication, and unrelated menu behavior remain unchanged.
- QA and design impact: focused navigation and presentation-state tests plus
  bounded Computer Use and visual comparison are required. All visible
  content remains SwiftUI and uses the accepted Settings-quality language.
- Specification paths changed: this contract and the directly related Dev
  Vlogs implementation-plan wording.
- Independent review: pending the `DV-P2-PUBLISH-UI` integration review.
- New contract revision or epoch: `DV-ACTIVE-2`.

### Historical Contract Delta — `DV-DRAFT-4`

- Change ID: `DV-DELTA-DRAFT-4-NATIVE-SOURCE`.
- Change mode: scoped `evolve` inside the Dev Vlogs Draft.
- Authorized by: the user's 2026-08-08 instruction that HoldType must preserve
  camera/macOS-native source quality without app-imposed compression or
  downgrade, clarified as no additional HoldType source-video encode or
  downsample rather than a promise of sensor RAW.
- Domain and clause IDs: source portion of `DV-D05`, `DV-CAPTURE-10`,
  `DV-STORAGE-9`–`DV-STORAGE-10`, `DV-BUILD-3`, `DV-BUILD-6`,
  `DV-ACC-MEDIA-1`, and `DV-EU-3`–`DV-EU-4`.
- Previous behavior: `DV-DRAFT-3` treated one fixed
  resolution/frame-rate/codec combination as the source candidate and tied
  storage evidence and Build output to that preset.
- New behavior: the selected camera and macOS negotiate source video;
  HoldType adds no resolution/FPS downgrade and no additional source-video
  encode. Source finalization may change container and add dictation audio only
  through a proven video-passthrough path. Build fallback when passthrough is
  impossible remains unresolved and does not block source-capture evidence.
- Evidence basis: the explicit user decision recorded in the persistent-goal
  registry at `cf2c4ee`, this Draft, the implementation plan, and the Phase 0B
  protocol at
  [`docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md`](../../qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md).
- Compatibility classification: additive Draft evolution; no shipped behavior,
  adjacent Active contract, or release baseline changes.
- Adjacent domains checked: dictation, transcription and output, History,
  Recording Cache, shared Settings, Permissions, Keychain, diagnostics,
  updates, unrelated menu behavior, iOS, and website/marketing remain
  protected.
- QA and design impact: Phase 0B must prove realized negotiated format and
  source-video preservation, and measure capacity from actual source behavior.
  No capture-quality selector is introduced. UI work remains independently
  gated.
- Specification paths changed: this Draft, its Phase 0B evidence protocol, and
  the governing implementation plan.
- Independent review: accepted with residual by `DV-P0A-QUALITY-REVIEW`.
- New contract revision: `DV-DRAFT-4`.

## Scope

- a feature that is off by default;
- an explicit app scope: selected apps, or all apps except exclusions;
- one preferred camera whose identity survives disconnection and relaunch;
- a user-selected local destination, including an external SSD or HDD;
- short camera-and-audio clips aligned with eligible dictation attempts;
- a separate Dev Vlogs window for setup, health, review, and commands;
- local folders and metadata grouped by day and originating app;
- an explicit build command that joins chosen clips chronologically;
- a future publication layer that consumes a completed export.

## Non-goals

- continuous or hidden background recording;
- screen or system-audio capture;
- recording meetings or other people without their knowledge;
- automatic cloud upload, account sync, telemetry, or analytics;
- replacing Transcript History or Recording Cache;
- making camera success a prerequisite for dictation;
- a full nonlinear video editor in the first release;
- a HoldType capture-resolution, frame-rate, or quality preset;
- promising sensor RAW or uncompressed camera output;
- automatic publication without an explicit user action and final
  confirmation;
- changing iOS behavior;
- claiming a dependent capability accepted before its required evidence and
  residuals are closed.

## Working product vocabulary

- `DV-PRODUCT-1`: The final V1 user-facing feature name is `Dev Vlogs`.
- `DV-PRODUCT-2`: V1 exposes its commands only through the HoldType app. It
  does not define or ship a CLI or automation API.

- **Trigger app**: the external app associated with the dictation start action.
  It is identified by bundle identifier and a display-name snapshot.
- **Vlog clip**: one immutable local source video created from one eligible
  dictation attempt.
- **Vlog day**: the calendar-day collection that groups clips across trigger
  apps without moving or duplicating their source files.
- **Build**: a saved recipe containing an ordered selection of clips and an
  export policy.
- **Export**: one immutable rendered video produced by a successful build.
- **Publish**: the user-facing local artifact-preparation workflow that selects
  one recorded day and its clips, applies the Original output policy, and
  produces one local export. It does not mean remote or social publication.
- **Publication attempt**: a future destination-specific upload or post that
  references one completed export.

## Active V1 behavior

The clauses below are implementation authority. They are not evidence that a
capability already exists or has passed its acceptance scenarios.

### Enablement and setup

- `DV-ENABLE-1`: Dev Vlogs is off by default on new and existing installs.
- `DV-ENABLE-2`: Enabling the feature is an explicit action inside the Dev
  Vlogs window. It is not a system permission and must not appear as a consent
  switch in Permissions.
- `DV-ENABLE-3`: Enabling the feature does not immediately start camera or
  microphone capture.
- `DV-ENABLE-4`: First setup requires a camera choice, destination, and app
  scope before Dev Vlogs can become Ready.
- `DV-ENABLE-5`: Camera permission is requested only from an explicit
  camera-related action after the user has chosen to enable or test Dev Vlogs.
- `DV-ENABLE-6`: Disabling Dev Vlogs affects future dictation attempts. It
  stops an active vlog branch safely but does not cancel the primary dictation
  branch or delete existing clips.
- `DV-ENABLE-7`: Camera permission is optional for the main HoldType product.
  Missing or denied camera permission must not open required setup on launch,
  block dictation readiness, or appear as a microphone problem.

### App eligibility

- `DV-APP-1`: The V1 recommended and default scope is `Only selected apps`,
  with an empty list until the user adds at least one app.
- `DV-APP-2`: `All apps except excluded apps` is a secondary mode and requires
  a separate explicit selection because it has broader privacy consequences.
- `DV-APP-3`: App rules use bundle identifiers as durable identity. Display
  names and icons are presentation metadata only.
- `DV-APP-4`: The trigger app is captured before a HoldType-owned popover or
  window can replace it as the frontmost app.
- `DV-APP-5`: Eligibility and folder ownership are frozen from the trigger app
  at dictation start. A later focus change does not move the clip to another
  app folder.
- `DV-APP-6`: If HoldType cannot establish a trustworthy trigger app, the vlog
  branch does not start. It must not write the clip into a generic app folder
  that could conceal a policy mistake.
- `DV-APP-7`: HoldType-owned windows are never implicit trigger apps.

### Parallel capture behavior

- `DV-CAPTURE-1`: One explicit HoldType dictation start action may start the
  dictation branch and an eligible vlog branch.
- `DV-CAPTURE-2`: The dictation branch remains authoritative. Camera,
  destination, storage, metadata, muxing, and vlog-finalization failures must
  not block, cancel, delay indefinitely, or downgrade a usable transcription.
- `DV-CAPTURE-3`: A vlog clip contains camera video and the same microphone
  speech used by the corresponding dictation attempt. The first release does
  not introduce a second vlog-only microphone choice.
- `DV-CAPTURE-4`: HoldType must not open the microphone twice merely to create
  the vlog asset. The final implementation needs one audio-capture authority
  with explicit ownership for dictation and vlog finalization.
- `DV-CAPTURE-5`: The vlog branch follows the same user start and terminal
  action as its dictation attempt, but maintains its own success, failure, and
  recovery state.
- `DV-CAPTURE-6`: Camera recording is always visible through macOS camera
  indication plus a HoldType-owned camera state. No hidden capture is allowed.
- `DV-CAPTURE-7`: Starting a vlog branch must use a bounded preparation time.
  If the camera is slow or unavailable, dictation proceeds and HoldType records
  a compact skipped-clip reason.
- `DV-CAPTURE-8`: A vlog clip is Ready only after HoldType can open the
  finalized asset and establish playable video and audio tracks.
- `DV-CAPTURE-9`: The source clip does not contain transcript text, nearby
  context, prompts, API credentials, or provider responses in the first
  release.
- `DV-CAPTURE-10`: The selected camera and macOS negotiate the actual captured
  video format. HoldType does not request a lower resolution or frame rate for
  storage predictability, downsample the source video, or run an additional
  source-video encode. It preserves the video encoding delivered by the
  camera/system; native 1080p or another negotiated format is allowed without
  becoming a HoldType quality preset, and this clause does not promise sensor
  RAW or uncompressed capture. Camera-format behavior remains configured by the
  camera and macOS rather than a HoldType capture-quality control. Source
  finalization may change container and add the dictation audio only through a
  proven video-passthrough path. If Phase 0B cannot produce one playable source
  clip while preserving that video, the source cell fails with an exact
  platform or product dependency; HoldType must not silently transcode or
  downscale it.
- `DV-CAPTURE-11`: V1 mirrors only the live preview. Stored source video keeps
  the camera's physically correct orientation. Build-time mirroring is
  deferred.

### Camera selection and reconnection

- `DV-CAMERA-1`: The Dev Vlogs window lists currently available cameras and
  provides a bounded live setup preview only after explicit user action.
- `DV-CAMERA-2`: HoldType persists the selected camera's stable device identity
  and a display-name snapshot.
- `DV-CAMERA-3`: If the preferred camera disconnects, HoldType remembers it and
  automatically recognizes it again when the same device returns.
- `DV-CAMERA-4`: HoldType does not silently switch to another camera. A
  different device may have a different framing or privacy expectation.
- `DV-CAMERA-5`: While the preferred camera is unavailable or used by another
  app, dictation continues and the vlog branch is skipped with a visible,
  recoverable explanation.
- `DV-CAMERA-6`: A future explicit fallback-camera setting may be added, but it
  is not part of the initial contract.
- `DV-CAMERA-7`: `build-macos-apps:swiftui-patterns` is available and governs
  the window and preview work. The preview, controls, overlays, state, and
  feedback remain SwiftUI; a platform rendering adapter may be considered only
  after evidence demonstrates the exact SwiftUI limitation on supported macOS
  targets. Preview acceptance remains gated by its own lifecycle evidence, not
  by skill availability, and does not gate passive window/Off/Setup delivery.

### Destination and storage

- `DV-STORAGE-1`: The initial default destination is
  `~/Movies/HoldType Dev Vlogs`.
- `DV-STORAGE-2`: The user may choose another writable folder through a
  SwiftUI-presented system folder picker. The selection may reside on an
  external SSD or HDD.
- `DV-STORAGE-3`: HoldType persists a bookmark-backed destination identity so
  it can detect a moved, renamed, remounted, stale, or unavailable destination
  without relying only on a path string.
- `DV-STORAGE-4`: HoldType verifies destination availability, writability, and
  useful free capacity before each vlog capture.
- `DV-STORAGE-5`: If the selected destination is unavailable at start,
  HoldType does not silently fall back to internal storage. It skips only the
  vlog branch and explains how to reconnect or choose a destination.
- `DV-STORAGE-6`: If an external destination disappears during capture,
  HoldType stops the vlog branch, preserves every recoverable fragment, and
  marks the result Ready, Incomplete, or Failed truthfully. Dictation continues.
- `DV-STORAGE-7`: Active and finalizing vlog assets are protected from Dev
  Vlogs delete, cleanup, and build commands.
- `DV-STORAGE-8`: V1 does not delete vlog clips
  automatically. It shows size by day and app, warns before space is exhausted,
  and requires explicit deletion.
- `DV-STORAGE-9`: Numeric low-space warning and hard-stop thresholds are
  derived from Phase 0B produced-byte-rate and finalization-overhead evidence
  for the actual formats negotiated across the available camera matrix. They
  must not be guessed or derived from a fixed HoldType capture preset.
- `DV-STORAGE-10`: The hard stop must reserve at least one maximum-duration
  attempt under a safe bound established from measured negotiated-source
  behavior, plus measured finalization overhead. Warning capacity remains
  distinct from that hard stop. Because Phase 0B did not establish a safe
  bound, the numeric policy remains capability-gated until representative
  measurements are accepted; it must not be invented.

### Folder organization

- `DV-FOLDER-1`: The on-disk layout remains understandable in Finder without
  requiring the HoldType UI.
- `DV-FOLDER-2`: Each clip is grouped first by local calendar day and then by
  trigger app, allowing one day-wide build while keeping each app's log
  separate.
- `DV-FOLDER-3`: App folders include a sanitized display name and bundle
  identifier to avoid collisions after an app rename.
- `DV-FOLDER-4`: File names include local start time plus a stable clip ID.
  Ordering must not depend on file modification time.
- `DV-FOLDER-5`: A compact local manifest stores stable clip ID, trigger-app
  identity, creation time, duration, byte size, camera identity, media health,
  and build membership. It does not store captured speech or transcript text.
- `DV-FOLDER-6`: If the user removes or moves a source clip directly in Finder,
  HoldType marks the indexed clip missing on refresh. It does not recreate the
  file, report a false playable state, or treat the change as an internal
  deletion success.

Provisional layout:

```text
HoldType Dev Vlogs/
  2026/
    2026-08-08/
      day.json
      apps/
        Codex--app.openai.codex/
          clips/
            14-32-05--<clip-id>.mov
          clips.jsonl
        Claude--com.anthropic.claudefordesktop/
          clips/
          clips.jsonl
      builds/
        <build-id>/
          build.json
          output.mp4
```

The exact extension and manifest encoding are implementation evidence, not
settled product intent, but the human-readable day/app hierarchy is part of the
active contract.

### Review and deletion

- `DV-REVIEW-1`: The Dev Vlogs window shows days newest first, with app groups,
  clip count, total duration, and disk usage.
- `DV-REVIEW-2`: A clip offers local playback, Reveal in Finder, inclusion in
  a build, and explicit Delete when no capture or build operation owns it.
- `DV-REVIEW-3`: Excluding a clip from a build is non-destructive. Delete is a
  separate destructive action with clear scope.
- `DV-REVIEW-4`: The initial review experience may use a list and preview; it
  does not require a timeline editor.
- `DV-REVIEW-5`: Removing source clips never removes an already completed
  export. A build whose sources were removed is retained as historical
  metadata but cannot be rebuilt from missing sources.

### Build and export

- `DV-BUILD-1`: A build is always user-initiated in the initial release.
- `DV-BUILD-2`: `Build Today's Vlog…` starts with all Ready, non-excluded clips
  for the selected day in chronological order. The user can narrow the app
  scope, change clip selection, and reorder selected clips before confirming.
- `DV-BUILD-3`: A build recipe is saved before rendering and identifies its
  ordered source clip IDs and the accepted export policy in force for that
  build.
- `DV-BUILD-4`: Rendering writes a new output. It does not overwrite source
  clips or an earlier successful export.
- `DV-BUILD-5`: A failed or cancelled build leaves source clips unchanged and
  may be retried from its existing recipe.
- `DV-BUILD-6`: Direct-compatible video passthrough is desirable and may be
  measured, but no fallback is authorized when selected clips cannot be
  composed without video re-encoding. Before Build implementation, the user
  must choose between (a) one final encode that does not reduce source
  resolution or nominal frame rate and (b) failing that Build without an
  output. `DV-ACTIVE-2` chooses neither outcome. The pending Build fork does not
  block native-source capture evidence.
- `DV-BUILD-7`: V1 provides selection and reorder, but no trim or timeline.
  Square, portrait, captions, title cards, transitions, silence trimming, and
  automatic highlights are deferred.
- `DV-BUILD-8`: Every media/export operation has a bounded timeout or
  cancellable progress boundary. A retry reuses valid completed artifacts.
- `DV-BUILD-9`: V1 build and export commands are app commands only. V1 does not
  define or ship a CLI or automation API.

### Export, Share, and deferred publication

- `DV-SHARE-1`: The V1 delivery boundary is Export, Reveal in Finder, and the
  macOS Share surface. No direct publication destination is part of V1 or the
  current persistent goal.
- `DV-SHARE-2`: A build succeeds independently of publication configuration;
  V1 has no publication account setup or publication attempt state.
- `DV-SHARE-3`: Completed exports are the only future input to direct
  publication adapters. No publication behavior may be added to capture,
  source-clip, or build ownership.
- `DV-PUBLISH-3`: A future direct destination keeps credentials in Keychain,
  validates current platform limits, and uses resumable or chunked upload when
  the provider supports it.
- `DV-PUBLISH-4`: `Build & Publish…` may be one user command later, but it must
  still show the completed artifact and require final confirmation before an
  irreversible public post.
- `DV-PUBLISH-5`: Each publication attempt has its own identity and terminal
  state. An uncertain provider result must not be retried blindly because that
  can create duplicate posts.
- `DV-PUBLISH-6`: Publication status never changes source clip or export
  ownership.

The `DV-PUBLISH-*` clauses are deferred discovery notes, not V1 behavior or
authority to begin publication work.

### Dev Vlogs window and menu entry

- `DV-UI-1`: The menu bar utility group gains one item: `Dev Vlogs…`.
- `DV-UI-2`: The item opens a separate SwiftUI window titled
  `HoldType: Dev Vlogs`; the feature is not inserted as another dense Settings
  sidebar section.
- `DV-UI-3`: The window owns enablement, setup, capture health, destination,
  app rules, day/app browsing, storage summary, and local artifact preparation.
  The user-facing Publish workflow may consume only truthful local Library and
  media-owner state. Remote publication readiness, providers, accounts,
  uploads, and public-post actions remain deferred and absent.
- `DV-UI-4`: The menu bar popover remains compact. It may show a small camera
  capture or degraded-state indicator but does not expose camera, destination,
  or app-rule controls.
- `DV-UI-5`: The window uses the same broad information-architecture pattern
  as Settings: a stable sidebar for several Dev Vlogs sections and one detail
  pane. It remains a separate feature window with its own navigation and state
  ownership rather than becoming a Settings section.
- `DV-UI-6`: The complete V1 sidebar order is Overview, Capture, Applications,
  Storage, Library, Publish. Overview is the default section. Navigation
  entries become visible only when their contained workflow is useful: the
  current iteration adds Publish as the final visible destination without an
  empty Library placeholder.
- `DV-UI-7`: Dev Vlogs reports only genuine macOS permissions relevant to this
  feature, initially Camera in Capture and the existing Microphone status it
  shares with dictation when that status is useful. It does not add a separate
  Permissions navigation section. Feature enablement remains in Overview;
  destination availability and bookmark health remain Storage access states,
  not macOS permissions.
- `DV-UI-8`: Camera preview, video player, controls, layout, state, and visible
  feedback are SwiftUI. Platform APIs remain narrow non-visual adapters.
- `DV-UI-9`: Publish uses Settings-quality grouped presentation for Source
  Day, Clips, Output, Build Progress, and Result as appropriate to its injected
  state. The Release path remains `No recordings` until a real Library owner
  supplies data. Deterministic previews and tests cover no recordings, empty
  day, populated selection, invalid or missing sources, ready, building,
  cancelled, failed, and completed artifact states. `Original` is the only
  output policy. Create Video, Cancel, Play, Reveal, and Share are visible only
  when the injected state owner explicitly enables the applicable action.

## Product invariants

- Dev Vlogs is off by default.
- No camera capture without an explicit HoldType dictation action, enabled
  feature, eligible trigger app, system permission, available preferred camera,
  and ready destination.
- No hidden or continuous camera recording.
- Dictation success never depends on vlog success.
- The preferred camera is remembered but never silently substituted.
- An unavailable external destination never causes an undisclosed internal
  fallback.
- Vlog source files stay separate from Recording Cache, Transcript History,
  and provider-retry audio.
- V1 stores no transcript text beside vlog clips.
- V1 mirrors preview only; stored source orientation remains physically
  correct.
- HoldType does not downsample or additionally encode source video; source
  finalization preserves the negotiated video through a proven passthrough
  path or fails truthfully.
- Default logs contain no video, audio, transcripts, paths, app content,
  prompts, credentials, or provider payloads.
- Build is non-destructive; clip deletion is explicit.
- V1 commands are app-only and the user-facing Publish workflow stops at local
  Export, Reveal in Finder, and macOS Share; direct publication remains
  deferred.
- All visible UI is SwiftUI.

## Adjacent contract reconciliation

Phase 0C is complete and preserved through `DV-ACTIVE-2`:

- `privacy-and-permissions.md` makes Camera optional to core HoldType and adds
  the explicit local Dev Vlogs camera/same-dictation-audio archive exception.
- `settings-and-secret-storage.md` keeps Dev Vlogs out of Settings and
  Keychain, while allowing small local non-secret feature preferences.
- `menu-bar-app-shell.md` adds `Dev Vlogs…`; compact status may follow only
  with its later truthful state owner.
- `microphone-text-input.md` defines a bounded read lease on the already
  finalized authoritative dictation artifact without changing provider or
  output ownership.
- `recording-durability-and-interruption.md` gives vlog media a separate owner,
  recovery boundary, and explicit Dev Vlogs Delete authority.

These clauses activate implementation boundaries, not acceptance claims.
Dependent runtime and QA residuals remain explicit in the acceptance map.

## Failure and recovery policy

| Condition | Dev Vlogs result | Dictation result |
| --- | --- | --- |
| Camera permission missing or denied | Skip clip; show camera recovery in Dev Vlogs | Continue normally |
| Preferred camera disconnected | Remember device; skip clip until it returns or user selects another | Continue normally |
| Camera busy in another app | Skip clip with compact explanation | Continue normally |
| Trigger app not eligible or unknown | Do not start vlog branch | Continue normally |
| Destination missing or read-only | Skip clip; no silent fallback | Continue normally |
| Storage below hard threshold | Skip clip; show capacity action | Continue normally |
| External drive disconnects during capture | Stop vlog, preserve recoverable fragments, classify truthfully | Continue normally |
| Video starts late | Preserve truthful media bounds; do not delay dictation indefinitely | Continue normally |
| Audio/video mux fails | Preserve owned source pieces and offer local Retry Finalize | Continue transcription and output |
| App quits or crashes | Recover only validated local fragments on next launch; never publish | Existing dictation durability contract applies |
| Build fails or is cancelled | Preserve sources and recipe; allow retry | No effect |
| Publication result is uncertain | Keep export; require confirmation before a new attempt | No effect |

## Product state and data implications

The feature-level readiness states are:

- Off;
- Setup required;
- Ready;
- Degraded: camera unavailable;
- Degraded: destination unavailable;
- Degraded: low storage.

A vlog attempt has its own lifecycle:

- not eligible;
- preparing;
- capturing;
- finalizing;
- ready;
- incomplete;
- failed;
- explicitly deleted.

A build has its own lifecycle:

- draft;
- building;
- ready;
- failed;
- cancelled.

A future publication attempt has its own lifecycle:

- awaiting confirmation;
- authenticating;
- uploading;
- processing;
- published;
- failed;
- outcome uncertain.

The exact persisted schema is deferred. Stable IDs and source ownership are
required so folders can be rebuilt into the local index without inventing or
duplicating clips.

## Recommended implementation direction

This section is research guidance, not normative implementation authority.

### Capture ownership

The current macOS recorder uses `AVAudioRecorder` and already gives each
dictation attempt durable audio ownership before provider work. Opening the
same microphone independently from a second movie recorder would create device
contention and two clocks.

The lowest-risk first spike is therefore:

1. Keep one authoritative dictation audio capture.
2. Start a camera-only AVFoundation capture branch after the vlog eligibility
   snapshot.
3. Record monotonic start and end offsets for both branches.
4. Give the vlog finalizer a temporary ownership lease on the same completed
   dictation audio artifact.
5. Mux the camera video and that audio into the finalized vlog source clip.
6. Release the vlog audio lease only after the source clip is playable or the
   vlog branch reaches a truthful recoverable failure.

This keeps the product branches independent while avoiding two microphone
owners. A feasibility spike must measure camera start latency, drift, and
failure behavior before this becomes contract text.

### Native media path

- AVFoundation capture sessions support camera and microphone inputs plus movie
  or sample-buffer outputs.
- The preferred camera can be found by stable device ID and monitored through
  connect/disconnect notifications.
- Fragmented QuickTime writing materially improves partial-file recovery. Apple
  documents a 10-second default fragment interval for movie capture and
  recommends 10 seconds or greater for external storage.
- Phase 0B must establish whether native composition or another platform path
  can change the container and add dictation audio while copying the negotiated
  video track without decoding, encoding, downsampling, or reducing frame rate.
- The smallest preservation evidence compares camera-only and finalized source
  video tracks: realized dimensions, nominal frame rate, codec/media subtype,
  relevant format description, timestamp bounds, and container/track/sample
  evidence sufficient to distinguish copied encoded video from a re-encode.
  The exact API is implementation evidence rather than contract text.
- Direct-compatible Build passthrough is worth measuring, but composition of
  incompatible source clips remains governed by the unresolved `DV-BUILD-6`
  fork.
- FFmpeg remains a useful development/reference tool, but shipping it in the
  first product version adds binary size, licensing, update, and subprocess
  boundaries that the native path does not yet require.

### Destination ownership

- Use a SwiftUI system folder picker for the destination.
- Persist bookmark data and refresh stale bookmarks.
- Observe mount and unmount changes, but revalidate the exact bookmark and
  writability before every capture rather than trusting a mount notification.
- Query useful available capacity and compute a conservative per-attempt
  requirement from the safe measured bound for actual negotiated source
  behavior and maximum dictation length.
- Write active files under a temporary name, use fragmented media, validate
  tracks, then atomically publish the final clip name where the file system
  supports it.

### Trigger-app ownership

Use the frontmost application's bundle identifier captured at the initiating
event. Display name and icon can be refreshed for presentation, but folder and
policy identity stay keyed by bundle ID.

### Build and publication ownership

Build and publication should be separate commands backed by separate state
owners. This permits:

- local builds without accounts;
- retrying a render without re-recording;
- publishing one export to multiple destinations;
- changing a platform adapter without changing clip storage;
- handling ambiguous uploads without duplicate public posts.

## Native-source media and storage budget

No fixed source bitrate or file-size estimate is authoritative because the
selected camera and macOS negotiate the realized source format. Phase 0B must
measure camera-only bytes, finalized source-clip bytes, bytes per recorded
second, peak temporary ownership, and finalization overhead for every available
camera and realized format in the controlled matrix.

Those measurements may establish a conservative safe bound for one
maximum-duration attempt. If they do not, the numeric warning and hard-stop
policy remains an explicit capability-gated residual. HoldType must not obtain
predictable storage by lowering source resolution/frame rate or adding a
source-video encode.

## Research synthesis

### What analogous products establish

| Product or source | Useful signal | What HoldType should not copy |
| --- | --- | --- |
| Tella clips | Short separately recorded clips can be reviewed and combined into one coherent video with less re-recording pressure. | Cloud-first project ownership and a full editor are not required for the local MVP. |
| Screen Studio | Camera and microphone device selection, an explicit preview, and access to separate raw tracks are understandable creator workflows. | Continuous screen recording and post-production layout controls are outside the initial scope. |
| OBS Studio | A configurable recording path, source model, hardware encoders, and replay-buffer concepts prove the value of destination and capture controls. | Its dense broadcasting configuration is the opposite of the focused HoldType workflow. |
| Rewind, historically | Local-first ambient archives are compelling. Public discussion repeatedly raises storage, CPU, bystander-consent, and trust concerns. | Continuous capture and vague background behavior conflict with this feature's explicit per-dictation boundary. |
| Descript | Clips, sequences, and export are product entities rather than one destructive file operation. | Account-backed editing and publishing are not prerequisites for local builds. |

No reviewed product combines all four parts of this proposal: dictation-defined
clip boundaries, camera-only developer moments, per-app eligibility, and a
local day/app archive. That combination is the product differentiation.

### Highest-signal UX risks

| Rank | Problem | Severity | Frequency signal | Confidence | Recommended product move |
| --- | --- | --- | --- | --- | --- |
| 1 | A user cannot confidently tell when the camera is recording or which apps can trigger it. | Critical | Common concern around ambient recorders | High | Off by default, selected-app scope, explicit camera state, no hidden capture. |
| 2 | Camera or storage failure makes dictation slower or unreliable. | Critical | Direct architectural risk in HoldType | High | Independent vlog state and bounded best-effort start; dictation never awaits vlog completion. |
| 3 | External drive loss corrupts the active clip. | High | Repeated recorder anecdotes; documented fragment benefit | High | Fragmented source files, mount/capacity checks, truthful partial recovery, no fallback. |
| 4 | Local video silently consumes large amounts of disk. | High | Repeated ambient-recorder feedback | High | Visible day/app sizes, warning and hard thresholds, explicit deletion. |
| 5 | Camera selection changes after a USB or Continuity device disconnects. | Medium | Normal capture-device lifecycle | High | Persist stable device ID; remember unavailable camera; no silent substitution. |
| 6 | A direct publish button becomes brittle as social APIs and account tiers change. | Medium | Current provider limits and paid access vary | High | Ship export first; isolate destination adapters and publication attempts later. |

### Source map

Public product sources:

- [Tella: How to use clips](https://www.tella.tv/help/recording/use-clips)
- [Screen Studio: Webcam & Microphone](https://screen.studio/guide/webcam-microphone)
- [Screen Studio: Extracting raw recording files](https://screen.studio/guide/extracting-raw-recording-files)
- [OBS Studio overview](https://obsproject.com/kb/obs-studio-overview)
- [Descript: Layer and clip overview](https://help.descript.com/hc/en-us/articles/10301481327757-Layer-and-clip-overview)
- [Historical Hacker News discussion of Rewind](https://news.ycombinator.com/item?id=33421751)

Primary platform sources:

- [Apple: Setting up a capture session](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)
- [Apple: Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [Apple: AVCaptureDevice](https://developer.apple.com/documentation/avfoundation/avcapturedevice)
- [Apple: Movie fragment interval](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput/moviefragmentinterval)
- [Apple: Frontmost application](https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication)
- [Apple: Volume mount notification](https://developer.apple.com/documentation/appkit/nsworkspace/didmountnotification)
- [Apple: Useful available volume capacity](https://developer.apple.com/documentation/foundation/urlresourcevalues/volumeavailablecapacityforimportantusage)
- [Apple: SwiftUI file selection and persistent access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Apple: AVAssetExportSession](https://developer.apple.com/documentation/avfoundation/avassetexportsession)
- [Apple: macOS sharing picker](https://developer.apple.com/documentation/appkit/nssharingservicepicker)
- [FFmpeg concat demuxer reference](https://ffmpeg.org/ffmpeg-formats.html#concat)
- [X media upload best practices](https://docs.x.com/x-api/media/quickstart/best-practices)
- [X API overview and access model](https://docs.x.com/x-api/overview)
- [YouTube resumable upload protocol](https://developers.google.com/youtube/v3/guides/using_resumable_upload_protocol)

Repository evidence inspected after the provisional Spec Basis:

- `HoldType/Services/AudioRecorderService.swift` and
  `HoldType/Services/AudioRecorderEngine.swift`: the current recorder has one
  `AVAudioRecorder` owner and exact-once audio finalization.
- `HoldType/Services/DictationSessionController.swift`: dictation durability,
  provider dispatch, and cache ownership are already tightly coordinated and
  must stay protected.
- `HoldType/HoldTypeApp.swift` and `HoldType/MenuBarView.swift`: HoldType already
  has a compact menu bar surface and separate normal windows for feature-heavy
  workflows.
- `HoldType/Models/AppSettings.swift`: camera, destination, and app policy are
  new state domains rather than existing setting variants.

Signal was weak for products that automatically start a webcam from dictation
events or organize the resulting clips by frontmost app. That absence is why
the first release needs a technical capture spike and a small user workflow
prototype rather than copying an established end-to-end pattern.

## Delivery phases

### Phase 0: contract and feasibility — complete with preserved residuals

- `DV-D01` through `DV-D13` are accepted and `DV-ACTIVE-2` is active.
- Phase 0B established bounded supporting evidence but did not accept capture,
  protected-scope storage, live preview, or quantitative thresholds.
- No Phase 0B expansion is admitted without separate explicit user approval.

### Phase 1: foundation and setup — accepted

- Release-path `Dev Vlogs…` menu entry;
- separate normal SwiftUI window titled `HoldType: Dev Vlogs`;
- Overview is the default section;
- truthful off-by-default Off/Setup state;
- opening or reopening the window never captures, starts preview, or requests
  Camera permission;
- camera preview, numeric storage thresholds, and mux preservation are not
  dependencies for this smallest slice.

### Publish presentation — current Iteration 1

- add Publish as the final currently visible sidebar destination;
- do not add an empty Library placeholder before its real owner exists;
- ship a truthful Release no-recordings state with Original as the only output
  policy and no media or remote-publication action;
- complete the future Source Day, Clips, Output, Build Progress, and Result
  hierarchy through deterministic preview/test inputs only;
- keep every action absent unless the injected state owner explicitly enables
  it.

### Phase 2: one-clip capture

- app eligibility, camera, destination, bounded preparation, and same-audio
  finalization;
- zero or one playable clip per eligible attempt;
- no capture acceptance until strict preservation, the shipping audio lease,
  and real product integration pass their scenarios.

### Phase 3: library, review, and deletion

- day/app library, playback, Reveal, inclusion/exclusion, and explicit Delete;
- exact separate vlog ownership and protected active/finalizing/build sources;
- no Transcript History or Recording Cache ownership.

### Phase 4: build, export, and Share

- saved recipes, selection/reorder, deterministic output, retry/cancel, Reveal,
  and macOS Share;
- no incompatible-source fallback until the user resolves `DV-BUILD-6`;
- direct publication remains outside the goal.

### Needs deeper research

- measured camera preparation/start latency and the numeric V1 product budget;
- measured audio/video offset and drift across short, typical, and
  maximum-duration captures;
- actual byte rate and finalization overhead needed to derive the low-space
  warning and hard-stop thresholds;
- whether each available camera can produce a playable finalized source clip
  with the negotiated video preserved without an additional HoldType encode;
- which final Build behavior the user chooses under `DV-BUILD-6` when
  selected clips cannot be composed by passthrough;
- the right preview/indicator balance during frequent short captures;
- real Continuity Camera and multi-camera device identity behavior;
- the SwiftUI-first preview lifecycle on supported macOS targets; the required
  UI skill is available, while live frames, Stop, mirroring, release, and
  reacquisition remain unproven.

## Acceptance and evidence mapping

These stable IDs govern implementation acceptance. An implementation-ready row
authorizes work; it does not claim that the capability is implemented,
accepted, or released.

| Capability / acceptance IDs | Implementation readiness | Acceptance evidence still required | Current residual |
| --- | --- | --- | --- |
| Setup: `DV-ACC-ENABLE-1`, `DV-ACC-UI-1` | Ready for Phase 1: Release `Dev Vlogs…`, separate normal SwiftUI window, Overview default, truthful Off/Setup. | Product tests and Computer Use QA for menu/window opening, default selection, Off/Setup truth, reopen behavior, and proof that passive opening neither captures nor requests Camera. | None from Phase 0B. Preview and numeric thresholds are not dependencies. |
| Capture: `DV-ACC-APP-1`, `DV-ACC-CAMERA-1`, `DV-ACC-CAPTURE-1`, `DV-ACC-MEDIA-1` | Contract-ready, but acceptance-gated for Phase 2. | Real product proof of bundle-ID eligibility, preferred-camera lifecycle, one shipping microphone owner/read lease, exact-once playable `1V/1A` output, strict source preservation, independent dictation behavior, and truthful failure. | R09: playable camera `1V/0A`, playable final `1V/1A`, passthrough complete, strict preservation `reading_failed`, Ready=0. W10 is unreviewed support-only. UI R01 has no live-frame/Stop/reacquisition proof. Quantitative data are incomplete. |
| Storage: `DV-ACC-STORAGE-1` | Mechanics may be implemented incrementally; protected-scope and numeric-policy acceptance remain gated. | Bookmark/destination/no-fallback/interruption/recovery product QA with protected adjacent owners unchanged; measured safe inputs before numeric warnings or hard stops. | Controlled mechanics succeeded, but R05 changed protected metadata and the cause is unknown. No protected-scope pass; byte-rate and overhead dataset incomplete. |
| Library: `DV-ACC-LIBRARY-1` | Ready only after its archive owners exist; separate ownership clauses are active now. | Product QA for day/app hierarchy, stable IDs, truthful size/health, Finder reconciliation, active-file protection, explicit exact Delete, reconstruction, and absence of transcript persistence. | No product library or exact-delete acceptance exists. |
| Publish UI: `DV-ACC-PUBLISH-UI-1` | Ready independently for a final navigation row, truthful no-recordings Release state, and deterministic presentation inputs. | Focused navigation/state/action tests, macOS build, Computer Use navigation to Publish, and visual comparison with the accepted Settings-quality baseline. | Library/media/build owners remain absent, so Release runtime must not expose fake days, clips, progress, results, or actions. |
| Build/share: `DV-ACC-BUILD-1`, `DV-ACC-SHARE-1` | Phase 4 only after accepted library/capture inputs; direct-compatible path may proceed under later packet. | Deterministic order/output, cancel/retry, missing sources, no overwrite, playable result, unchanged sources, Reveal, Share, and absence of publication state. | `DV-BUILD-6` still requires the user only for incompatible-source fallback; no Build/share product QA exists. |

## Resolved decisions and remaining unknowns

The user resolved the source-quality portion of `DV-D05` on 2026-08-08.
The incompatible-source Build fallback in `DV-BUILD-6` remains a separate
material product fork:

| Decision | Accepted V1 result |
| --- | --- |
| `DV-D01` | Overview first; Overview, Capture, Applications, Storage, Library, Publish. Publish is final and means local artifact preparation; remote publication remains absent. |
| `DV-D02` | Selected apps is recommended/default; all-apps-with-exclusions is secondary. |
| `DV-D03` | Trigger app is frozen at start; later focus changes do not stop or move the clip. |
| `DV-D04` | The dictation microphone is the only V1 audio source. |
| `DV-D05` | Preserve the camera/macOS-negotiated source without a HoldType resolution/FPS downgrade or additional source-video encode. No HoldType capture-quality selector is added; native 1080p or another negotiated format is allowed without promising sensor RAW. |
| `DV-D06` | Mirror preview only; source remains physically correct; build-time mirroring is deferred. |
| `DV-D07` | Numeric low-space thresholds come from measured negotiated-source byte rate and overhead; the hard stop reserves one maximum-duration attempt under a safe measured bound plus finalization overhead, or remains capability-gated until a safe bound is established. |
| `DV-D08` | V1 has no automatic retention or deletion. |
| `DV-D09` | Build supports selection and reorder, with no trim or timeline. |
| `DV-D10` | V1 persists no transcript text beside clips. |
| `DV-D11` | V1 uses app commands only, with no CLI. |
| `DV-D12` | V1 delivery stops at Export, Reveal in Finder, and macOS Share. |
| `DV-D13` | The final V1 name is `Dev Vlogs`. |

All other `DV-D01` through `DV-D13` decisions remain unchanged. The
remaining unknowns are:

- `DV-EU-1`: measured camera preparation/start latency and the numeric V1
  product budget derived from it;
- `DV-EU-2`: measured initial audio/video offset and maximum drift over short,
  typical, and maximum-duration attempts;
- `DV-EU-3`: measured produced byte rate and finalization overhead used to set
  numeric warning and hard-stop capacity;
- `DV-EU-4`: whether the controlled hardware/storage matrix proves one
  playable source clip per applicable cell while preserving the negotiated
  source video without HoldType downsampling or re-encoding;
- `DV-EU-5`: the supported SwiftUI-first preview lifecycle. Skill availability
  is resolved; UI R01 remains terminal `not_available` without live-frame,
  Stop, mirroring, release, or reacquisition evidence.

`DV-BUILD-6` remains a real user decision: when direct-compatible passthrough
cannot compose the selected clips, choose either one final encode without
reducing source resolution or nominal frame rate, or fail the Build. Phase 0B
may gather compatibility evidence but must not choose this fallback.

Phase 0B records these results without inventing thresholds. `DV-ACTIVE-2`
classifies them as capability-scoped residuals; none blocks the independent
Phase 1 Off/Setup slice.
