# Dev Vlogs Persistent Goal Registry

Status: active

Goal thread: `019fe09f-e938-7bb3-b984-dd3ac4f05848`

Started: 2026-08-08

Governing plan: [`docs/dev-vlogs-implementation-plan.md`](dev-vlogs-implementation-plan.md)

Pinned contract: [`docs/specs/features/dev-vlogs.md`](specs/features/dev-vlogs.md),
revision `DV-DRAFT-3`, checkpoint `ed108fa`.

## Restart Gate

After every start, resume, clear, or context compaction, `/root` must read the
active persistent goal, `AGENTS.md`, `root-orchestration.md`,
`product-truth-governance.md`, the governing plan, the current Dev Vlogs
contract, and this registry before dispatching or accepting goal work.

Chat memory, summaries, live worker state, and earlier green checks do not
replace this pass.

## Scope Guard

The goal ends after accepted Phase 4 local Build, Export, and macOS Share.
Direct publication adapters and every other deferred item in the governing plan
are outside the goal.

No packet may improve, refactor, redesign, or clean up an adjacent product or
shared owner beyond the smallest change proven necessary for Dev Vlogs. The
protected domains are ordinary dictation, transcription and output, Transcript
History, Recording Cache, shared Settings, Keychain, diagnostics, updates,
unrelated menu behavior, all iOS behavior, and website/marketing.

Real technical blockers remain visible. A worker must return the exact
dependency or environment residual rather than weaken the contract, invent a
fallback, or broaden scope.

## Accepted Decisions

The user accepted `DV-D01` through `DV-D13` on 2026-08-08. They are integrated
in `DV-DRAFT-3@ed108fa` and independently accepted for discovery/evidence work.
They are not yet an Active implementation epoch.

## Contract Epoch

| Epoch | Authority | Status | Notes |
| --- | --- | --- | --- |
| `DV-DRAFT-2@8081c10` | Earlier discovery draft | superseded | Replaced after the accepted decisions were integrated and reviewed. |
| `DV-DRAFT-3@ed108fa` | Decision-complete discovery draft plus Phase 0B protocol | current | Non-UI evidence packets may run; product implementation remains gated. |
| `DV-ACTIVE-1` | Future reconciled Dev Vlogs and adjacent active specs | pending | Required before Phase 1 product implementation. |

## Packet Registry

