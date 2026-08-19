# Batch 15 — Automation Recovery

- Node type: leaf
- Status: complete
- Batch ID: `15-automation-recovery`
- Change mode: Reconcile
- Source documents: 1
- Source words: 426
- Read when: batch 15 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 15 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [Automation prompt recovery](../../features/automation-prompt-recovery.md) — `af8f9952d24b7a24a3d1bffe8e3aa1b92a37a2f2c052a8a4e7afc58dd9932746`.

## Disposition and protected meaning

- Source: `contract`, Active.
- Preserve exact-cwd scope, required repository records and restore fields,
  exact prompt reuse, deduplication, verification, update coupling, and secrecy boundary.

## Acceptance and next

- Stable leaf path; one disposition; reachable and ≤100 lines.
- Coverage reaches 33/54 without duplicates/unknowns; hash matches.
- No automation, product/source, behavior, or JSON routing-state change.
- After push, activate batch `16-ios-release`.
