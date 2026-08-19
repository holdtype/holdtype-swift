# HoldType Specification Migration

- Node type: root
- Migration ID: `holdtype-spec-library-2026-08`
- Status: complete
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

- [Batch 29 — legacy feature template](batches/29-legacy-feature-template.md) — final batch completed and ready for checkpoint integration.
- [Latest receipt](receipts/29-legacy-feature-template.md) — accepted source hash, resource disposition, and terminal validation.

## Completed checkpoints

- [00](batches/00-root-menu-bar-shell.md)/[receipt](receipts/00-root-menu-bar-shell.md) `47ae2215`; [01](batches/01-capture-controls.md)/[receipt](receipts/01-capture-controls.md) `738c9e32`.
- [02](batches/02-recording-history.md)/[receipt](receipts/02-recording-history.md) `8dddb28f`; [03](batches/03-transcription.md)/[receipt](receipts/03-transcription.md) `c8fdb549`.
- [04](batches/04-output-core.md)/[receipt](receipts/04-output-core.md) `f9f4cfe3`; [05](batches/05-text-enhancement.md)/[receipt](receipts/05-text-enhancement.md) `59564e03`.
- [06](batches/06-privacy.md)/[receipt](receipts/06-privacy.md) `6c53171b`; [07](batches/07-settings.md)/[receipt](receipts/07-settings.md) `bb46a2f3`.
- [08](batches/08-usage-estimates.md)/[receipt](receipts/08-usage-estimates.md) `fd3e613e`; [09](batches/09-dev-vlogs.md)/[receipt](receipts/09-dev-vlogs.md) `99ea53a8`.
- [10](batches/10-diagnostics-qa.md)/[receipt](receipts/10-diagnostics-qa.md) `70a02fc2`; [11](batches/11-distribution.md)/[receipt](receipts/11-distribution.md) `32046f3a`.
- [12](batches/12-website.md)/[receipt](receipts/12-website.md) `2d843db2`; [13](batches/13-coverage-discovery.md)/[receipt](receipts/13-coverage-discovery.md) `c637161e`.
- [14](batches/14-backlog-automation.md)/[receipt](receipts/14-backlog-automation.md) `0e7ee66b`; [15](batches/15-automation-recovery.md)/[receipt](receipts/15-automation-recovery.md) `be9ba1a4`.
- [16](batches/16-ios-release.md)/[receipt](receipts/16-ios-release.md) `e5f1b596`.
- [17](batches/17-ios-voice.md)/[receipt](receipts/17-ios-voice.md) `e73cdd6f`.
- [18](batches/18-ios-keyboard.md)/[receipt](receipts/18-ios-keyboard.md) `53f92815`.
- [19](batches/19-ios-settings.md)/[receipt](receipts/19-ios-settings.md) `b153f85c`.
- [20](batches/20-ios-voice-audio.md)/[receipt](receipts/20-ios-voice-audio.md) `b1a9e6f7`.
- [21](batches/21-ios-diagnostics.md)/[receipt](receipts/21-ios-diagnostics.md) `438813da`.
- [22](batches/22-legacy-ios-foundations.md)/[receipt](receipts/22-legacy-ios-foundations.md) `c3b3d1c6`.
- [23](batches/23-legacy-ios-privacy.md)/[receipt](receipts/23-legacy-ios-privacy.md) `9b4b09dc`.
- [24](batches/24-legacy-ios-output.md)/[receipt](receipts/24-legacy-ios-output.md) `b64a118d`.
- [25](batches/25-legacy-ios-history.md)/[receipt](receipts/25-legacy-ios-history.md) `8fa77866`.
- [26](batches/26-deferred-ios-history-foundation.md)/[receipt](receipts/26-deferred-ios-history-foundation.md) `04a349f7`.
- [27](batches/27-deferred-ios-failure-history.md)/[receipt](receipts/27-deferred-ios-failure-history.md) `24ee4a02`.
- [28](batches/28-deferred-keyboard-settings.md)/[receipt](receipts/28-deferred-keyboard-settings.md) `db62918f`.

## Pending queue

None. All 54 baseline documents have one terminal migration disposition; the
final resource batch is linked above.

## Completion

Every source must have one terminal non-deferred disposition; every Active
contract must be reachable; nodes and migration state must remain within 100
lines; links must resolve; no JSON routing state may exist; product
implementation must remain unchanged.

Terminal validation: 54/54 sources covered exactly once, zero missing,
duplicates, unknowns, or deferred migration items. Product-level contracts
whose status is Historical or Deferred remain protected evidence and were not
activated by migration.
