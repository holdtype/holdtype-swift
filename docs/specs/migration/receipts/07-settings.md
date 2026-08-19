# Receipt 07 — Settings

- Node type: leaf
- Status: accepted
- Batch ID: `07-settings`
- Contract revision: `holdtype.macos.settings-and-secret-storage@1`
- Read when: reviewing batch 07 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/settings-and-secret-storage.md`: SHA-256 `9bb0f524f4afa0b4d35949b8459eb8f675acf4ff4de4e7123b0406d056ebf04b`; `contract`.

## Semantic disposition

- Authority remains Active/Accepted and macOS legacy-released; current iOS
  storage contracts retain precedence.
- Stable inbound path becomes a bounded hybrid. The stale Fixes Restore
  Defaults mention is superseded by the narrower Active Text Fixes contract.

## Created or updated paths

- macOS branch; settings hybrid plus eight responsibility leaves
- migration root, batch 07, and receipt 07

## Validation

- Links, reachability, node size, coverage, hash, protected defaults/identifiers,
  JSON absence, and whitespace are checked before integration.
- Navigation, credential cache/Keychain, automation policy, defaults, device/
  recording bounds, cache/History, local Billing/Diagnostics/Updates, Dev Vlogs
  separation, and iOS precedence remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 37 documents in 21 batches.
- Next: `08-usage-estimates` after push.
