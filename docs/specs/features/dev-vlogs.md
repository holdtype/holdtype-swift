# Dev Vlogs

Status: Decision-complete Draft for Phase 0B evidence; not implementation
authority.

Contract revision: `DV-DRAFT-3`.

Revision note: `DV-DRAFT-3` records the user's accepted `DV-D01` through
`DV-D13` decisions and pins the evidence still required before activation. It
does not authorize product implementation; Phase 0B feasibility and measurement
evidence plus Phase 0C reconciliation remain mandatory.

Implementation planning:
[`docs/dev-vlogs-implementation-plan.md`](../../dev-vlogs-implementation-plan.md).

Change mode: scoped `evolve` for accepted Draft decisions; delivery remains
discovery-only until a later Active revision.

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

The user has authorized discovery and a first-pass specification only. No
product implementation is authorized in this phase.

Authorized draft domains:

- feature enablement and eligibility;
- camera selection and camera capture;
- local vlog storage and app-based organization;
- clip review, build, export, and future publication concepts;
- the separate Dev Vlogs window and its menu entry.

Protected adjacent domains:

- microphone dictation, transcription, correction, translation, and text
  delivery;
- recording durability, Transcript History, and Recording Cache ownership;
- the current menu bar status hierarchy;
- the genuine-system-permission boundary in Permissions;
- Keychain, diagnostics, updates, and all iOS behavior.

The current privacy contract forbids persistent audio outside Recording Cache
and bounded recovery ownership. This draft does not override that rule. Before
implementation, an accepted evolution must add one narrowly named Dev Vlogs
archive exception while preserving all existing dictation-cache defaults and
cleanup behavior.

### Contract Delta

- Change ID: `DV-DELTA-DRAFT-3-D01-D13`.
- Change mode: scoped `evolve` inside the Dev Vlogs Draft.
- Authorized by: user acceptance of `DV-D01` through `DV-D13` on 2026-08-08.
- Domain and clause IDs: `DV-PRODUCT-1`–`DV-PRODUCT-2`, `DV-UI-6`,
  `DV-APP-1`–`DV-APP-5`,
  `DV-CAPTURE-3`–`DV-CAPTURE-4`, `DV-CAPTURE-9`–`DV-CAPTURE-11`,
  `DV-STORAGE-8`–`DV-STORAGE-10`, `DV-BUILD-2`,
  `DV-BUILD-6`–`DV-BUILD-9`, and `DV-SHARE-1`–`DV-SHARE-3`.
- Previous behavior: these points were recommendations or unresolved product
  decisions in `DV-DRAFT-2`.
- New behavior: the V1 decisions are accepted Draft behavior; only the
  explicitly evidence-dependent feasibility and numeric-threshold questions
  remain open.
- Evidence basis: the accepted user decision set, the implementation plan's
  Section 11 decision brief, and the Phase 0B protocol at
  [`docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md`](../../qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md).
- Compatibility classification: additive Draft evolution; no shipped behavior,
  adjacent Active contract, or release baseline changes.
- Adjacent domains checked: dictation, transcription and output, History,
  Recording Cache, shared Settings, Permissions, Keychain, diagnostics,
  updates, unrelated menu behavior, iOS, and website/marketing remain
  protected.
- QA and design impact: Phase 0B collects feasibility and measurement evidence;
  UI prototype work remains blocked until `build-macos-apps:swiftui-patterns`
  is available. No UI is designed by this delta.
- Specification paths changed: this Draft only; the separate Phase 0B protocol
  is evidence guidance, not product authority.
- Independent review: pending `DV-P0A-REVIEW`.
- New contract revision: `DV-DRAFT-3`.

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
- automatic publication without an explicit user action and final
  confirmation;
- changing iOS behavior;
- implementing this draft before its unknowns are reconciled.

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
  export preset.
- **Export**: one immutable rendered video produced by a successful build.
- **Publication attempt**: a future destination-specific upload or post that
  references one completed export.

## Accepted Draft behavior

