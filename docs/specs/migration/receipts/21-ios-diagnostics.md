# Receipt 21 — iOS Diagnostics

- Node type: leaf
- Status: accepted
- Batch ID: `21-ios-diagnostics`
- Contract revision: `holdtype.ios.diagnostics@1`
- Read when: reviewing batch 21 provenance, validation, or resume state.
- Do not read when: selecting or processing another active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/ios-diagnostics.md`: `2bbac9854076f0471cb50e69098d4b30296d167fcd6b8babd53eb1719d323446`; `contract`.

## Semantic disposition

- Active local diagnostics authority remains; compaction adds no collection,
  export, retention, privacy, or delivery claim. No Contract Delta exists.

## Created or updated paths

- stable diagnostics leaf; iOS branch; migration root, batch, receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, hash, JSON absence, whitespace checked.
- Scope, typed events, export, retention/storage, privacy/failures, verification remain.

## Residuals and next batch

- Residual corpus after acceptance: 12 documents in 7 batches.
- Next: `22-legacy-ios-foundations` after push.
