# HoldType Specification Migration

- Node type: root
- Migration ID: `holdtype-spec-library-2026-08`
- Status: in_progress
- Read when: starting, resuming, reviewing, or completing this migration.
- Do not read when: the task is outside specification migration.
- Change mode: Reconcile
- Approved by: user in the active Codex task on 2026-08-19
- Source specification root: `docs/specs`
- Maximum sources per batch: 3
- Maximum source words per batch: 12000
- Maximum size: 100 physical lines.

## Contract Change Envelope

- User-authorized outcome: migrate all 54 legacy Markdown documents into a selective Markdown-first tree.
- Authorized domains: specification routing and one active semantic batch at a time.
- Protected domains: all product behavior, implementation, QA, releases, and adjacent contracts.
- Product implementation authorization: forbidden.
- Allowed specification delta: faithful structural split, routing metadata, provenance, and explicit dispositions.
- Forbidden specification delta: changed behavior, authority, stability, precedence, compatibility, or release scope.
- Material decisions requiring the user: unresolved Active conflict or required product-meaning change.

## Corpus baseline

- Total documents: 54
- Total words: 146123
- Total lines: 18498
- Oversized documents: 45
- Existing declared nodes before migration: 0
- JSON specification state before migration: 0

## Current checkpoint

- [Batch 02 — recording and History](batches/02-recording-history.md) — completed and ready for checkpoint integration.
- [Latest receipt](receipts/02-recording-history.md) — accepted source hashes, dispositions, nodes, and validation.

## Completed checkpoints

- [Batch 00 — root and menu-bar shell](batches/00-root-menu-bar-shell.md) —
  accepted in [receipt 00](receipts/00-root-menu-bar-shell.md), commit `47ae2215`.
- [Batch 01 — capture controls](batches/01-capture-controls.md) — accepted in
  [receipt 01](receipts/01-capture-controls.md), commit `738c9e32`.

## Pending queue

`03` transcription; `04` output core; `05` text enhancement; `06` privacy;
`07` settings; `08` usage estimates;
`09` Dev Vlogs; `10` diagnostics/QA; `11` distribution; `12` website; `13`
coverage/discovery; `14` backlog automation; `15` automation recovery; `16`
iOS release; `17` iOS Voice; `18` iOS keyboard; `19` iOS settings; `20` iOS
voice/audio; `21` iOS diagnostics; `22` legacy iOS foundations; `23` legacy
iOS privacy; `24` legacy iOS output; `25` legacy iOS history; `26` deferred
iOS history base; `27` deferred iOS failure history; `28` deferred keyboard
settings.

Only the current linked batch is loaded. Activate batch `03` after this
checkpoint is pushed; completed batch bodies are not reloaded.

## Completion

Every source must have one terminal non-deferred disposition; every Active
contract must be reachable; nodes and migration state must remain within 100
lines; links must resolve; no JSON routing state may exist; product
implementation must remain unchanged.
