# Batch 10 — Diagnostics And QA

- Node type: leaf
- Status: complete
- Batch ID: `10-diagnostics-qa`
- Change mode: Reconcile
- Source documents: 3
- Source words: 3780
- Read when: batch 10 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 10 is accepted.
- Maximum size: 100 physical lines.

## Sources and hashes

- [Diagnostics](../../features/diagnostics-and-crash-reports.md) — `75b42da5fa99af8f357c73051ef50259ea3aa806f388179394cc26962ce71a64`.
- [Platform testing](../../features/platform-testing-strategy.md) — `af5c2547ccf6b5e2ee75b5e021319c63208c45e927c1711b0adcc16455fd1693`.
- [Verification](../../features/verification-strategy.md) — `852ea0234f14e9d4a469b9a5d7da9dabe0e997340f479fd8d13032c2f0f94b96`.

## Dispositions and protected meaning

- All three: `contract`; each retains its inbound path as a bounded hybrid.
- Preserve read-only local diagnostics, 7-day/5-MB logs, 48-hour bundle,
  smallest-layer evidence, runtime-QA decision, iOS product isolation,
  fake-first/no-live boundaries, bounded waits, and publication separation.

## Acceptance and next

- One disposition per source; nodes reachable and ≤100 lines.
- Coverage reaches 23/54 without duplicates/unknowns; hashes match.
- No behavior, implementation, QA requirement, or JSON routing state changes.
- After push, activate batch `11-distribution`.
