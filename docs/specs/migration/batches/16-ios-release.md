# Batch 16 — iOS Release

- Node type: leaf
- Status: complete
- Batch ID: `16-ios-release`
- Change mode: Reconcile
- Source documents: 1
- Source words: 6038
- Read when: batch 16 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 16 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [iOS V1.1 release](../../features/ios-v1-release.md) — `a34636e0d3530f7e2fff6dca424887bbef52654e6933a1a063981cba41d7a526`.

## Disposition and protected meaning

- Source: `contract`, canonical Active/Accepted current iOS release authority.
- Preserve handoff precedence, exact scope/non-goals, one Pending/Latest,
  20-entry History, cache-off default, Brand Stage, privacy versions, failure
  isolation, signed-device stop gate, and legacy/deferred exclusion.

## Acceptance and next

- Stable hybrid with 13 responsibility children; all reachable and ≤100 lines.
- Coverage reaches 34/54 without duplicates/unknowns; source hash matches.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `17-ios-voice`.
