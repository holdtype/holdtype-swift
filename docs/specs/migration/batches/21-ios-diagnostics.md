# Batch 21 — iOS Diagnostics

- Node type: leaf
- Status: complete
- Batch ID: `21-ios-diagnostics`
- Change mode: Reconcile
- Source documents: 1
- Source words: 1205
- Read when: batch 21 is active or its source disposition is reviewed.
- Do not read when: another batch is active and batch 21 is accepted.
- Maximum size: 100 physical lines.

## Source and hash

- [iOS diagnostics](../../features/ios-diagnostics.md) — `2bbac9854076f0471cb50e69098d4b30296d167fcd6b8babd53eb1719d323446`.

## Disposition and protected meaning

- Source: `contract`, Active.
- Preserve local-only typed/redacted evidence, explicit export, honest crash
  boundary, retention caps, process file ownership, and no delivery inference.

## Acceptance and next

- Stable leaf reachable and ≤100 lines; coverage reaches 42/54 with no duplicates/unknowns.
- Source hash matches; no runtime/log/product/QA or JSON routing-state change.
- After push, activate batch `22-legacy-ios-foundations`.
