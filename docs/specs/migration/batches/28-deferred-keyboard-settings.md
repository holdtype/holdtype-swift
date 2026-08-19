# Batch 28 — Deferred Keyboard Settings

- Node type: leaf
- Status: complete
- Batch ID: `28-deferred-keyboard-settings`
- Change mode: Reconcile
- Source documents: 1
- Source words: 1072
- Read when: batch 28 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 28 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [Keyboard settings snapshot](../../features/ios-keyboard-settings-snapshot.md) — `a8b32a5d38a1bef488cf18d1c6921d5f2e68bd1318112160c3b11e0514892d92`.

## Disposition and protected meaning

- Source: `historical`/`deferred`; current Brand Stage precedence preserved.
- Retain one-way ownership, optional/fail-closed schema, forbidden-data and
  future-lexicon boundaries, fallback, truthful publication/revision, M0B, and
  verification with explicit research-only non-activation.

## Acceptance and next

- One deferred historical hybrid and two children; reachable and ≤100 lines.
- Coverage reaches 53/54 without duplicates/unknowns; source hash matches.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `29-legacy-feature-template`.
