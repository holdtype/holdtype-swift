# QA Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting test, build, runtime, simulator, Computer Use, or fake/manual evidence.
- Do not read when: only product intent or migration status is needed.
- Maximum size: 100 physical lines.

## Children

- [Platform testing strategy](../platform-testing-strategy.md) — smallest-layer
  evidence, macOS runtime decisions, iOS/keyboard gates, and task matrix.
- [Verification strategy](../verification-strategy.md) — deterministic seams,
  no-live automation, bounded waits, and publication separation.
- [UI/functionality coverage map](../ui-functionality-coverage.md) — resource
  linking selected surfaces to likely owners and evidence routes.

## Boundary

QA verifies pinned product contracts; it does not create or weaken intent.
Operational tool commands stay in `docs/agent-tooling.md`.

## Dependency

- [Specification root](../../README.md) — authority and precedence conventions.
