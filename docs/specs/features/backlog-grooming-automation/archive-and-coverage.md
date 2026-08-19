# Grooming Archive And Coverage

- Node type: leaf
- Status: Active
- Contract: `holdtype.operations.backlog-grooming.archive@1`
- Read when: archiving completed tasks or claiming a contract gap is covered.
- Do not read when: shaping a new child task only.
- Maximum size: 100 physical lines.

## Completed-task archive

The archive agent uses `scripts/backlog_archive_done.py` in dry-run or apply
mode and moves only clean top-level tasks whose front matter and visible status
both equal `done` into `backlog/done/`. The Markdown record and task ID remain
dependency evidence, but archived tasks are never selectable implementation work.

Skip every non-done status, mismatch, collision, unavailable Git status, or
uncommitted source task. After apply, rerun normal and blocked selectors and
commit only owned moves and archive-tooling changes.

## Truthful coverage

“Covered by existing tasks” requires each contract gap to map to one of:

- a `done` task with current implementation evidence;
- a dependency-ready task selected or selectable by the normal selector; or
- a blocked task with a concrete resolver path and first unblock action in the map.

A blocked or dependency-pending task alone is insufficient. Refine its unblock
path or add one small task that makes the next product delta executable.

The coverage map is navigation, not a substitute for specs or completed work;
it must not call placeholder or disconnected behavior covered.
