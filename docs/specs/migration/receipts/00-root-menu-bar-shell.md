# Receipt 00 — Root and Menu Bar Shell

- Node type: leaf
- Status: accepted
- Batch ID: `00-root-menu-bar-shell`
- Contract revision: `holdtype.macos.menu-bar-shell@1`
- Read when: reviewing batch 00 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance

- `docs/specs/README.md`: source SHA-256 `d6caad1a78cf33fb9f3323e5b1a825444ff97a357d3df9339a966414d8c1fa67`; disposition `contract`.
- `docs/specs/index.md`: source SHA-256 `46e4cef50752c1372c0e50d40bddabee65e4b2e3475fba24cb8c9324fd9d4738`; disposition `resource`.
- `docs/specs/features/menu-bar-app-shell.md`: source SHA-256 `375cf2173aca415352241b6ac1667b1de718bc4298ff9e24d332e0836b660b64`; disposition `contract`.

## Semantic disposition

- Authority remains Active; macOS behavior remains legacy-released.
- The root and index retain their legacy inbound paths.
- The menu shell retains its path and becomes a hybrid linking three bounded
  responsibilities.
- No product behavior, implementation, precedence, or release scope changed.

## Created or updated nodes

- `docs/specs/README.md`
- `docs/specs/index.md`
- `docs/specs/features/README.md`
- `docs/specs/features/macos/README.md`
- `docs/specs/features/menu-bar-app-shell.md`
- `docs/specs/features/menu-bar-app-shell/lifecycle.md`
- `docs/specs/features/menu-bar-app-shell/primary-controls.md`
- `docs/specs/features/menu-bar-app-shell/state-and-status.md`
- `docs/specs/migration/README.md`
- `docs/specs/migration/batches/00-root-menu-bar-shell.md`
- `docs/specs/migration/receipts/00-root-menu-bar-shell.md`

## Validation

- Markdown validator: 1 root, 11 reachable nodes, and 43 valid links.
- Node size: 26–90 physical lines; no node exceeds 100.
- Coverage against source revision `fe092f2c`: 54 sources, 3 mapped, 51
  pending, 0 duplicates, and 0 unknown paths.
- Baseline source hashes match the pinned revision; no source drift was hidden.
- JSON routing state: absent.
- Stable source clause IDs `DOCK-1`–`DOCK-3` and `DV-MENU-1`–`DV-MENU-3`
  remain represented, including the `1A`, `2A`, and shipping boundaries.
- `git diff --check`: passed; scoped diff contains documentation only.

## Residuals and next batch

- Residual corpus: 51 documents in 28 bounded batches.
- Next: `01-capture-controls` after this receipt is validated, committed, and pushed.
