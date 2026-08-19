# Blocked Task Resolution Paths

- Node type: leaf
- Status: Active
- Contract: `holdtype.operations.blocked-resolution.paths@1`
- Read when: recording or validating why a blocked task is handled.
- Do not read when: selecting the next blocked task.
- Maximum size: 100 physical lines.

Every handled blocked task has a durable resolution path.

## Automation-recoverable tooling

Record `python3 scripts/local_tooling_recover.py --apply --json`, any local
install/configuration command, the bounded verification immediately retried,
fresh recovery/verification result, and why the blocker remains on failure.

## Repository-solvable blocker

Cite exactly one small follow-up task. It names the original task it unblocks,
`allowed_paths`, acceptance criteria, and verification.

## Operator-only blocker

Record the exact operator action or status check, why local recovery does not
apply, and why a repository task cannot yet help.

Never report handled without one of these complete paths.
