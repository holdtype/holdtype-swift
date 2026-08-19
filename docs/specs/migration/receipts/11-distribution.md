# Receipt 11 — Distribution

- Node type: leaf
- Status: accepted
- Batch ID: `11-distribution`
- Contract revisions: `holdtype.macos.software-updates@1`, `holdtype.macos.distribution-channel@1`
- Read when: reviewing batch 11 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/software-updates.md`: `b088f937f41b51d42765aced538164c19625357e32b12ae01380eb4a65cdfae0`; `contract`.
- `features/app-store-distribution.md`: `30a745be511eef07227a9cf6e0b59eb306258dad36e927832cd9991335d6796a`; `contract`.

## Semantic disposition

- Active/Accepted direct-distribution and legacy-released update behavior remain.
- Stable inbound paths become bounded hybrids; no semantic Delta exists.

## Created or updated paths

- product/distribution branch; update hybrid plus two children; channel hybrid
  plus two children; migration root, batch, and receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, hashes, artifact names/URLs,
  entitlement/support bounds, JSON absence, and whitespace checked before integration.
- Store prohibition, user trust, Sparkle flow, updater termination, canonical
  artifact, Homebrew, notarization, and final entitlement proof remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 29 documents in 17 batches.
- Next: `12-website` after push.
