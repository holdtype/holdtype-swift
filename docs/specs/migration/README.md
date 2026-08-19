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

- [Batch 16 — iOS release](batches/16-ios-release.md) — completed and ready for checkpoint integration.
- [Latest receipt](receipts/16-ios-release.md) — accepted source hash, disposition, nodes, and validation.

## Completed checkpoints

- [Batch 00 — root and menu-bar shell](batches/00-root-menu-bar-shell.md) —
  accepted in [receipt 00](receipts/00-root-menu-bar-shell.md), commit `47ae2215`.
- [Batch 01 — capture controls](batches/01-capture-controls.md) — accepted in
  [receipt 01](receipts/01-capture-controls.md), commit `738c9e32`.
- [Batch 02 — recording and History](batches/02-recording-history.md) — accepted
  in [receipt 02](receipts/02-recording-history.md), commit `8dddb28f`.
- [Batch 03 — OpenAI transcription](batches/03-transcription.md) — accepted in
  [receipt 03](receipts/03-transcription.md), commit `c8fdb549`.
- [Batch 04 — output core](batches/04-output-core.md) — accepted in
  [receipt 04](receipts/04-output-core.md), commit `f9f4cfe3`.
- [Batch 05 — text enhancement](batches/05-text-enhancement.md) — accepted in
  [receipt 05](receipts/05-text-enhancement.md), commit `59564e03`.
- [Batch 06 — privacy](batches/06-privacy.md) — accepted in
  [receipt 06](receipts/06-privacy.md), commit `6c53171b`.
- [Batch 07 — settings](batches/07-settings.md) — accepted in
  [receipt 07](receipts/07-settings.md), commit `bb46a2f3`.
- [Batch 08 — usage estimates](batches/08-usage-estimates.md) — accepted in
  [receipt 08](receipts/08-usage-estimates.md), commit `fd3e613e`.
- [Batch 09 — Dev Vlogs](batches/09-dev-vlogs.md) — accepted in
  [receipt 09](receipts/09-dev-vlogs.md), commit `99ea53a8`.
- [Batch 10 — diagnostics and QA](batches/10-diagnostics-qa.md) — accepted in
  [receipt 10](receipts/10-diagnostics-qa.md), commit `70a02fc2`.
- [Batch 11 — distribution](batches/11-distribution.md) — accepted in
  [receipt 11](receipts/11-distribution.md), commit `32046f3a`.
- [Batch 12 — website](batches/12-website.md) — accepted in
  [receipt 12](receipts/12-website.md), commit `2d843db2`.
- [Batch 13 — coverage and discovery](batches/13-coverage-discovery.md) —
  accepted in [receipt 13](receipts/13-coverage-discovery.md), commit `c637161e`.
- [Batch 14 — backlog automation](batches/14-backlog-automation.md) — accepted
  in [receipt 14](receipts/14-backlog-automation.md), commit `0e7ee66b`.
- [Batch 15 — automation recovery](batches/15-automation-recovery.md) — accepted
  in [receipt 15](receipts/15-automation-recovery.md), commit `be9ba1a4`.

## Pending queue

`17` iOS Voice; `18` iOS keyboard; `19` iOS settings; `20` iOS
voice/audio; `21` iOS diagnostics; `22` legacy iOS foundations; `23` legacy
iOS privacy; `24` legacy iOS output; `25` legacy iOS history; `26` deferred
iOS history base; `27` deferred iOS failure history; `28` deferred keyboard
settings.

Only the current linked batch is loaded. Activate batch `17` after this
checkpoint is pushed; completed batch bodies are not reloaded.

## Completion

Every source must have one terminal non-deferred disposition; every Active
contract must be reachable; nodes and migration state must remain within 100
lines; links must resolve; no JSON routing state may exist; product
implementation must remain unchanged.
