# Dev Vlogs Persistent Goal Registry

Status: active coordination state

Goal thread: `019fe09f-e938-7bb3-b984-dd3ac4f05848`

Started: 2026-08-08

Governing plan:
[`docs/dev-vlogs-implementation-plan.md`](dev-vlogs-implementation-plan.md).

Approved autonomous delivery plan:
[`docs/dev-vlogs-autonomous-delivery-plan.md`](dev-vlogs-autonomous-delivery-plan.md),
committed at `3753db1` and activated as the persistent-goal objective on
2026-08-11.

Pinned contract:
[`docs/specs/features/dev-vlogs.md`](specs/features/dev-vlogs.md), revision
`DV-ACTIVE-3`, advanced under the user's 2026-08-11 clarification that the
product must avoid additional video processing/re-encode/downsample but does
not require a separate forensic sample-exact proof. Independent
`DV-P2-CAPTURE-REVIEW-R1-REPAIR` accepted the Release capture implementation
with one bounded real-device runtime residual.

Historical packet and receipt bodies are preserved verbatim in the
[registry archive](dev-vlogs-execution-registry-archive.md). They are evidence,
not current coordination or product authority.

## Restart Gate

After every start, resume, clear, or context compaction, `/root` must read the
active persistent goal, `AGENTS.md`, `root-orchestration.md`,
`product-truth-governance.md`, the governing plan, the current Dev Vlogs
contract, and this registry before dispatching or accepting goal work.

Chat memory, summaries, live worker state, and the historical archive do not
replace this pass.

## Scope Guard

The goal ends after accepted Phase 4 local Build, Export, and macOS Share.
Direct publication adapters and every other deferred plan item are outside the
goal.

No packet may improve, refactor, redesign, or clean up an adjacent product or
shared owner beyond the smallest change proven necessary for Dev Vlogs.
Protected domains are ordinary dictation, transcription, correction,
translation and output; Transcript History; Recording Cache; shared Settings;
Keychain; diagnostics; updates; unrelated menu behavior; iOS; and
website/marketing.

No new Phase 0B Debug, tooling, observer, permission, preview, storage, or
hardware-runtime work is admitted without a separate user-approved
cost/benefit decision. Residuals gate only the claims and capabilities that
depend on them.

## Accepted Decisions

The user accepted `DV-D01` through `DV-D13` on 2026-08-08. The user further
required native-source preservation: HoldType must not impose a source-video
resolution/FPS downgrade or an additional source-video encode. Native 1080p or
another negotiated format is not a HoldType preset, quality selector, sensor
RAW promise, or permission to claim preservation without proof.

`DV-BUILD-6` is the only remaining material product decision. It gates only
Phase 4 behavior when selected clips cannot be composed by direct-compatible
passthrough: the user must later choose one final no-resolution/no-nominal-FPS
reduction encode or a failed Build with no output.

On 2026-08-10 the user adopted outcome-first execution. Release-path product
capability is the primary progress measure; specs, tests, Debug harnesses,
evidence, models, registries, and reviews are supporting work. On 2026-08-11
the user explicitly authorized `DV-ACTIVE-1` and the narrow adjacent contract
reconciliation recorded below.

## Contract Epoch

| Epoch | Authority | Status | Notes |
| --- | --- | --- | --- |
| `DV-DRAFT-2@8081c10` | Earlier discovery Draft | superseded | Historical evidence only. |
| `DV-DRAFT-3@ed108fa` | Accepted-decision Draft plus protocol | superseded | Historical evidence only. |
| `DV-DRAFT-4@2f3266a` | Native-source Draft | superseded | Phase 0B evidence basis; not current authority. |
| `DV-ACTIVE-1` | User-authorized Dev Vlogs contract and narrow adjacent clauses | superseded by `DV-ACTIVE-2` | Historical Phase 1 authority; accepted setup/UI behavior remains protected. |
| `DV-ACTIVE-2` | Approved Publish information architecture and local-artifact presentation | superseded by `DV-ACTIVE-3` | Historical Publish UI authority; its accepted behavior remains protected. |
| `DV-ACTIVE-3` | User-clarified no-additional-video-processing capture contract | current / capture source accepted_with_residual | Active, Evolving implementation authority. Configured passthrough and playable media govern source acceptance; a separate sample-exact forensic validator is not a product gate. |

Any open packet based on affected `DV-DRAFT-4` clauses is retired or must be
revalidated before its result can be accepted. Historical Phase 0B evidence
remains evidence under the dispositions below.

## Contract Change Envelope

- Task: activate the Dev Vlogs V1 contract and make the smallest Release-path
  setup slice dependency-ready.
