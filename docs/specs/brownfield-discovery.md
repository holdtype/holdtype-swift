# Brownfield Discovery

- Node type: hybrid
- Status: Current resource
- Read when: repository ownership is unclear after a product contract path is selected.
- Do not read when: choosing product intent, backlog state, or broad source inventory.
- Maximum size: 100 physical lines.

This is a non-exhaustive orientation aid, never product authority and never a
replacement for targeted `rg`/`rg --files` discovery before implementation.

## Repository shape

- Root: `HoldType.xcodeproj`, spec-first docs, backlog, automations, scripts,
  and reference material.
- Targets: macOS `HoldType`, iOS `HoldType-iOS`, `HoldTypeTests`, and
  `HoldTypeIOSTests`; primary scheme `HoldType`.
- Current macOS and iOS scope is selected from Active contracts, not historical
  statements in this map.

## Children

- [Source and test map](brownfield-discovery/source-and-test-map.md) — entry,
  presentation, model/service, shared, iOS, and test ownership hints.

## Routing and verification

Start at [spec index](index.md), read only the governing contract closure, then
use targeted source discovery. The old OpenWhispr snapshot is retired and must
not be recreated; its brief is fallback evidence only.

Backlog/automation uses its own runbooks and compact selector. Baseline Swift
verification is macOS build (and matching tests when touched) plus
`git diff --check`; docs/spec-only normally uses diff check.
