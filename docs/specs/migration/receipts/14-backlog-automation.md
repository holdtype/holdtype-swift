# Receipt 14 — Backlog Automation

- Node type: leaf
- Status: accepted
- Batch ID: `14-backlog-automation`
- Contract revisions: `holdtype.operations.backlog-grooming@1`, `holdtype.operations.blocked-resolution@1`
- Read when: reviewing batch 14 provenance, validation, or resume state.
- Do not read when: selecting or processing another active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/backlog-grooming-automation.md`: `467bcfc69be15a1dc22079e0ac74f99a00c9ded1b6f04e6c9644b4d1a49f86ca`; `contract`.
- `features/blocked-task-resolution-automation.md`: `896b6ae505fcb7dab7b1066de9e92eb67819372251c2009875b42f0d752b045d`; `contract`.

## Semantic disposition

- Active operational authority remains. Navigation and responsibility splits
  add no behavior or priority change; no Contract Delta exists.

## Created or updated paths

- operations branch; two stable hybrids and four responsibility children;
  product-contract branch; migration root, batch, and receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, hashes, JSON absence, and
  whitespace checked before integration.
- Task shape, archive, coverage truth, sweep ordering, local recovery,
  resolution paths, verification batching, and safety boundaries remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 22 documents in 14 batches.
- Next: `15-automation-recovery` after push.
