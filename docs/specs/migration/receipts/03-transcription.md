# Receipt 03 — OpenAI Transcription

- Node type: leaf
- Status: accepted
- Batch ID: `03-transcription`
- Contract revision: `holdtype.shared.openai-transcription@1`
- Read when: reviewing batch 03 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Source provenance and disposition

- `features/openai-transcription.md`: SHA-256 `bc5a3ead2c75bdbb896781abffe37b75d551f9faf18a6a767bfb31de180cd6c9`; `contract`.

## Semantic disposition

- Authority remains Active/Accepted; macOS legacy-released and current iOS
  precedence remain protected.
- The stable inbound path becomes a bounded hybrid with eleven leaves.
- No semantic Contract Delta was accepted.

## Created or updated paths

- `features/shared/README.md`
- `features/openai-transcription.md` and eleven child nodes
- migration root, batch 03, and receipt 03

## Validation

- Markdown validator: 1 root, 54 reachable nodes, and 168 valid links.
- Node size: 25–90 physical lines; no node exceeds 100.
- Cumulative coverage against `fe092f2c`: 54 sources, 9 mapped, 45
  pending, 0 duplicates, and 0 unknown paths.
- Baseline hash matches the pinned source revision.
- Exact 25,000,000-byte, 64-KiB, 1-MiB, 902-second, 60-second,
  `0600`/`0700`, one-hour/24-hour, 256-entry, 32-removal, 512-MiB,
  one-second, redirect, lock/link, xattr, filename-grammar, and cleanup bounds
  remain represented.
- Credential, prompt/context, dispatch-seal, recovery, cache, redaction, and
  fake-only automation boundaries remain represented.
- JSON routing state: absent.
- `git diff --check`: passed; scoped diff contains documentation only.

## Residuals and next batch

- Residual corpus after acceptance: 45 documents in 25 batches.
- Next: `04-output-core` after this checkpoint is pushed.