| Packet | Owner | Contract epoch | Dependencies | Writable scope | Status | Receipt | Residual / next dependency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DV-G0-REGISTRY` | `/root` | `DV-DRAFT-2@8081c10` | none | registry; plan registry link | accepted | recorded below | Dispatch `DV-P0A-SPEC`. |
| `DV-P0A-SPEC` | `/root/dv_p0a_spec` | `DV-DRAFT-2@8081c10` | `DV-G0-REGISTRY` | Dev Vlogs spec; Phase 0B protocol | accepted | `ed108fa` | Decision-complete `DV-DRAFT-3` produced. |
| `DV-P0A-REVIEW` | `/root/dv_p0a_review` | `DV-DRAFT-3@ed108fa` | `DV-P0A-SPEC` | read-only | accepted_with_residual | recorded below | Phase 0B quantitative evidence and UI skill remain expected residuals. |
| `DV-P0B-CAPTURE-E01` | `/root/dv_p0b_capture_map` | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | read-only capture/source/platform evidence | accepted_with_residual | recorded below | Debug-only capture spike feasible; shipping audio lease remains Phase 0C work. |
| `DV-P0B-STORAGE-E01` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | read-only storage/source/platform/environment evidence | accepted_with_residual | recorded below | Test-only storage spike feasible; physical disconnect/read-only cells remain environment residuals. |
| `DV-P0B-E01-REVIEW` | `/root/dv_p0b_e01_review` | `DV-DRAFT-3@ed108fa` | both E01 maps | read-only | accepted_with_residual | recorded below | Writable capture/storage packets must be serialized and keep distinct QA run roots. |
| `DV-P0B-CAPTURE-W01` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-3@ed108fa` | accepted `DV-P0B-E01-REVIEW` | exact Debug-only capture paths from accepted E01 map | accepted_with_residual | `9d9efec`, repair `ff70155`; receipts below | Debug/fake/build feasibility accepted; real hardware/media evidence and shipping audio lease remain. |
| `DV-P0B-CAPTURE-W01-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-W01@9d9efec` | read-only | rejected | recorded below | Return exact four blockers to the original owner; runtime/storage remain blocked. |
| `DV-P0B-CAPTURE-W01-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | repair `ff70155` | read-only | accepted_with_residual | recorded below | Storage is dependency-ready; hardware remains a separate controlled runtime gate. |
| `DV-P0B-STORAGE-W01` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | accepted `DV-P0B-CAPTURE-W01@ff70155` | two exact storage test files; one redacted QA summary; marker-verified internal temp roots | accepted_with_residual | `2486b56`, repair `69b2d16`; receipts below | Internal bookmark/capacity/promotion/cleanup evidence accepted; external/media runtime remains. |
| `DV-P0B-STORAGE-W01-REVIEW` | `/root/dv_p0b_storage_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-STORAGE-W01@2486b56` | read-only | rejected | recorded below | Return exact safety/claim repairs to original owner; external/runtime work remains blocked. |
| `DV-P0B-STORAGE-W01-REVIEW-R1` | `/root/dv_p0b_storage_w01_review` | `DV-DRAFT-3@ed108fa` | repair `69b2d16` | read-only | accepted_with_residual | recorded below | Controlled external/runtime evidence may be packetized separately. |
| `DV-P0B-CAPTURE-R01` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-3@ed108fa` | accepted capture/storage W01 repairs | one redacted capture-R01 QA run; raw media in exact temporary run root only | accepted_with_residual | `f698fcb`; receipts below | All camera classes terminal not_available; preflight only, no capture/media claim. |
| `DV-P0B-CAPTURE-R01-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-R01@f698fcb` | read-only | accepted_with_residual | recorded below | Retry capture only when an explicit camera uniqueID enumerates. |
| `DV-P0B-CAPTURE-R02` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-3@ed108fa` | accepted R01 preflight; user reports iPhone connected/prepared | one redacted capture-R02 QA run; raw media in exact temporary run root only | review | `0e21972`; pending review receipt below | Continuity enumerated, but camera start failed and termination overran; no retry before review/repair. |
| `DV-P0B-STORAGE-E02` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | accepted storage W01 repair and capture R01 cleanup | read-only exact external-runtime seam/command map | review | pending review receipt below | Existing harness is internal-only; proposed three-path test seam awaits independent review. |
| `DV-P0B-UI` | unassigned | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW`; required skill available | bounded prototype/evidence paths assigned later | queued | — | Do not dispatch until `build-macos-apps:swiftui-patterns` is available and read. |
| `DV-P0B-REVIEW` | unassigned reviewer | `DV-DRAFT-3@ed108fa` | all dispatched P0B packets | read-only | queued | — | Reconcile evidence, residuals, and protected-domain impact. |
| `DV-P0C-CONTRACT` | unassigned | accepted P0A revision | `DV-P0B-REVIEW` | named specs and acceptance map | queued | — | Produce `DV-ACTIVE-1`; no implementation. |
| `DV-P0C-REVIEW` | unassigned reviewer | proposed `DV-ACTIVE-1` | `DV-P0C-CONTRACT` | read-only | queued | — | Independent contract and epoch acceptance. |
| `DV-P1-SETUP` | unassigned | `DV-ACTIVE-1` | `DV-P0C-REVIEW` | assigned foundation/setup paths | queued | — | Foundation and setup vertical slice. |
| `DV-P2-CAPTURE` | unassigned | current Active epoch | accepted Phase 1 | assigned capture paths | queued | — | One-clip slice without dictation regression. |
| `DV-P3-LIBRARY` | unassigned | current Active epoch | accepted Phase 2 | assigned archive/library paths | queued | — | Library, review, exclusion, and exact deletion. |
| `DV-P4-BUILD` | unassigned | current Active epoch | accepted Phase 3 | assigned build/export/share paths | queued | — | Deterministic local Build, Export, and Share. |
| `DV-FINAL-QA` | unassigned reviewers | final Active epoch | accepted Phase 4 | read-only plus controlled runtime evidence | queued | — | Build/tests, signed camera/storage/runtime, SwiftUI QA, and protected-domain verification. |

