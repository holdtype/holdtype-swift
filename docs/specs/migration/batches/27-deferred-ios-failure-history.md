# Batch 27 — Deferred iOS Failure History

- Node type: leaf
- Status: complete
- Batch ID: `27-deferred-ios-failure-history`
- Change mode: Reconcile
- Source documents: 1
- Source words: 9422
- Read when: batch 27 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 27 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [Failed History and retry audio](../../features/ios-failed-history-and-retry-audio.md) — `b6e592fb7443965cb8a3d735b023a3b53673b55514d6c6ae464b85b94707d343`.

## Disposition and protected meaning

- Source: `historical`/`deferred`; current single-Pending V1.1 precedence preserved.
- Retain failed model/mapping, strict record/Pending transfer, tombstone/cutover,
  explicit one-shot Retry, accepted-output interlock, lifecycle/app boundary,
  privacy/isolation, and verification with explicit non-activation.

## Acceptance and next

- One deferred historical hybrid and seven children; reachable and ≤100 lines.
- Coverage reaches 52/54 without duplicates/unknowns; source hash matches.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `28-deferred-keyboard-settings`.
