# Receipt 17 — iOS Voice

- Node type: leaf
- Status: accepted
- Batch ID: `17-ios-voice`
- Contract revisions: `holdtype.ios.voice-state@1`, `holdtype.ios.voice-draft@1`
- Read when: reviewing batch 17 provenance, validation, or resume state.
- Do not read when: selecting or processing another active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/ios-v1-voice-state-persistence.md`: `35baf101bac25170d481cf9e851abf3ab9f76c5cc70f613f4ccfb1bd9836594d`; `contract`.
- `features/ios-voice-draft.md`: `ead0f64ecde1313f42acc2c5342481814ca30dfc0da22e442991c16a2684f109`; `contract`.

## Semantic disposition

- Approved current Voice authority remains. Splitting adds no persistence,
  presentation, recovery, or acceptance change. No Contract Delta exists.

## Created or updated paths

- two stable hybrids and eight responsibility children; iOS branch; migration
  root, batch, and receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, hashes, JSON absence, and whitespace checked.
- Stage/replay/cleanup safety, Draft mutation/Undo/CAS, Voice activity/modes,
  recovery/accessibility, and acceptance matrices remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 18 documents in 11 batches.
- Next: `18-ios-keyboard` after push.