## Current Coordination State

- Accepted E01 evidence supports bounded Debug-only capture and test-only
  storage spikes without a shipping dependency.
- Repaired capture packet `ff70155` is accepted_with_residual after independent
  review. The original `9d9efec` rejection remains recorded below.
- Accepted evidence is limited to Debug/fake/build feasibility. It does not
  establish camera/TCC/device/media measurements, E07 dictation non-regression,
  or the shipping shared-audio lease.
- Repaired storage packet `69b2d16` is accepted_with_residual after independent
  review. The original `2486b56` rejection remains recorded below.
- Accepted storage evidence is limited to fake/internal APFS bookmark,
  capacity, exclusive-promotion, redaction, and cleanup mechanics. External
  drives, true-stale/remount, interruption, and representative media remain.
- Capture runtime preflight `f698fcb` is accepted_with_residual. Built-in and
  USB are unavailable; the connected iPhone did not enumerate as Continuity
  Camera. No capture, TCC, media, or quantitative claim exists.
- A bounded capture retry waits for an explicit camera uniqueID. Independent
  storage external/runtime evidence may proceed serially after this cleanup.
- `DV-P0B-STORAGE-E02` completed a read-only map: the accepted harness is
  internal-only and a proposed three-path external test seam awaits review.
- `DV-P0B-CAPTURE-R02@0e21972` awaits evidence review. Continuity enumeration
  succeeded, camera start failed before first frame, and termination exceeded
  its accepted cleanup bound. No hardware retry is allowed before repair.
- Product implementation is gated until `DV-P0C-REVIEW` accepts
  `DV-ACTIVE-1`.
- The connected iPhone is reserved for the later dependency-ready Continuity
  Camera runtime gate.
- E01 observed writable external SSD and HDD classes. Exact authorized scratch
  bases and runtime availability remain pending for the storage packet.
- `build-macos-apps:swiftui-patterns` was unavailable during planning; do not
  dispatch UI design or implementation until resolved.
- Direct publication is outside the goal and must never be dispatched.

## Accepted Receipts

### `DV-G0-REGISTRY`

```text
packet_id: DV-G0-REGISTRY
status: done

outcome: Persistent goal scope, restart gate, epochs, packet graph, and blocker
policy recorded.
authority_used: User-created goal; governing plan; DV-DRAFT-2;
root-orchestration.md; product-truth-governance.md.
changed_paths: docs/dev-vlogs-execution-registry.md;
docs/dev-vlogs-implementation-plan.md
reused_owners: Existing Dev Vlogs plan and specification system.
checks_run: Documentation diff hygiene before checkpoint acceptance.
scope_check: Coordination-only; no product behavior or source change.
deviations: none
residual: DV-D01-D13 require specification integration and review.
next_dependency: DV-P0A-SPEC
runtime_or_visual_handoff: none
```

### `DV-G0-REGISTRY-REVIEW`

```text
packet_id: DV-G0-REGISTRY-REVIEW
status: done

outcome: accept
authority_used: User-created persistent goal; AGENTS.md; governing plan;
DV-DRAFT-2@8081c10.
changed_paths: none
reused_owners: Existing Dev Vlogs plan and specification system.
checks_run: Exact two-path diff inspection; tracked and untracked diff hygiene;
plan/spec linkage; packet graph and scope gates.
scope_check: Scope guard, Phase 0 dependency order, UI skill gate, and exclusion
of direct publication are coherent.
deviations: none
residual: Registry awaits the coordinator's scoped checkpoint commit.
next_dependency: DV-P0A-SPEC
runtime_or_visual_handoff: none
```

### `DV-P0A-SPEC`

