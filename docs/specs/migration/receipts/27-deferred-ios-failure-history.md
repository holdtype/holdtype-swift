# Receipt 27 — Deferred iOS Failure History

- Node type: leaf
- Status: accepted
- Batch ID: `27-deferred-ios-failure-history`
- Read when: reviewing batch 27 provenance, validation, or resume state.
- Do not read when: selecting or processing another active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/ios-failed-history-and-retry-audio.md`: `b6e592fb7443965cb8a3d735b023a3b53673b55514d6c6ae464b85b94707d343`; `historical`/`deferred`.

## Semantic disposition

- Failed History/retry audio remains non-authoritative and outside V1.1;
  structural split activates no rows, ownership transfer, Retry train, UI, or
  delivery provenance. No Contract Delta exists.

## Created or updated paths

- one deferred historical hybrid and seven children; iOS branch; migration state.

## Validation

- Links/cycles/reachability/sizes, coverage, hash, JSON absence, whitespace checked.
- Model, transfer, cleanup, cutover, Retry, interlock, lifecycle, privacy,
  isolation, verification, and non-activation evidence remain visible.

## Residuals and next batch

- Residual corpus after acceptance: 2 documents in 2 batches.
- Next: `28-deferred-keyboard-settings` after push.
