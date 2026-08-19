# Receipt 01 — Capture Controls

- Node type: leaf
- Status: accepted
- Batch ID: `01-capture-controls`
- Contract revisions: `holdtype.macos.microphone-input@1`, `holdtype.macos.global-hotkey@1`, `holdtype.macos.floating-indicator@1`
- Read when: reviewing batch 01 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/microphone-text-input.md`: SHA-256 `6b53d6f060c92e47f0957559739ef1c662966d1634f3bc6a4ec9e26c2ff1d85c`; `contract`.
- `features/global-hotkey.md`: SHA-256 `a98b39bbce33a4580ee5a02e43d113167565953fcd374a8bca528a9efa08afd7`; `contract`.
- `features/floating-indicator.md`: SHA-256 `c9ce692af387d566fd08c5c8b7749c4ec5edd9d41b4b7bc43f66545b9cdafa44`; `contract`.

## Semantic disposition

- Authority remains Active and shipped macOS behavior remains legacy-released.
- Stable inbound paths become bounded hybrids with ordinary child links.
- Existing numeric limits, shortcuts, clause IDs, destructive boundaries,
  fallback behavior, state mappings, and protected dependencies are retained.
- No semantic Contract Delta was accepted.

## Created or updated paths

- `features/macos/README.md`
- `features/microphone-text-input.md` and four child nodes
- `features/global-hotkey.md` and three child nodes
- `features/floating-indicator.md` and two child nodes
- `migration/README.md`
- `migration/batches/01-capture-controls.md`
- `migration/receipts/01-capture-controls.md`

## Validation

- Markdown validator: 1 root, 25 reachable nodes, and 103 valid links.
- Node size: 26–90 physical lines; no node exceeds 100.
- Cumulative coverage against `fe092f2c`: 54 sources, 6 mapped, 48
  pending, 0 duplicates, and 0 unknown paths.
- All three baseline hashes match the pinned source revision.
- `DV-AUDIO-LEASE-1` and `DV-AUDIO-LEASE-2`, all numeric duration and
  countdown limits, shortcut defaults, permission fallbacks, and state-table
  outcomes remain represented.
- Dependency validation found and removed one reverse Menu Bar/Indicator cycle
  while preserving menu-owned fallback status.
- JSON routing state: absent.
- `git diff --check`: passed; scoped diff contains documentation only.

## Residuals and next batch

- Residual corpus after acceptance: 48 documents in 27 batches.
- Next: `02-recording-history` after this checkpoint is pushed.
