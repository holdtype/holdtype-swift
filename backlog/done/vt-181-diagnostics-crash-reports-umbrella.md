---
id: VT-181
title: Diagnostics And Crash Reports Umbrella
status: done
priority: P1
lane: settings
dependencies:
  - VT-182
  - VT-183
  - VT-184
allowed_paths:
  - backlog/**
  - docs/specs/features/diagnostics-and-crash-reports.md
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/privacy-and-permissions.md
verification:
  - python3 scripts/backlog_next.py --json
  - git diff --check
---

# VT-181 - Diagnostics And Crash Reports Umbrella

Status: done
Priority: P1
Lane: settings
Dependencies: VT-182, VT-183, VT-184
Expected outputs: final diagnostics closeout review after child tasks
Verification: python3 scripts/backlog_next.py --json; git diff --check

## Goal

Close out the Diagnostics and Crash Reports product area after the focused
child tasks land.

## Child Tasks

- VT-182 Diagnostics Settings crash report browser
- VT-183 Diagnostic bundle export
- VT-184 Runtime log diagnostics instrumentation

## Scope

- Review the completed diagnostics implementation against
  `docs/specs/features/diagnostics-and-crash-reports.md`.
- Patch only small spec, backlog, or QA gaps discovered during closeout.
- Record any remaining follow-up tasks for work that should not be widened into
  this umbrella.

## Non-goals

- Implement crash report browsing, bundle export, or runtime logging directly
  in this umbrella while child tasks remain incomplete.
- Add automatic telemetry, analytics, or crash uploads.

## Acceptance

- All child task dependencies are done.
- The selector no longer reports diagnostics child tasks as pending.
- Specs and backlog reflect the implemented behavior.

## Completion Notes

- VT-182, VT-183, and VT-184 are complete.
- The implemented Settings surface follows
  `docs/specs/features/diagnostics-and-crash-reports.md`.
- No automatic telemetry, upload, or destructive crash-report action was added.
- Completed in direct-chat mode to close the backlog records that were created
  before the workflow clarification.
