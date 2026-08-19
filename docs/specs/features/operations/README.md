# Operations Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting backlog or installed-automation behavior.
- Do not read when: selecting product runtime behavior or implementation work.
- Maximum size: 100 physical lines.

## Children

- [Backlog grooming](../backlog-grooming-automation.md) — derives small,
  implementation-ready tasks and maintains truthful coverage routing.
- [Blocked-task resolution](../blocked-task-resolution-automation.md) — sweeps
  blockers into verified completion or durable recovery paths.
- Automation recovery remains in the [authority index](../../index.md) until
  migration batch 15 completes.

## Boundary

These contracts govern operational automation. They do not authorize product
behavior changes, bypass selected-task scope, or make routing resources product intent.

## Dependency

- [Specification root](../../README.md) — authority and precedence conventions.
