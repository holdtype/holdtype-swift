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
| `DV-P0B-CAPTURE` | unassigned | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | bounded spike/evidence paths assigned later | queued | — | Prove one-audio-owner capture, mux, latency, sync, drift, fragments, and interruption behavior. |
| `DV-P0B-STORAGE` | unassigned | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | bounded spike/evidence paths assigned later | queued | — | Prove bookmark, destination, capacity, and external-drive behavior. |
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

- Current dependency-ready packets: `DV-P0B-CAPTURE` and
  `DV-P0B-STORAGE`. Their writable ownership must be made disjoint before
  dispatch.
- Product implementation is gated until `DV-P0C-REVIEW` accepts
  `DV-ACTIVE-1`.
- The connected iPhone is reserved for the later dependency-ready Continuity
  Camera runtime gate.
- External-drive availability is not yet established; record it when the
  storage runtime matrix becomes dependency-ready.
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