```text
packet_id: DV-P0A-SPEC
status: done

outcome: Integrated DV-D01-D13 into decision-complete DV-DRAFT-3 and added a
bounded Phase 0B feasibility and measurement protocol.
authority_used: User acceptance; DV-DRAFT-2@8081c10; governing plan and
registry; product-truth governance.
changed_paths: docs/specs/features/dev-vlogs.md;
docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md
reused_owners: Existing Dev Vlogs specification and QA evidence layers.
checks_run: Staged diff hygiene, complete staged-diff inspection, post-commit
path audit.
scope_check: Only authorized documentation paths changed.
deviations: none
residual: Numeric latency/storage evidence awaits Phase 0B; UI preview waits
for build-macos-apps:swiftui-patterns.
next_dependency: DV-P0A-REVIEW
runtime_or_visual_handoff: none
commit: ed108fa69fe54781dbe09285c3dac59d3d4f1b35
```

### `DV-P0A-REVIEW`

```text
packet_id: DV-P0A-REVIEW
status: done

outcome: accept_with_residual
authority_used: Pinned pre-change authority, user decisions, DV-DRAFT-3 and
Phase 0B protocol at ed108fa.
changed_paths: none
reused_owners: Dev Vlogs specification, plan, registry, and QA evidence layer.
checks_run: Full authority reading; exact commit review; path and diff hygiene;
pre/post comparison; stale-reference check; DV-D01-D13 mapping.
scope_check: Clean; no adjacent spec or source change.
deviations: none
residual: Phase 0B must provide quantitative capture/storage evidence. UI
preview feasibility remains gated on build-macos-apps:swiftui-patterns.
next_dependency: DV-P0B-CAPTURE and DV-P0B-STORAGE
runtime_or_visual_handoff: none
```

### `DV-REGISTRY-P0A-UPDATE-REVIEW`

```text
packet_id: DV-REGISTRY-P0A-UPDATE-REVIEW
status: done

outcome: accept after repair of two stale revision/status statements
authority_used: DV-DRAFT-3@ed108fa; accepted DV-P0A-SPEC and DV-P0A-REVIEW
receipts; governing plan and goal scope.
changed_paths: none
reused_owners: Persistent-goal registry and governing plan.
checks_run: Exact coordination diff review and diff hygiene.
scope_check: Current epoch, accepted decisions, dependency-ready packets, and
UI skill gate are coherent.
deviations: none
residual: Phase 0B capture/storage evidence remains required; UI remains
skill-gated.
next_dependency: DV-P0B-CAPTURE and DV-P0B-STORAGE
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-E01`

```text
packet_id: DV-P0B-CAPTURE-E01
status: done

outcome: Apple-native Debug-only camera/audio/mux spike is feasible with one
existing microphone owner and no shipping dependency.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; active microphone,
durability, and privacy contracts; exact recorder/controller/project source;
official Apple AVFoundation/CoreMedia documentation.
changed_paths: none
reused_owners: AVFoundationAudioRecorderService, AudioRecorderEngine,
RecordingCaptureJournal, and existing exact-once artifact finalization.
checks_run: Read-only source, project, SDK-header, and official-platform review.
scope_check: Capture feasibility only; no storage, UI, or product change.
deviations: none
residual: Shipping shared-audio lease is not implemented or authorized;
camera/TCC/signing/device/codec/latency/sync/fragment evidence remains.
next_dependency: DV-P0B-E01-REVIEW
runtime_or_visual_handoff: none
```

### `DV-P0B-STORAGE-E01`

```text
packet_id: DV-P0B-STORAGE-E01
status: done

outcome: Apple-native test-only destination/bookmark/capacity/promotion spike
is feasible with a separate Dev Vlogs owner.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; active storage/privacy/
durability/distribution contracts; exact storage owners; official Apple APIs.
changed_paths: none
reused_owners: Existing app distribution and file-system platform boundaries;
protected Cache, History, and recovery owners remain separate.
checks_run: Read-only source/project/platform review and redacted disk inventory.
scope_check: Storage feasibility only; no write, mount, unmount, or user-data
mutation.
deviations: none
residual: Real bookmark/remount/capacity/promotion/interruption evidence and
physical disconnect/read-only-media cells remain.
next_dependency: DV-P0B-E01-REVIEW
runtime_or_visual_handoff: none
```

### `DV-P0B-E01-REVIEW`