- Change mode: scoped `evolve` plus `reconcile`.
- User-authorized outcome: `DV-ACTIVE-1` plus the approved autonomous Publish
  evolution recorded as `DV-ACTIVE-2`, under explicit authority dated
  2026-08-11.
- Authorized domains: Dev Vlogs V1 clauses and only the named Camera privacy,
  local preferences, menu entry, shared-audio lease, and separate vlog-media
  durability integrations.
- Protected adjacent domains: ordinary dictation/transcription/output,
  History, Recording Cache, shared Settings UI/persistence, Keychain,
  diagnostics, updates, unrelated menu commands, iOS, and marketing.
- Shared owners: microphone finalization may later expose only the bounded
  read lease specified by `DV-AUDIO-LEASE-1`; no second microphone owner or
  provider/output behavior change is authorized.
- Authority/stability: Active/Evolving Dev Vlogs; existing released macOS
  behavior remains protected.
- Required evidence: capability-specific scenarios in the acceptance map;
  independent `DV-P0C-REVIEW` accepted the contract before Phase 1 dispatch.
- Allowed specification delta: `DV-ACTIVE-2`, active acceptance mapping, the
  approved final Publish IA/local-artifact meaning, and the exact narrow
  adjacent clauses named above.
- Forbidden delta: weakened capture/storage acceptance, invented thresholds,
  hidden capture, silent fallback, automatic deletion, second microphone
  ownership, iOS change, publication, or CLI.
- Material decision requiring the user: `DV-BUILD-6` only, before Phase 4
  incompatible-source fallback.
- Pinned epoch: `DV-ACTIVE-3`.

## Accepted Phase 0B Evidence

- Capture R09 (`8c5ea02`) reached one authorized Continuity attempt. The
  camera-only asset was playable `1V/0A`, the finalized asset was playable
  `1V/1A`, and passthrough completed. Strict stored-sample preservation failed
  `reading_failed`; Ready remained zero. This is a functional failure, not an
  accepted capture path.
- W10 (`b539487`) added Debug-only closed reader-operation/asset-side mappings
  and completed self-verification, but its reviewer produced no verdict after
  a usage limit. It is unreviewed support evidence and does not prove runtime
  success.
- Controlled storage cells established useful bookmark/capacity/promotion and
  cleanup mechanics. R05 changed protected metadata; exact cause remains
  unknown. Storage has no protected-scope acceptance.
- UI R01 (`771b309`) is terminal `not_available`: the explicit camera was
  selected, the app reported Camera `notDetermined`, and no permission request
  or capture occurred. Live frames, Stop, mirroring, camera release, and
  reacquisition were not proven. The required SwiftUI skill is now available;
  skill availability is no longer a blocker.
- E07 (`719e995`) accepts deterministic fake-backed paired dictation
  non-regression. It does not accept the shipping shared-audio lease or real
  product integration.
- Representative latency, sync/drift, CPU, memory, byte-rate, temporary-byte,
  and finalization-overhead datasets remain incomplete. No numeric product
  threshold is accepted.

## Residual-To-Capability Map

| Capability | Current residual | Effect |
| --- | --- | --- |
| Window, menu entry, Overview, Off/Setup | None from Phase 0B | Phase 1 is implementation-ready after proportional contract review. Passive opening never requests Camera or starts capture. |
| Camera preview/setup | R01 proved no live frames, Stop, release, mirroring, or reacquisition | Preview may be implemented later but cannot be claimed accepted until its explicit lifecycle passes. Unavailable preview must remain truthful. |
| One-clip capture | R09 strict preservation `reading_failed`; Ready=0; shipping lease/integration unaccepted | Gates capture acceptance and any Ready-clip claim; does not gate setup UI. |
| Numeric start/space policy | Representative quantitative datasets incomplete | No numeric latency, warning, or hard-stop rule may be invented. Gate only controls that require those numbers. |
| Storage protected scope | R05 protected metadata changed; attribution unknown | Mechanics may inform implementation, but protected-scope storage acceptance remains open. |
| Library/delete | No product library or exact-delete acceptance | Gates library acceptance; separate vlog ownership clauses are implementation authority, not proof. |
| Build/share | Product QA absent; `DV-BUILD-6` unresolved for incompatible sources | Compatible build work waits for Phase 4; incompatible-source fallback waits for the user decision. |

## Packet Registry

