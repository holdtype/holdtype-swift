# Receipt 08 — Usage Estimates

- Node type: leaf
- Status: accepted
- Batch ID: `08-usage-estimates`
- Contract revisions: `holdtype.macos.openai-usage-estimate@2`, `holdtype.ios.transcription-usage-estimate@1`
- Read when: reviewing batch 08 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/openai-usage-estimate.md`: SHA-256 `fe7ced43bec99787326d72393939f98b4d924f2543fe8baa60a35475ecf96f8f`; `contract`.
- `features/ios-usage-estimate.md`: SHA-256 `734ba352e1e666d167d20130f8b59ddf3831f396a49e4b9ee68ce86c85c14945`; `contract`.

## Semantic disposition

- Both remain Active/Accepted; macOS remains legacy-released and current iOS
  release/Voice/keyboard precedence remains protected.
- Stable inbound paths become bounded hybrids; no semantic Delta exists.

## Created or updated paths

- product/macOS/iOS branch nodes
- macOS usage hybrid plus two children; iOS usage hybrid plus five children
- migration root, batch 08, and receipt 08

## Validation

- Links, reachability, sizes, coverage, hashes, pricing/JSON bounds, JSON routing
  absence, and whitespace are checked before integration.
- Producer timing, exactly-once, frozen/unknown pricing, reset isolation,
  repository ownership, strict wire validation, retention/fencing, privacy, and
  release verifier boundaries remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 35 documents in 20 batches.
- Next: `09-dev-vlogs` after push.
