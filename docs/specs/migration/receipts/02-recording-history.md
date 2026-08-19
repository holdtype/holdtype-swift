# Receipt 02 — Recording Durability and History

- Node type: leaf
- Status: accepted
- Batch ID: `02-recording-history`
- Contract revisions: `holdtype.shared.recording-durability@2`, `holdtype.macos.transcript-history@1`
- Read when: reviewing batch 02 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/recording-durability-and-interruption.md`: SHA-256 `c3a6e3bb67da0df16896cc252d12a3ec3d759e8e3bf9a9692985e2cafb2a79ef`; `contract`.
- `features/transcript-history.md`: SHA-256 `ec8b5156f9cfe1a75551e275c6883fa09dd64093543e5bde4bbaa0e581e371e2`; `contract`.

## Semantic disposition

- Recording durability remains Active/Accepted at revision 2; macOS portions
  remain legacy-released and current iOS precedence remains external.
- Transcript History remains Active and legacy-released.
- Stable inbound paths become bounded hybrids; no semantic Contract Delta exists.

## Created or updated paths

- `features/README.md`, `features/shared/README.md`, and `features/macos/README.md`
- `features/recording-durability-and-interruption.md` and three child nodes
- `features/transcript-history.md` and seven child nodes
- migration root, batch 02, and receipt 02

## Validation

- Markdown validator: 1 root, 40 reachable nodes, and 142 valid links.
- Node size: 25–90 physical lines; no node exceeds 100.
- Cumulative coverage against `fe092f2c`: 54 sources, 8 mapped, 46
  pending, 0 duplicates, and 0 unknown paths.
- Both baseline hashes match the pinned source revision.
- `DV-DURABILITY-1` through `DV-DURABILITY-4`, every terminal cause,
  destructive boundary, visible recovery state, seal classification, and repair
  outcome remain represented.
- One reverse Capture/History dependency cycle was removed while retaining the
  producer-consumer ownership direction.
- JSON routing state: absent.
- `git diff --check`: passed; scoped diff contains documentation only.

## Residuals and next batch

- Residual corpus after acceptance: 46 documents in 26 batches.
- Next: `03-transcription` after this checkpoint is pushed.
