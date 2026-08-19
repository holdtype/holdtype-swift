# Receipt 05 — Text Enhancement

- Node type: leaf
- Status: accepted
- Batch ID: `05-text-enhancement`
- Contract revisions: `holdtype.shared.text-fixes@3`, `holdtype.macos.text-fixes-writing-skill@1`, `holdtype.shared.voice-emoji-commands@1`
- Read when: reviewing batch 05 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/text-fixes.md`: SHA-256 `e78f990d8ccc0fe30b2f4bc7a6ceeaafaa5d4aa70257431c493af677ea8b6a9b`; `contract`.
- `features/text-fixes-writing-skill.md`: SHA-256 `81d23a70ed89304cbfbae7a456c3d3c2b1fe8193d84689d3a1808f438ea239bc`; `contract`.
- `features/voice-emoji-commands.md`: SHA-256 `4e1a212947e63539938c05e70b96c9045f03d1038fa6b2f0a395568df22a4c70`; `contract`.

## Semantic disposition

- Authority remains Active/Accepted; macOS remains legacy-released and
  current iOS contracts retain narrower precedence.
- Stable inbound paths become bounded hybrids/leaves; no semantic Delta exists.

## Created or updated paths

- macOS/shared branch nodes
- Text Fixes plus six children
- writing-skill addendum
- voice emoji commands plus two children
- migration root, batch 05, and receipt 05

## Validation

- Markdown links, reachability, node size, cumulative coverage, baseline hashes,
  protected identifiers/bounds, JSON absence, and whitespace are checked before integration.
- Target capture, exact output, stale/one-time replacement, consent/privacy,
  Voice Prompt, Humanize, keyboard release gate, emoji matching/pipeline, and
  current iOS precedence remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 39 documents in 23 batches.
- Next: `06-privacy` after push.