The clauses below record accepted V1 intent but remain Draft evidence until
Phase 0B completes and Phase 0C reconciles the affected Active contracts.

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
- `DV-CAPTURE-10`: The V1 source-preset candidate is fixed 1280x720 at 30
  frames per second with H.264 video and AAC audio. It becomes accepted source
  quality only if Phase 0B measurements support it and Phase 0C records that
  evidence; this Draft does not predetermine the measurement result.
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
- `DV-CAMERA-7`: Any live preview feasibility work must wait until
  `build-macos-apps:swiftui-patterns` is available. The preview, controls,
  overlays, state, and feedback remain SwiftUI; a platform rendering adapter
  may be considered only after the required evidence demonstrates a SwiftUI
  limitation on supported macOS targets.

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
  derived from Phase 0B produced-byte-rate and finalization-overhead evidence.
  They must not be guessed or fixed before that evidence is reconciled.
- `DV-STORAGE-10`: The hard stop must reserve at least one maximum-duration
  attempt at the accepted source preset plus measured finalization overhead.
  Warning capacity remains distinct from that hard stop.

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
draft contract.

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
  ordered source clip IDs and export preset.
- `DV-BUILD-4`: Rendering writes a new output. It does not overwrite source
  clips or an earlier successful export.
- `DV-BUILD-5`: A failed or cancelled build leaves source clips unchanged and
  may be retried from its existing recipe.
- `DV-BUILD-6`: The V1 export candidate is 1280x720 at 30 frames per second
  with H.264 video and AAC audio, contingent on Phase 0B evidence and Phase 0C
  acceptance alongside the source-preset decision.
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
  app rules, day/app browsing, storage summary, and builds. Publication
  readiness may appear only in a separately authorized deferred delivery.
- `DV-UI-4`: The menu bar popover remains compact. It may show a small camera
  capture or degraded-state indicator but does not expose camera, destination,
  or app-rule controls.
- `DV-UI-5`: The window uses the same broad information-architecture pattern
  as Settings: a stable sidebar for several Dev Vlogs sections and one detail
  pane. It remains a separate feature window with its own navigation and state
  ownership rather than becoming a Settings section.
- `DV-UI-6`: The V1 sidebar order is Overview, Capture, Applications, Storage,
  Library, Builds, Permissions. Overview is the default section. Publishing is
  absent until a separately authorized deferred delivery exists.
- `DV-UI-7`: The Dev Vlogs Permissions section reports only genuine macOS
  permissions relevant to this feature, initially Camera and the existing
  Microphone status it shares with dictation. Feature enablement remains in the
  feature overview or capture section. Destination availability and bookmark
  health are storage access states, not macOS permissions.
- `DV-UI-8`: Camera preview, video player, controls, layout, state, and visible
  feedback are SwiftUI. Platform APIs remain narrow non-visual adapters.

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
- Default logs contain no video, audio, transcripts, paths, app content,
  prompts, credentials, or provider payloads.
- Build is non-destructive; clip deletion is explicit.
- V1 commands are app-only and stop at Export, Reveal in Finder, and macOS
  Share; direct publication remains deferred.
- All visible UI is SwiftUI.

## Required contract reconciliation before implementation

This draft may become implementation authority only after a later accepted
revision reconciles the following active contracts:

- `privacy-and-permissions.md`: add optional camera permission and the explicit
  local Dev Vlogs audio/video archive exception without weakening normal
  dictation retention.
- `settings-and-secret-storage.md`: keep the feature out of the crowded
  Settings sidebar while defining any small cross-feature preferences that
  truly belong in shared settings.
- `menu-bar-app-shell.md`: add the `Dev Vlogs…` utility entry and compact
  capture/degraded indication without expanding the popover into a control
  panel.
- `microphone-text-input.md`: define the bounded shared-audio lease that lets a
  vlog finalizer use the same completed dictation audio without changing
  transcription ownership.
- `recording-durability-and-interruption.md`: establish whether vlog media gets
  an analogous but separate durability contract; it must not become a second
  owner inside Transcript History.

Phase 0C must advance this contract beyond `DV-DRAFT-3`, record the Phase 0B
evidence, reconcile the protected Active contracts above, add the final
acceptance map, and explicitly mark a new revision Active. Until then, this
Draft cannot authorize implementation.

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
- A uniform source preset makes chronological assembly predictable.
- AVFoundation compositions plus export sessions are sufficient for a first
  native concatenate-and-export path.
