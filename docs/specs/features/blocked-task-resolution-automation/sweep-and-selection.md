# Blocked Resolution Sweep And Selection

- Node type: leaf
- Status: Active
- Contract: `holdtype.operations.blocked-resolution.sweep@1`
- Read when: running or reviewing a blocked-task sweep.
- Do not read when: only the resolution record format is needed.
- Maximum size: 100 physical lines.

## Run

1. Respect repository workflow/canonical checkout and avoid an active claim.
2. Select with `scripts/backlog_blocked_next.py`; read only that task and
   evidence needed for its blocker.
3. Before declaring local Xcode, build service, compiler probe, runner, cache,
   Simulator, DerivedData, utility, or library state blocked, run local recovery.
4. Prefer direct unblock when acceptance is already satisfied and verification
   can safely rerun; otherwise create/refine one blocker-removing follow-up.
5. Record a durable resolution path and keep run-local handled/skipped IDs.
6. After each committed resolution, rerun the selector and continue until every
   current item is resolved, has a refreshed path, or is not safely resolvable.
7. Commit only resolver-owned backlog/spec/workflow or narrowly scoped code.

## Deterministic order

Highest priority wins; ties prefer the task unblocking the most others, then
numeric task ID. The selector's ordered `blocked` array is the sweep queue.
Read bodies one at a time and preserve handled/skipped IDs across reruns.

Normal work remains selected by `scripts/backlog_next.py`; blocked selection
must never make ordinary executor tasks appear ready.