```text
packet_id: DV-P0B-E01-REVIEW
status: done

outcome: capture accept_with_residual; storage accept_with_residual
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; governing plan/registry;
exact source/project ownership; official Apple documentation.
changed_paths: none
reused_owners: Existing recorder/journal and protected storage owners.
checks_run: Pinned-contract comparison; lifecycle/startup/project/storage/API
inspection; read-only environment classification.
scope_check: Clean; explorers made no changes.
deviations: none
residual: Capture shipping lease and runtime evidence remain; storage real
filesystem/interruption evidence remains; quantitative data is evidence-only.
next_dependency: Repair stale plan references, checkpoint receipts, then
DV-P0B-CAPTURE-W01 followed by serialized storage work.
runtime_or_visual_handoff: none
```

### `DV-REGISTRY-E01-UPDATE-REVIEW`

```text
packet_id: DV-REGISTRY-E01-UPDATE-REVIEW
status: done

outcome: accept
authority_used: Accepted capture/storage E01 maps and E01 review; governing
plan, registry, and DV-DRAFT-3@ed108fa.
changed_paths: none
reused_owners: Persistent-goal registry and governing plan.
checks_run: Exact coordination diff review and diff hygiene.
scope_check: E01 residuals, serialized writable order, UI skill gate, and Phase
5 exclusion are coherent.
deviations: none
residual: Capture W01 is dependency-ready; storage and UI remain gated.
next_dependency: DV-P0B-CAPTURE-W01
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-W01`

```text
packet_id: DV-P0B-CAPTURE-W01
status: done

outcome: Built and fake-verified the isolated Debug-only camera/audio/mux
harness; repair ff70155 closed all four findings from the rejected base.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; accepted E01 evidence;
bounded W01 and R1 packets.
changed_paths: Fifteen original authorized paths plus nine path-bounded repair
changes; commits 9d9efec and ff70155.
reused_owners: Existing AVFoundationAudioRecorderService and AudioRecorderEngine;
no shipping shared-audio lease.
checks_run: Structure; 21 focused fake tests; Debug build-only; bounded Release
compile; Debug/Release settings and artifact isolation; script checks; path audit.
scope_check: Debug-only harness and exact integration paths; protected product
owners, Release camera declarations, UI, iOS, dependencies, and publication
unchanged.
deviations: Initial commit was rejected and repaired by the original owner.
residual: Real camera/microphone/TCC/Continuity, device/media/codec/timing/
resource evidence, E07, and the shipping shared-audio lease remain.
next_dependency: DV-P0B-CAPTURE-W01-REVIEW-R1
runtime_or_visual_handoff: none
accepted_repair_commit: ff70155aa0559678487eacb67bc16a62ce199b75
```

### `DV-P0B-CAPTURE-W01-REVIEW-R1`

```text
packet_id: DV-P0B-CAPTURE-W01-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Repair closes harness-only scene routing, steady-error exact-once
cleanup, bounded terminate-later cleanup, and callback-independent export/script
timeouts. Debug/fake/build feasibility is accepted.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; original W01 packet;
rejected review; repair ff70155; protected adjacent contracts.
changed_paths: none
checks_run: Exact nine-path diff; structure; 21 focused tests; bounded Release
build; Debug/Release settings and artifacts; Debug guards; one-mic/no-fallback
scan; script and QA-claim audit.
scope_check: Clean; Release retains original plist/entitlements and contains no
Dev Vlogs symbols. No app, hardware, TCC, UI, provider, Keychain, or storage run.
deviations: none
residual: Hardware/runtime/media measurements, E07, and shipping audio lease
remain outside this acceptance.
next_dependency: DV-P0B-STORAGE-W01 or separately controlled hardware runtime.
runtime_or_visual_handoff: none
reviewed_commit: ff70155aa0559678487eacb67bc16a62ce199b75
```

### `DV-P0B-STORAGE-W01`

