# Receipt 15 — Automation Recovery

- Node type: leaf
- Status: accepted
- Batch ID: `15-automation-recovery`
- Contract revision: `holdtype.operations.automation-recovery@1`
- Read when: reviewing batch 15 provenance, validation, or resume state.
- Do not read when: selecting or processing another active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/automation-prompt-recovery.md`: `af8f9952d24b7a24a3d1bffe8e3aa1b92a37a2f2c052a8a4e7afc58dd9932746`; `contract`.

## Semantic disposition

- Active operational authority remains; compaction and metadata add no
  automation behavior or recovery-source change. No Contract Delta exists.

## Created or updated paths

- Stable recovery leaf; operations branch; migration root, batch, and receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, source hash, JSON absence, and
  whitespace checked before integration.
- Scope, inventory/snapshot/runbook records, restore fields, exact prompt,
  duplicate avoidance, comparison, coupled updates, and non-goals remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 21 documents in 13 batches.
- Next: `16-ios-release` after push.
