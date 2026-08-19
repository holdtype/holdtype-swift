# Backlog Grooming Automation

- Node type: hybrid
- Status: Active
- Contract: `holdtype.operations.backlog-grooming@1`
- Read when: creating or refining executable backlog tasks from current gaps.
- Do not read when: executing a selected task or resolving a blocked task.
- Maximum size: 100 physical lines.

## Goal and inputs

Keep `backlog/` populated with small, implementation-ready tasks derived from
the selected Active specs, current Swift/tests, and fresh selector/task-header
state. Use the historical MVP brief only when Active contracts do not settle
initial behavior. The groomer identifies gaps; it does not implement Swift.

## Children

- [Run and task shape](backlog-grooming-automation/run-and-task-shape.md) —
  ordered workflow, checkpoint sizing, review, and selector closeout.
- [Archive and coverage](backlog-grooming-automation/archive-and-coverage.md) —
  safe completed-task moves and truthful coverage-map rules.

## Evidence and boundaries

The retired OpenWhispr snapshot is provenance only and must not be restored.
Decisions come from Active HoldType specs, current source/tests, and fresh
selector state. Do not introduce Electron, React, Node, Tauri, Rust runtime, or
local-model dependencies unless an Active product contract changes that boundary.

The historical first-iteration bias was a visible native menu-bar item before
deeper services. It remains provenance, not authority over current priorities.

## Non-goals

- No Swift implementation, product-brief rewrite, task deletion, or false `done`.
- No oversized task mixing UI, services, permissions, network, and persistence.

## Dependencies

- [UI/functionality coverage](ui-functionality-coverage.md) — routing resource.
- [Blocked-task resolution](blocked-task-resolution-automation.md) — separate
  automation for tasks already blocked.