```text
packet_id: DV-P0B-STORAGE-W01
status: done

outcome: Test-only storage harness verifies marker-owned roots, ordinary
bookmark rename-following, injected capacity/destination states, synchronized
writes, APFS exclusive no-overwrite promotion, truthful partial classification,
redaction, and exact cleanup. Repair 69b2d16 hardens cleanup ancestry identity.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E08; accepted E01 map;
bounded W01 and R1 packets.
changed_paths: Two storage test files and one redacted QA summary; commits
2486b56 and 69b2d16.
reused_owners: Internal FileManager temporary directory and ordinary unsandboxed
Foundation bookmarks only; no protected storage owner.
checks_run: Structure; 19 focused tests; redirected-prefix survival; bounded
Debug build; diff/path and zero-residue/process audits.
scope_check: Internal marker-owned temp roots only; no product source, project,
entitlement, UserDefaults, external volume, user archive, media, UI, or hardware.
deviations: Initial commit was rejected and repaired by the original owner.
residual: True-stale/external bookmark recovery, SSD/HDD, read-only/remount/
disconnect, representative media, and numeric Phase 0C inputs remain.
next_dependency: DV-P0B-STORAGE-W01-REVIEW-R1
runtime_or_visual_handoff: none
accepted_repair_commit: 69b2d163a696b4a13fab3e58475ad3065b57269f
```

### `DV-P0B-STORAGE-W01-REVIEW-R1`

```text
packet_id: DV-P0B-STORAGE-W01-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Cleanup prefix/root identity and stale-claim repairs close both prior
findings; internal XCTest/storage feasibility is accepted.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E08; original packet; rejected
review; repair 69b2d16.
changed_paths: none
checks_run: Exact three-path diff; ancestry/prefix/root/attack-fixture review;
structure; 19 cases; bounded Debug build; zero-residue and process audit.
scope_check: Clean; no product, external-volume, app, hardware, UI, provider,
Keychain, or representative-media access.
deviations: none
residual: External/read-only/remount/interruption/bookmark/media and numeric
threshold evidence remain.
next_dependency: Separately controlled external/runtime storage evidence.
runtime_or_visual_handoff: none
reviewed_commit: 69b2d163a696b4a13fab3e58475ad3065b57269f
```

### `DV-P0B-CAPTURE-R01`

```text
packet_id: DV-P0B-CAPTURE-R01
status: done

outcome: Bounded Debug/signing/internal-capacity preflight found zero built-in,
USB, Continuity, or other external cameras. No capture started.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; accepted capture and
storage harness repairs; finite R01 packet.
changed_paths: Twelve redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-r01/; commit f698fcb.
checks_run: Debug build; signing/Release isolation; bounded bundled enumeration;
capacity; JSON/CSV/redaction/path checks; cleanup audit.
scope_check: Evidence-only; no source, TCC, UI, provider, Keychain, iOS,
external-storage, or protected-owner change.
deviations: Initial detached idle guard exited early; enumeration repeated once
under a verified same-shell guard.
residual: No camera uniqueID; functional capture/media/TCC and all quantitative
evidence remain unqualified.
next_dependency: DV-P0B-CAPTURE-R01-REVIEW
runtime_or_visual_handoff: none
commit: f698fcb55e2d5b993947daf35bb41aecef075c6d
```

### `DV-P0B-CAPTURE-R01-REVIEW`

```text
packet_id: DV-P0B-CAPTURE-R01-REVIEW
status: done
verdict: accept_with_residual

outcome: Evidence supports terminal not_available classification for built-in,
USB, and Continuity cells; it makes no functional capture or media claim.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E02/E04/E06/E08; exact R01
evidence and accepted harness authority.
changed_paths: none
checks_run: Exact commit and twelve-blob audit; JSON/CSV parsing; redaction and
media scans; cleanup/process/caffeinate zero-residue snapshot.
scope_check: Clean; no source, spec, project, TCC, UI, Keychain, provider,
external storage, or protected-owner change.
deviations: Initial guard deviation was disclosed and corrected by guarded
repeat.
residual: Only enumeration/signing preflight is accepted. E02 functional media
and E06 measurements wait for an explicit camera identity.
next_dependency: Controlled retry after camera hardware enumerates.
runtime_or_visual_handoff: none
reviewed_commit: f698fcb55e2d5b993947daf35bb41aecef075c6d
```

## Completed Pending Review

