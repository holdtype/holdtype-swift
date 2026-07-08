---
kind: automation-project-index
automationLayer: per-user-automation-registry
status: active
---

# Automation Prompts

This folder records installed Codex automations that run against this HoldType
Swift checkout.

Repository cwd:
`/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`

Runtime runbooks:

- `runbooks/archive-completed-automation-threads.md`
- `runbooks/holdtype-swift-backlog-archiver.md`
- `runbooks/holdtype-swift-backlog-groomer.md`
- `runbooks/holdtype-swift-blocker-resolver.md`
- `runbooks/holdtype-swift-implementer.md`
- `runbooks/holdtype-swift-tooling-unblocker.md`

Restore-ready installed prompt snapshots:

- `installed/README.md`
- `installed/holdtype-swift-archive-completed-automation-threads.md`
- `installed/holdtype-swift-backlog-archiver.md`
- `installed/holdtype-swift-backlog-groomer.md`
- `installed/holdtype-swift-blocker-resolver.md`
- `installed/holdtype-swift-implementer.md`
- `installed/holdtype-swift-tooling-unblocker.md`

Shared tooling guidance:

- `../agent-tooling.md`

Recovery spec:

- `../specs/features/automation-prompt-recovery.md`

Only the implementer, tooling-unblocker, and archive-housekeeping automations
may run `python3 scripts/automation_resource_cleanup.py`. Information-gathering,
backlog-grooming, blocker-resolution, and backlog-archiver automations must not
call that script because broad current-user `killall` cleanup can conflict with
other concurrent work. Every automation should still keep MCP use task-specific,
terminate or close resources clearly started by the current run, report residual
run-owned resources, and finish with a final report that includes
`Thread archive: external_sweeper`. Normal workers must not call
`set_thread_archived`. Archive-housekeeping may call `set_thread_archived` only
for a different readback-verified completed or safely stale automation thread,
using an explicit `threadId`; it must report
`self_archive=skipped_external_sweeper` for its own current run.

Per-user inventories:

- `users/eugenepotapenko.md`
