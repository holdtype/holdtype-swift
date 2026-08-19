# Blocked Task Resolution Automation

- Node type: hybrid
- Status: Active
- Contract: `holdtype.operations.blocked-resolution@1`
- Read when: sweeping blocked backlog tasks or recording an unblock path.
- Do not read when: normal implementation selection or general grooming is active.
- Maximum size: 100 physical lines.

## Goal

Prevent blocked tasks from becoming abandoned work. The resolver turns each
selected blocker into completed work, one executable follow-up, a recovered
local-tooling path, or a precise operator-only request.

## Children

- [Sweep and selection](blocked-task-resolution-automation/sweep-and-selection.md)
  — deterministic queue order, bounded reading, recovery, and continuation.
- [Resolution paths](blocked-task-resolution-automation/resolution-paths.md) —
  durable records for tooling, repository, and operator-only blockers.

## Narrow verification batches

The resolver may close stale-verification tasks together only when the same
fresh recovery and bounded command satisfies tasks whose existing resolution
paths explicitly say that pass is sufficient. Exclude unrelated blockers,
runtime-QA blockers, and tasks still needing product implementation.

## Non-goals

Do not replace normal execution, bulk-mark unresolved work done, duplicate
follow-ups, hide external blockers, or let one blocker starve the sweep. No
destructive cleanup, database/storage mutation, or broad process cleanup.
