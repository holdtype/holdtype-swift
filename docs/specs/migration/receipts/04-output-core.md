# Receipt 04 — Output Core

- Node type: leaf
- Status: accepted
- Batch ID: `04-output-core`
- Contract revisions: `holdtype.macos.text-output@1`, `holdtype.macos.post-transcription-actions@1`, `holdtype.shared.text-correction@1`
- Read when: reviewing batch 04 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/text-output-workflow.md`: SHA-256 `a907d29971692cd36987384736299d172b68805e6a897e2dc2682dcca75e5419`; `contract`.
- `features/post-transcription-actions.md`: SHA-256 `f625bd8957e5c9022ed273e01776c543c8f6f808687ab44a9680c1f478074402`; `contract`.
- `features/text-correction.md`: SHA-256 `25f0d41382f3d298666b4015f9ba89a84da526f1c6aa08632ad44171058d01e4`; `contract`.

## Semantic disposition

- Authority remains Active; macOS remains legacy-released and shared/iOS
  boundaries retain current precedence.
- Stable inbound paths become bounded hybrids; no semantic Delta exists.

## Created or updated paths

- macOS/shared branch nodes
- text output plus two children
- post-transcription actions plus three children
- text correction plus four children
- migration root, batch 04, and receipt 04

## Validation

- Markdown validator: 1 root, 68 reachable nodes, and 200 valid links.
- Node size: 25–90 lines; no node exceeds 100.
- Cumulative coverage against `fe092f2c`: 54 sources, 12 mapped, 42
  pending, 0 duplicates, and 0 unknown paths.
- All baseline hashes match the pinned source revision.
- Accepted→correction→translation→output ordering, translation strictness,
  correction fail-open behavior, Last Result/system-clipboard separation,
  iOS Library action/status semantics, runtime request boundaries, cancellation,
  timeout, storage, and verification remain represented.
- One reverse Output/History dependency was removed while preserving History as
  a consumer of final accepted output.
- JSON routing state: absent; `git diff --check`: passed.

## Residuals and next batch

- Residual corpus after acceptance: 42 documents in 24 batches.
- Next: `05-text-enhancement` after push.
