# Agent Onboarding

This is the short startup checklist for HoldType Swift work. It is a routing
guide, not a request to preload the whole repository.

## Context Budget

Read only the files needed for the current request.

Do not read these by default:

- all feature specs;
- `backlog/done/` task bodies;
- all automation runbooks;
- `docs/openwhispr_swiftui_codex_tz.md`;
- `references/openwhispr-main/`;
- `DerivedData/` or generated build artifacts.

Use `rg` and `rg --files` for discovery because they respect repository ignore
rules.

## Direct Chat Work

Ordinary live-chat requests are direct tasks unless the user explicitly asks to
use backlog or the active automation/runbook says it is a backlog worker.

For direct-chat work:

1. Read `AGENTS.md`.
2. Read this file.
3. For a product feature, behavioral bug, behavioral investigation,
   product-behavior plan, or potentially behavioral refactor, read
   `docs/specs/README.md`, `docs/specs/index.md`, and the active relevant specs
   before opening implementation source.
4. State the Spec Basis: authoritative paths, expected behavior, invariants,
   gaps or conflicts, and spec impact. If the contract is missing or
   conflicting, settle it in the specs before implementation.
5. Read `SWIFT.md` after the Spec Basis and before Swift, SwiftUI, AppKit,
   Xcode project, or test changes.
6. Use `docs/specs/brownfield-discovery.md` only as a current repo map when
   ownership is unclear.
7. Read `docs/agent-tooling.md` only when choosing Xcode, MCP, runtime QA, or
   Computer Use tooling. Its `iOS Simulator, Mirroring, And Physical Device QA`
   section is mandatory before any iOS interactive or device qualification.
8. Inspect source, tests, history, and runtime evidence only after the Spec
   Basis. Use them to establish actual behavior and ownership, not product
   intent.
9. Implement the requested scope directly without creating backlog files, but
   do not cross a planning-only or investigation-only boundary.
10. Run task-appropriate verification.
11. Stage and commit only files changed for the current task.

## Backlog Work

Use backlog mode only for explicit backlog requests, scheduled backlog
automation, backlog file/script/runbook maintenance, or user-approved
restartable task queues.

For backlog work:

1. Read `AGENTS.md`, this file, and `BACKLOG_DEVELOPMENT.md`.
2. Run compact selector readback:

   ```sh
   python3 scripts/backlog_next.py --compact-json
   ```

3. If compact output is insufficient for queue debugging, rerun with full
   `--json`.
4. If `expired_in_progress_reset_paths` is non-empty, run `git diff --check`,
   stage only those reset task files, create a scoped repair commit, and rerun
   the compact selector before claiming work.
5. Claim exactly the selected task before reading its body.
6. Read only the selected task body and task-relevant specs, state the Spec
   Basis, and only then open task-relevant source files.

## Current Project Shape

The active product phase is the native macOS menu bar MVP. The repository now
contains real macOS services, settings surfaces, models, and tests; do not rely
on older bootstrap notes that describe only a minimal template. Use
`docs/specs/brownfield-discovery.md` for the current map, then verify exact file
ownership with `rg --files`.

Use copied OpenWhispr files only as behavior reference evidence. The Swift app
must stay native and must not inherit Electron, React, Node.js, updater,
accounts, billing, telemetry, or local model downloader behavior unless a
future spec explicitly changes scope.
