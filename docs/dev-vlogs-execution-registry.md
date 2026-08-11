# Dev Vlogs Persistent Goal Registry

Status: active coordination state

Goal thread: `019fe09f-e938-7bb3-b984-dd3ac4f05848`

Started: 2026-08-08

Governing plan:
[`docs/dev-vlogs-implementation-plan.md`](dev-vlogs-implementation-plan.md).

Pinned contract:
[`docs/specs/features/dev-vlogs.md`](specs/features/dev-vlogs.md), revision
`DV-ACTIVE-1`, activated under explicit user authority on 2026-08-11;
independent `DV-P0C-REVIEW` is pending.

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
| `DV-ACTIVE-1` | User-authorized Dev Vlogs contract and narrow adjacent clauses | current / review pending | Active, Evolving implementation authority. Capability acceptance remains scenario- and residual-gated. |

Any open packet based on affected `DV-DRAFT-4` clauses is retired or must be
revalidated before its result can be accepted. Historical Phase 0B evidence
remains evidence under the dispositions below.

## Contract Change Envelope

- Task: activate the Dev Vlogs V1 contract and make the smallest Release-path
  setup slice dependency-ready.
- Change mode: scoped `evolve` plus `reconcile`.
- User-authorized outcome: `DV-ACTIVE-1` and project-local coordination under
  explicit authority dated 2026-08-11.
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
  independent `DV-P0C-REVIEW` before Phase 1 implementation acceptance.
- Allowed specification delta: `DV-ACTIVE-1`, active acceptance mapping, and
  the exact narrow adjacent clauses named above.
- Forbidden delta: weakened capture/storage acceptance, invented thresholds,
  hidden capture, silent fallback, automatic deletion, second microphone
  ownership, iOS change, publication, or CLI.
- Material decision requiring the user: `DV-BUILD-6` only, before Phase 4
  incompatible-source fallback.
- Pinned epoch: `DV-ACTIVE-1`.

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
| `DV-P0C-CONTRACT` | `DV-ACTIVE-1` | user authority and terminal Phase 0B dispositions | complete; receipt is this checkpoint commit | Independent proportional review. |
| `DV-P0C-REVIEW` | `DV-ACTIVE-1` | `DV-P0C-CONTRACT` | queued | Accept, accept with residual, or reject the contract delta without opening another support chain. |
| `DV-P1-SETUP` | `DV-ACTIVE-1` | accepted `DV-P0C-REVIEW` | next shipping packet | Release `Dev Vlogs…`, separate SwiftUI window, Overview default, truthful Off/Setup; no capture or Camera request on open. |
| `DV-P2-CAPTURE` | current Active epoch | accepted Phase 1 plus dependent residual closure | queued | One playable exact-once clip without dictation regression. |
| `DV-P3-LIBRARY` | current Active epoch | accepted Phase 2 | queued | Library, review, exclusion, and explicit exact deletion. |
| `DV-P4-BUILD` | current Active epoch | accepted Phase 3 and `DV-BUILD-6` when applicable | queued | Deterministic local Build, Export, Reveal, and Share. |
| `DV-FINAL-QA` | final Active epoch | accepted Phase 4 | queued | Proportional build/test/runtime/visual/protected-domain verification. |

## Current Coordination State

- Shipping capability delivered by Phase 0C: none. This is the second and
  final admitted support-only checkpoint before shipping implementation.
- Capability unlocked: the smallest Phase 1 Release slice—`Dev Vlogs…`, a
  separate normal SwiftUI window, Overview default, and truthful Off/Setup
  state—is contract-ready and does not depend on preview, capture, storage
  thresholds, mux preservation, or `DV-BUILD-6`.
- Support depth: `2/2`. One proportional contract review is admitted. A repair
  may be used only for a focused defect in this delta; broader review findings
  become explicit residuals or return to `/root` for delivery-and-cost
  reassessment.
- No Phase 0B expansion is admitted without separate explicit user approval.
- Outcome plan remains 60/25/15: approximately 60% shipping implementation,
  25% verification/review/QA, and 15% discovery/diagnostics/tooling/
  coordination, adjusted only for demonstrated risk.
- Exact next capability: after `DV-P0C-REVIEW`, dispatch `DV-P1-SETUP` as
  `shipping_product`. Do not substitute more evidence, models, tooling, or
  Debug work.
- Direct publication remains outside the goal.

## Contract Delta — `DV-ACTIVE-1`

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
- Independent review: `DV-P0C-REVIEW` pending.
- New epoch: `DV-ACTIVE-1`.