| Packet | Epoch | Dependency | Status | Next dependency |
| --- | --- | --- | --- | --- |
| `DV-P0C-CONTRACT` | `DV-ACTIVE-1` | user authority and terminal Phase 0B dispositions | accepted_with_residual at `835c455` | Phase 1 shipping. |
| `DV-P0C-REVIEW` | `DV-ACTIVE-1` | `DV-P0C-CONTRACT@835c455` | accepted_with_residual | No material blocker; preserve the editorial residual below and do not open a repair cycle. |
| `DV-P1-SETUP` | `DV-ACTIVE-1` | accepted `DV-P0C-REVIEW` | accepted_with_residual at `ceeee8b` | Release `Dev Vlogs…`, separate SwiftUI window, Overview default, truthful Off/Setup; focused tests/build accepted. Computer Use transport blocked the post-repair visual pass. |
| `DV-P1-CAMERA-SETUP` | `DV-ACTIVE-1` | accepted `DV-P1-SETUP` source/build review | accepted_with_residual at `e2614c7` | Genuine Camera status/request/recovery and preferred-camera discovery/selection ship without passive request, preview, capture, fallback, or dictation dependency. Computer Use visual QA remains blocked. |
| `DV-P1-APPLICATIONS` | `DV-ACTIVE-1` | accepted `DV-P1-CAMERA-SETUP` | accepted_with_residual at `b27d859` | Selected-app default and explicit all-apps-with-exclusions policy, durable bundle-ID identity, validated app picker/editor; no capture integration. Computer Use visual QA remains blocked. |
| `DV-P1-STORAGE` | `DV-ACTIVE-1` | accepted `DV-P1-APPLICATIONS` | accepted_with_residual at `9f8c01c` | Default/custom bookmark-backed destination, truthful availability, and complete Phase 1 readiness ship without numeric thresholds or capture writes. Computer Use visual QA remains blocked. |
| `DV-P1-UI-POLISH` | `DV-ACTIVE-1` | accepted Phase 1 setup and user-approved UI polish plan | accepted_with_residual at `b9114a5` | Settings-quality Release UI and exact lower-priority menu placement accepted; bounded MenuBarExtra, final close/reopen, and Dark runtime observations remain residuals. |
| `DV-P2-PUBLISH-UI` | `DV-ACTIVE-2` | accepted Phase 1 UI plus autonomous plan `3753db1` | accepted_with_residual at `d9da88e` | Publish is the final visible section with a truthful no-recordings Release state; deterministic rich states are presentation-only. Computer Use window reacquisition remained blocked; source/tests/build review accepted. |
| `DV-P2-PRESERVATION-GATE` | `DV-ACTIVE-3` | accepted `DV-P2-PUBLISH-UI-REVIEW` plus user-approved autonomous plan `3753db1` | accepted_with_residual under user clarification | Corrected hardware route found one eligible Continuity Camera, playable camera `1V/0A`, playable finalized `1V/1A`, passthrough, and one microphone owner. The Debug-only `camera_source / sample_size_timing_metadata` read failure is no longer a product gate; no video processing was introduced. |
| `DV-P2-CAPTURE` | `DV-ACTIVE-3` | accepted corrected preservation evidence | implementation accepted_with_residual at `24d8f1e` | Release one-clip capture, real cleanup-aware audio lease, exact-once lifecycle, force camera teardown, archive publication, and truthful status are accepted. One real product attempt remains before runtime acceptance. |
| `DV-P3-LIBRARY` | current Active epoch | accepted Phase 2 | queued | Library, review, exclusion, and explicit exact deletion. |
| `DV-P4-BUILD` | current Active epoch | accepted Phase 3 and `DV-BUILD-6` when applicable | queued | Deterministic local Build, Export, Reveal, and Share. |
| `DV-FINAL-QA` | final Active epoch | accepted Phase 4 | queued | Proportional build/test/runtime/visual/protected-domain verification. |

## Current Coordination State

- Shipping capability delivered: commit `ceeee8b` provides the Release
  `Dev Vlogs…` action, separate singleton SwiftUI window, Overview-only first
  slice, persisted off-by-default enablement, and truthful Off/Setup state.
  Independent `DV-P1-SETUP-REVIEW-R1` accepted the repaired source, focused
  tests, and build.
- Runtime residual: Computer Use timed out before the post-repair menu/window
  interaction. The exact 30-second operator check is menu -> `Dev Vlogs…` ->
  title/Overview/Off -> enable/Setup required -> close/reopen persistence, with
  no Camera prompt, preview, or capture. Do not represent this visual journey
  as accepted until that observation is recorded.
- Support depth: reset to `0` by the Phase 1 shipping checkpoint. Verification
  remained proportional: one review and one one-line repair/re-review.
- Camera setup delivered by `e2614c7`: Capture owns nonprompting Camera status,
  explicit enabled-only request/recovery, current DiscoverySession enumeration,
  and a persisted preferred stable identity with remembered-unavailable and no-
  fallback behavior. Release Camera purpose and entitlement are accepted; the
  inherited Computer Use visual residual remains explicit.
