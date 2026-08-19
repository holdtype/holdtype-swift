# Batch 25 — Legacy iOS History

- Node type: leaf
- Status: complete
- Batch ID: `25-legacy-ios-history`
- Change mode: Reconcile
- Source documents: 1
- Source words: 9455
- Read when: batch 25 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 25 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [History and storage](../../features/ios-history-and-storage.md) — `0633369d39198ee104103770ae0002c50955848906df09f23b1ceca8afa25ccd`.

## Disposition and protected meaning

- Source: `historical`/`superseded`; current compact V1.1 precedence preserved.
- Retain History generations/UI, Pending journal/audio, one-shot dispatch,
  P4 app-only acceptance, P4D capture/transfer/relaunch, ownership/retention,
  failure, privacy, and verification evidence without activation.

## Acceptance and next

- One historical hybrid and seven children; reachable and ≤100 lines.
- Coverage reaches 50/54 without duplicates/unknowns; source hash matches.
- No implementation, behavior, release, QA artifact, or JSON routing-state change.
- After push, activate batch `26-deferred-ios-history-foundation`.
