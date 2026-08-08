# Dev Vlogs

Status: Draft discovery; not implementation authority.

Contract revision: `DV-DRAFT-1`.

Change mode: `discover`.

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

## Provisional user-visible behavior

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

- `DV-APP-1`: The recommended initial scope is `Only selected apps`, with an
  empty list until the user adds at least one app.
- `DV-APP-2`: The alternative scope is `All apps except excluded apps` and
  requires a separate explicit selection because it has broader privacy
  consequences.
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
- `DV-STORAGE-8`: The initial release does not delete vlog clips
  automatically. It shows size by day and app, warns before space is exhausted,
  and requires explicit deletion.
- `DV-STORAGE-9`: Low-space thresholds remain an open product decision. The
  contract must distinguish warning capacity from the hard point at which a
  new vlog branch is skipped.

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
  scope and clip selection before confirming.
- `DV-BUILD-3`: A build recipe is saved before rendering and identifies its
  ordered source clip IDs and export preset.
- `DV-BUILD-4`: Rendering writes a new output. It does not overwrite source
  clips or an earlier successful export.
- `DV-BUILD-5`: A failed or cancelled build leaves source clips unchanged and
  may be retried from its existing recipe.
- `DV-BUILD-6`: The first export preset should target broadly compatible
  H.264 video with AAC audio. The provisional first canvas is 1280x720 at 30
  frames per second.
- `DV-BUILD-7`: Square, portrait, captions, title cards, transitions, silence
  trimming, and automatic highlights are later presets, not prerequisites for
  the first local build.
- `DV-BUILD-8`: Every media/export operation has a bounded timeout or
  cancellable progress boundary. A retry reuses valid completed artifacts.

### Publication

- `DV-PUBLISH-1`: Publication is a separate layer after a successful export.
  A build can succeed even when no publication destination is configured.
- `DV-PUBLISH-2`: The first useful release may stop at Export, Reveal in
  Finder, and the system Share surface rather than requiring direct social APIs.
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

### Dev Vlogs window and menu entry

- `DV-UI-1`: The menu bar utility group gains one item: `Dev Vlogs…`.
- `DV-UI-2`: The item opens a separate SwiftUI window titled
  `HoldType: Dev Vlogs`; the feature is not inserted as another dense Settings
  sidebar section.
- `DV-UI-3`: The window owns enablement, setup, capture health, destination,
  app rules, day/app browsing, storage summary, builds, and publication
  readiness.
- `DV-UI-4`: The menu bar popover remains compact. It may show a small camera
  capture or degraded-state indicator but does not expose camera, destination,
  or app-rule controls.
- `DV-UI-5`: The first window information architecture is:
  1. status and primary action;
  2. today's clips and storage summary;
  3. day/app browser and review;
  4. build/export history;
  5. setup for camera, destination, and app scope.
- `DV-UI-6`: Camera preview, video player, controls, layout, state, and visible
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
- Default logs contain no video, audio, transcripts, paths, app content,
  prompts, credentials, or provider payloads.
- Build is non-destructive; clip deletion is explicit.
- Publication is explicit and never automatic by default.
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

The later reconciliation also needs a semantic contract revision beyond
`DV-DRAFT-1`, an acceptance map, and runtime evidence from the Phase 0 spike.

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

## Provisional media and storage budget

For a 720p H.264 source at roughly 2-5 Mbps plus 128 Kbps AAC audio, the
calculated storage range is approximately:

- 16-39 MB per recorded minute;
- 1.0-2.3 GB per recorded hour;
- 0.5-1.2 GB for thirty one-minute clips in a day;
- 0.25-0.58 GB for one maximum 15-minute attempt.

These are planning estimates, not measured HoldType results. A capture spike
must measure real files from the built-in camera, a common USB webcam, and
Continuity Camera before quality, warning, and hard-stop thresholds are fixed.

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

- settle the open product decisions below;
- measure camera start latency and audio/video drift;
- verify one-audio-owner capture and muxing;
- test internal and external destinations, unplug, low-space, sleep, quit, and
  camera-disconnect behavior;
- measure actual storage and CPU impact at candidate presets;
- produce a SwiftUI information-architecture prototype for the separate
  window.

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

- whether the feature should ever preserve transcript text for captions;
- whether app changes during a long dictation should terminate only the vlog
  branch;
- the right preview/indicator balance during frequent short captures;
- real Continuity Camera and multi-camera device identity behavior;
- social-platform presets, account tiers, upload limits, and authentication at
  implementation time;
- whether advanced users need a CLI/automation surface in addition to the app
  command model.

## Verification mapping for a future implementation

- Enablement: fresh install off, explicit enable, explicit disable, no capture
  from passive window opening.
- App policy: selected app, excluded app, unknown app, app rename, duplicate
  display names, HoldType window focus, and menu-started dictation.
- Camera: permission states, stable selection, USB disconnect/reconnect, busy
  device, Continuity Camera disappearance, and no silent fallback.
- Destination: default Movies location, external folder, rename/remount, stale
  bookmark, read-only folder, low space, and unplug during capture.
- Capture: exact one clip per eligible dictation, shared audio correctness,
  bounded camera start, drift, user stop, duration limit, discard, quit, crash,
  and dictation success under every vlog failure.
- Storage: correct day/app hierarchy, stable IDs, truthful sizes, active-file
  protection, explicit deletion, and index reconstruction.
- Build: deterministic order, excluded clips, cancellation, retry, missing
  source, no overwrite, playable H.264/AAC export, and unchanged sources.
- Publication: explicit confirmation, credential isolation, bounded upload,
  provider processing, retryable failure, and outcome-uncertain duplicate
  protection.
- Runtime UI: a future visible/interaction change requires Computer Use QA with
  the repository's sanitized launch and cleanup rules.

## Unknowns requiring confirmation

These are real product decisions, not implementation questions:

1. Is `Only selected apps` the correct default after the global feature is
   enabled, or should setup offer `All apps except exclusions` with equal
   prominence?
2. Should an actual switch from an eligible external app to an ineligible app
   during a long dictation stop the vlog branch, or is trigger-app-at-start the
   complete policy?
3. Is the same dictation microphone always the vlog audio source for V1, or
   must a camera's built-in microphone be selectable?
4. Is 720p/30 H.264 the correct source default, with 1080p deferred?
5. Should the camera image be mirrored in the stored source, only in preview,
   or only as a build setting?
6. What low-space warning and hard-stop thresholds are acceptable?
7. Should source clips have no automatic retention forever, or should an
   explicit max-days/max-size policy be part of the first release?
8. Does the first build need only chronological concatenation, or must it also
   support reorder and trim?
9. Should V1 store accepted transcript text beside a clip for captions/search,
   or keep vlog media strictly separate from transcript persistence?
10. Is `Dev Vlogs` the final user-facing name?
11. Is a CLI command an actual product requirement, or are app commands such as
    `Build Today's Vlog…` sufficient initially?
12. Which publication destination should be first after local export is proven:
    X, YouTube, Mastodon, or only the macOS Share surface?