- Applications setup delivered by `b27d859`: the safe selected-app default,
  separately confirmed all-apps-with-exclusions mode, bundle-ID-owned lists,
  and validated SwiftUI app import are accepted. No active-app observation or
  capture integration was introduced.
- Storage setup delivered by `9f8c01c`: exact default/custom destination,
  bookmark-backed identity, closed corrupt/unavailable states, no fallback,
  root-owned passive readiness refresh, and Off/Setup/Ready/degraded reduction
  are accepted without live destination writes.
- UI polish delivered by `b9114a5`: `Dev Vlogs…` is the final utility entry
  before Quit; the native sidebar, Overview, Capture, Applications, and Storage
  match the Settings information hierarchy. Independent review accepted the
  scoped source, seven focused suites, macOS build, five ImageGen references,
  Light-mode screenshots, and Computer Use navigation/toggle/resize flow.
  Direct Computer Use observation of the MenuBarExtra order, final
  close/reopen reacquisition, and Dark appearance remains a bounded visual
  residual; source/test enforcement and semantic system styling are accepted,
  and no repair cycle is admitted for those observations.
- Phase 1 source/build/UI status: complete and accepted with the bounded visual
  residuals above. Passive navigation showed no Camera prompt, preview, or
  capture, and no Phase 0B or Debug expansion was introduced.
- Autonomous completion authority: the user approved
  `docs/dev-vlogs-autonomous-delivery-plan.md` and activated the persistent
  goal. Execution proceeds through Publish UI, bounded one-clip capture,
  Library/Delete/Publish artifact creation, and integrated final QA without
  intermediate operator approval unless a recorded economic or external-
  authority stop condition is reached.
- Publish UI delivered by `d9da88e`: Publish is the final visible Dev Vlogs
  section and the Release runtime truthfully shows no recordings and no
  enabled artifact action. Rich empty-day/ready/building/cancelled/failed/
  completed presentations are deterministic injected states only. Independent
  review accepted the contract/source/tests/build and retained the bounded
  Computer Use window-reacquisition residual without a repair cycle.
- Preservation gate terminal result: Apple documentation and the current SDK
  proved the earlier standalone `.continuityCamera`-only enumeration was a
  false negative because an unbundled process may receive the iPhone as
  `.builtInWideAngleCamera`. The corrected all-video-types plus
  `isContinuityCamera` route found exactly one eligible device and performed
  exactly one signed 10-second W10 attempt. Camera media was playable `1V/0A`,
  final media was playable `1V/1A`, passthrough completed, and one dictation
  microphone owner was preserved. Strict `stored_sample_exact_v1` still failed
  `reading_failed / camera_source / sample_size_timing_metadata`; Ready stayed
  zero. This is an internal preservation-evidence dependency, not a phone or
  connection failure, and it does not authorize a retry or new Debug system.
- Editorial residual: Dev Vlogs still calls the human-readable folder
  hierarchy "part of the draft contract" in one sentence. Active authority is
  otherwise unambiguous; correct that wording only during a later natural
  specification edit, without a repair/re-review cycle.
- No Phase 0B expansion is admitted without separate explicit user approval.
- Outcome plan remains 60/25/15: approximately 60% shipping implementation,
  25% verification/review/QA, and 15% discovery/diagnostics/tooling/
  coordination, adjusted only for demonstrated risk.
- Capture implementation delivered by `ac0c4b6` and repaired by `24d8f1e`:
  one Release coordinator freezes policy/camera/destination/trigger identity,
  captures camera-only video, leases the existing finalized dictation audio,
  publishes one passthrough `1V/1A` clip, and leaves ordinary dictation
  authoritative. Independent re-review accepted exact cleanup deferral,
  disable cancellation, stale-task suppression, and forced camera teardown.
- Exact next dependency: one bounded real product attempt on the connected
  Continuity Camera must establish a playable archived clip, observed audio/
  video alignment, normal dictation completion, one microphone owner, and
  camera release. No Phase 0B expansion or new diagnostic system is required.
- Direct publication remains outside the goal.

## Contract Delta — `DV-ACTIVE-3`

- Change ID: `DV-DELTA-ACTIVE-3-CAPTURE-EVIDENCE`.
- Change mode: scoped `evolve` plus `reconcile`.
- Authorized by: the user's 2026-08-11 clarification that recording the
  camera with sound is the product outcome and HoldType must simply avoid
  additional video processing.
