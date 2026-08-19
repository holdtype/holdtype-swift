# Batch 14 — Backlog Automation

- Node type: leaf
- Status: complete
- Batch ID: `14-backlog-automation`
- Change mode: Reconcile
- Source documents: 2
- Source words: 1392
- Read when: batch 14 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 14 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Backlog grooming](../../features/backlog-grooming-automation.md) — `467bcfc69be15a1dc22079e0ac74f99a00c9ded1b6f04e6c9644b4d1a49f86ca`.
- [Blocked resolution](../../features/blocked-task-resolution-automation.md) — `896b6ae505fcb7dab7b1066de9e92eb67819372251c2009875b42f0d752b045d`.

## Dispositions and protected meaning

- Both sources: `contract`, Active.
- Preserve grooming inputs/task sizing/archive/coverage rules and deterministic
  blocked sweep, local recovery, resolution-path, and non-destructive boundaries.

## Acceptance and next

- Stable hybrid paths; one disposition each; nodes reachable and ≤100 lines.
- Coverage reaches 32/54 without duplicates/unknowns; hashes match.
- No product/source/backlog-body, behavior, or JSON routing-state change.
- After push, activate batch `15-automation-recovery`.