### `DV-P0B-CAPTURE-R02`

```text
packet_id: DV-P0B-CAPTURE-R02
status: failed

outcome: One explicit candidate-capable Continuity Camera enumerated and was
selected with no fallback. Camera start failed before first frame; termination
then exceeded the accepted cleanup window.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted harness; user-authorized
Continuity retry.
changed_paths: Eight redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-r02/; commit 0e21972.
checks_run: Guarded enumeration and 10-second invocation; exact-once event and
artifact probes; bounded Computer Use attempt; cleanup/redaction/path audits.
scope_check: Evidence-only; no source, TCC, UI, provider, Keychain, iOS, or
external-storage change.
deviations: Exact run-owned TERM was required after cleanup overrun; Computer
Use could not attach to the non-activating harness.
residual: Underlying camera-start category is not logged; termination hangs
after the terminal failure; TCC state remains uncertain. No media gate passed.
next_dependency: DV-P0B-CAPTURE-R02-REVIEW
runtime_or_visual_handoff: none
commit: 0e21972071d76eff1dd53a67a0b397d7bc32518e
```

### `DV-P0B-STORAGE-E02`

```text
packet_id: DV-P0B-STORAGE-E02
status: done

outcome: Existing storage harness cannot accept an external base. A minimal
test-only seam is feasible in two storage test files plus one wrapper script.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E04/E06/E08; accepted W01;
current test scheme/tooling and read-only external inventory.
changed_paths: none
checks_run: Read-only harness/scheme/tooling and redacted disk metadata review.
scope_check: No file, volume, app, camera, UI, or external-content mutation.
deviations: none
residual: External actual I/O, representative media, unplug/remount, and
read-only media remain; each runtime mount root needs explicit authorization.
next_dependency: DV-P0B-STORAGE-E02-REVIEW
runtime_or_visual_handoff: none
```

## Rejected Receipts

### `DV-P0B-CAPTURE-W01-REVIEW` of `9d9efec`

```text
packet_id: DV-P0B-CAPTURE-W01-REVIEW
status: done
verdict: reject

outcome: The Debug harness builds and passes focused fake tests, but mandatory
startup-isolation, terminal-cleanup, and bounded-operation safeguards fail.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; original W01 packet;
exact commit and protected adjacent contracts.
changed_paths: none
checks_run: Exact 15-path diff; structure; 13 fake tests; Debug and Release
builds; build-setting and built-artifact isolation; script checks; final audit.
scope_check: Path scope and Release isolation pass; no hardware/TCC/UI/provider
runtime occurred.
deviations: none
residual: Product scenes still compose under the harness gate; steady-state
camera failures may not terminate and clean up; quit does not await cleanup;
the export timeout and one hardware-script build-settings probe are not fully
bounded. All real hardware/media evidence and the shipping lease remain open.
next_dependency: Original capture owner repairs the exact findings, then a new
independent review runs before storage or hardware runtime.
runtime_or_visual_handoff: none
reviewed_commit: 9d9efecc36e6337790a2f80e2571d3118e4bc404
```

### `DV-P0B-STORAGE-W01-REVIEW` of `2486b56`

```text
packet_id: DV-P0B-STORAGE-W01-REVIEW
status: done
verdict: reject

outcome: Path scope, build, 18 focused tests, promotion collision, redaction,
and residue checks pass, but cleanup symlink-prefix safety fails.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; exact W01 packet and
commit; protected storage contracts.
changed_paths: none
checks_run: Exact three-path diff; structure; focused suite; bounded Debug
build; zero-residue and process audit.
scope_check: Clean; no product, external-volume, media, or hardware runtime.
deviations: none
residual: Cleanup validates the run-root leaf but not the required temp-prefix
component immediately before recursive delete, allowing a parent-symlink
substitution risk. The summary also overstates stale-bookmark evidence: rename
following passed, but a stale result was not deterministically established.
next_dependency: Original storage owner repairs the same three paths, adds a
redirected-prefix survival test, corrects the claim, then repeats review.
runtime_or_visual_handoff: none
reviewed_commit: 2486b56c02130abd905824a0b50da95118a4b81c
```