- Domain and clauses: capture acceptance portions of `DV-CAPTURE-3`,
  `DV-CAPTURE-8`, `DV-CAPTURE-10`, `DV-ACC-CAPTURE-1`, and
  `DV-ACC-MEDIA-1`.
- Previous behavior: a separate Debug-only sample-exact/sample-size-timing
  comparison could block capture even after configured passthrough produced
  playable camera `1V/0A` and finalized `1V/1A` media.
- New behavior: HoldType still must configure passthrough and must not decode,
  re-encode, downsample, or reduce nominal frame rate. Product acceptance uses
  the configured media path, playable camera/final tracks, truthful realized
  format, one microphone owner, and dictation independence; a separate
  forensic sample-exact validator is not a product gate.
- Evidence basis: corrected Continuity Camera attempt, direct user authority,
  implementation `ac0c4b6`, repair `24d8f1e`, and independent focused
  re-review.
- Compatibility: acceptance clarification plus additive Release Dev Vlogs
  capture; ordinary dictation and all adjacent released owners remain
  protected.
- QA impact: one bounded real product attempt remains required for audible
  alignment, normal dictation completion, and camera release.
- Specification paths: Dev Vlogs contract and implementation plan.
- Independent review: `DV-P2-CAPTURE-REVIEW-R1-REPAIR`
  `accept_with_residual`.
- New epoch: `DV-ACTIVE-3`.

## Contract Delta — `DV-ACTIVE-2`

- Change ID: `DV-DELTA-ACTIVE-2-PUBLISH`.
- Change mode: scoped `evolve` plus `reconcile`.
- Authorized by: the user-approved autonomous delivery plan `3753db1`.
- Domain and clauses: Dev Vlogs IA/presentation portions of `DV-UI-*`,
  `DV-BUILD-*`, `DV-SHARE-1`, `DV-D01`, `DV-D09`, and `DV-D12`.
- Previous behavior: future V1 IA named separate Library, Builds, and
  Permissions destinations while the accepted Phase 1 product exposed only
  Overview, Capture, Applications, and Storage.
- New behavior: the complete V1 IA ends with Library and Publish. Publish is
  the user-facing local-artifact preparation workflow; Build remains an
  internal durable recipe. Direct/social publication and social output
  profiles remain outside V1. The current Release exposes Publish with a
  truthful no-recordings state and no media action until its later owners
  exist.
- Evidence basis: approved plan `3753db1`, accepted Phase 1 visual baseline,
  implementation `d9da88e`, and independent
  `DV-P2-PUBLISH-UI-REVIEW` accept_with_residual.
- Compatibility: additive Dev Vlogs UI evolution; accepted Phase 1 setup and
  every protected adjacent macOS behavior remain unchanged.
- QA/design impact: native final navigation row, Settings-quality semantic
  Form, deterministic presentation states, focused tests, macOS builds, and a
  bounded Computer Use residual.
- Specification paths: Dev Vlogs contract and implementation plan.
- Independent review: accepted_with_residual; no repair dependency.
- New epoch: `DV-ACTIVE-2`.

## Historical Contract Delta — `DV-ACTIVE-1`

- Change ID: `DV-DELTA-ACTIVE-1`.
- Change mode: scoped `evolve` plus `reconcile`.
- Authorized by: explicit user authority dated 2026-08-11.
- Domain and clauses: Dev Vlogs V1; optional Camera permission/local archive;
  separate local preferences/window; menu entry; bounded shared-audio lease;
  separate vlog durability/delete boundary.
- Previous behavior: `DV-DRAFT-4` was evidence only and Phase 0B failures
  broadly blocked implementation.
- New behavior: `DV-ACTIVE-1` is Active/Evolving implementation authority;
  acceptance remains capability-gated, while Phase 1 Off/Setup is ready
  independently of later residuals.
- Evidence basis: accepted decisions `DV-D01`–`DV-D13`, terminal R09, storage
  R05, UI R01, accepted fake-backed E07, W10's unreviewed disposition, and the
  2026-08-10 economic reset.
- Compatibility: additive macOS feature; existing released behavior remains
  protected.
- Adjacent domains checked: privacy/permissions, settings/secrets, menu shell,
  microphone input, and recording durability; all other protected domains are
  unchanged.
- QA/design impact: active acceptance map added; SwiftUI separate-window
  pattern governs Phase 1; runtime acceptance remains capability-specific.
- Specification paths: Dev Vlogs, plan, index, five adjacent contracts, Phase
  0B closeout, and this registry split.
- Independent review: `DV-P0C-REVIEW` accepted_with_residual; no material
  finding, one nonblocking editorial residual recorded above.
- New epoch: `DV-ACTIVE-1`.