- FFmpeg remains a useful development/reference tool, but shipping it in the
  first product version adds binary size, licensing, update, and subprocess
  boundaries that the native path does not yet require.

### Destination ownership

- Use a SwiftUI system folder picker for the destination.
- Persist bookmark data and refresh stale bookmarks.
- Observe mount and unmount changes, but revalidate the exact bookmark and
  writability before every capture rather than trusting a mount notification.
- Query useful available capacity and compute a conservative per-attempt
  requirement from the selected capture preset and maximum dictation length.
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

## Candidate media and storage budget

For a 720p H.264 source at roughly 2-5 Mbps plus 128 Kbps AAC audio, the
calculated storage range is approximately:

- 16-39 MB per recorded minute;
- 1.0-2.3 GB per recorded hour;
- 0.5-1.2 GB for thirty one-minute clips in a day;
- 0.25-0.58 GB for one maximum 15-minute attempt.

These are planning estimates, not measured HoldType results. Phase 0B must
measure real files from the built-in camera, a USB camera when available, and
connected iPhone Continuity Camera before source quality, warning, and
hard-stop thresholds are accepted. No planning estimate in this section is a
numeric product threshold.

The 720p H.264/AAC direction is a pragmatic first default because Apple's
1280x720 export preset produces H.264 with AAC, and X recommends 720p H.264
with AAC for ordinary video upload. Higher quality and portrait/square exports
belong in explicit later presets.

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
- [Apple: 1280x720 H.264/AAC export preset](https://developer.apple.com/documentation/avfoundation/avassetexportpreset1280x720)
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

### Phase 0: contract and feasibility

- measure the evidence-dependent questions that remain after `DV-D01` through
  `DV-D13`;
- measure camera start latency and audio/video drift;
- verify one-audio-owner capture and muxing;
- test internal and external destinations, unplug, low-space, sleep, quit, and
  camera-disconnect behavior;
- measure actual storage and CPU impact at candidate presets;
- use the bounded Phase 0B protocol linked by this Draft;
- keep UI preview feasibility and prototype activity blocked until
  `build-macos-apps:swiftui-patterns` is available.

### Phase 1: local clip MVP

- off-by-default enablement;
- camera permission, picker, remembered identity, and test preview;
- selected-app scope and all-apps-with-exclusions mode;
- destination selection and health;
- parallel best-effort clips with day/app folders;
- list, playback, Reveal in Finder, exclusion, and Delete;
- no build and no publication required for capture MVP acceptance.

### Phase 2: build and export

- saved build recipes;
- chronological selection and reorder;
- native 720p H.264/AAC export;
- progress, cancel, retry, preview, Reveal in Finder, and Share;
- no direct social account required.

### Phase 3: publication adapters

- destination-specific authentication and Keychain storage;
- provider validation, chunked/resumable upload, processing, and idempotency;
- explicit publication confirmation;
- optional `Build & Publish…` orchestration after the separate steps are
  reliable.

### Needs deeper research

- measured camera preparation/start latency and the numeric V1 product budget;
- measured audio/video offset and drift across short, typical, and
  maximum-duration captures;
- actual byte rate and finalization overhead needed to derive the low-space
  warning and hard-stop thresholds;
- whether measured 720p/30 H.264/AAC results support accepting the fixed V1
  candidate;
- the right preview/indicator balance during frequent short captures;
- real Continuity Camera and multi-camera device identity behavior;
- the SwiftUI-first preview path on supported macOS targets after the required
  UI skill is available.

## Acceptance and evidence mapping

These stable IDs frame later implementation acceptance. Phase 0B evidence is
governed by the linked protocol; passing a Phase 0B gate does not activate this
Draft.

| Acceptance ID | Required behavior | Phase 0B evidence |
| --- | --- | --- |
| `DV-ACC-ENABLE-1` | Fresh installs stay Off; enable/disable is explicit; passive window opening never captures. | Not exercised by the debug-only spike. |
| `DV-ACC-APP-1` | Selected/default, excluded, unknown, renamed, duplicate-name, HoldType-focus, and menu-start trigger cases preserve bundle-ID policy and the start-time snapshot. | `DV-P0B-E01`; later product QA required. |
| `DV-ACC-CAMERA-1` | Preferred-device identity, no silent fallback, busy/disconnect/reconnect, and Continuity Camera behavior are truthful. | `DV-P0B-E01`, `DV-P0B-E02`, `DV-P0B-E04`. |
| `DV-ACC-CAPTURE-1` | One microphone owner produces at most one playable audio/video clip for an eligible attempt; every vlog failure leaves dictation usable. | `DV-P0B-E02`, `DV-P0B-E04`, `DV-P0B-E07`. |
| `DV-ACC-MEDIA-1` | Candidate quality, preparation, sync/drift, resource use, byte rate, and finalization overhead are measured before numeric product thresholds are accepted. | `DV-P0B-E06`. |
| `DV-ACC-STORAGE-1` | Internal/external destination handling, useful capacity, no silent fallback, unplug/interruption, and truthful recovery are demonstrated. | `DV-P0B-E03`, `DV-P0B-E04`. |
| `DV-ACC-LIBRARY-1` | Day/app hierarchy, stable IDs, truthful sizes, active-file protection, explicit Delete, and index reconstruction work without transcript persistence. | Later product QA required. |
| `DV-ACC-BUILD-1` | Selection/reorder, deterministic output, cancel/retry, missing-source handling, no overwrite, playable output, and unchanged sources are demonstrated. | Capture/mux feasibility only in `DV-P0B-E02`; later build QA required. |
| `DV-ACC-SHARE-1` | V1 exposes Export, Reveal in Finder, and macOS Share only; no direct adapter or publication state exists. | Later product QA required. |
| `DV-ACC-UI-1` | Overview opens first; delivered sections follow the accepted order; all visible UI is SwiftUI. | `DV-P0B-E05` remains blocked until the required skill is available. |

## Resolved decisions and evidence-dependent unknowns

The user resolved every V1 product choice in the decision brief on 2026-08-08:

| Decision | Accepted Draft result |
| --- | --- |
| `DV-D01` | Overview first; Overview, Capture, Applications, Storage, Library, Builds, Permissions; Publishing absent until deferred delivery. |
| `DV-D02` | Selected apps is recommended/default; all-apps-with-exclusions is secondary. |
| `DV-D03` | Trigger app is frozen at start; later focus changes do not stop or move the clip. |
| `DV-D04` | The dictation microphone is the only V1 audio source. |
| `DV-D05` | Fixed 720p/30 H.264/AAC is the V1 candidate, contingent on Phase 0 evidence. |
| `DV-D06` | Mirror preview only; source remains physically correct; build-time mirroring is deferred. |
| `DV-D07` | Numeric low-space thresholds come from measured byte rate and overhead; the hard stop reserves at least one maximum-duration attempt plus finalization overhead. |
| `DV-D08` | V1 has no automatic retention or deletion. |
| `DV-D09` | Build supports selection and reorder, with no trim or timeline. |
| `DV-D10` | V1 persists no transcript text beside clips. |
| `DV-D11` | V1 uses app commands only, with no CLI. |
| `DV-D12` | V1 delivery stops at Export, Reveal in Finder, and macOS Share. |
| `DV-D13` | The final V1 name is `Dev Vlogs`. |

No unresolved product-choice question remains from `DV-D01` through
`DV-D13`. The remaining unknowns are evidence-dependent:

- `DV-EU-1`: measured camera preparation/start latency and the numeric V1
  product budget derived from it;
- `DV-EU-2`: measured initial audio/video offset and maximum drift over short,
  typical, and maximum-duration attempts;
- `DV-EU-3`: measured produced byte rate and finalization overhead used to set
  numeric warning and hard-stop capacity;
- `DV-EU-4`: whether the controlled hardware/storage matrix supports accepting
  fixed 720p/30 H.264/AAC for V1;
- `DV-EU-5`: the supported SwiftUI-first preview path, pending availability of
  `build-macos-apps:swiftui-patterns` and bounded feasibility evidence.

Phase 0B records these results without inventing thresholds. Phase 0C must
classify and reconcile them before any Active implementation revision.
