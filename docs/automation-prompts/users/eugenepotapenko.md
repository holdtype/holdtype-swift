---
kind: automation-user-inventory
automationLayer: per-user-automation-registry
localUser: eugenepotapenko
status: inspected
---

# eugenepotapenko Automation Inventory

Inventory date: 2026-07-05
Inspected user home: `/Users/eugenepotapenko`
Inspected Codex home: `/Users/eugenepotapenko/.codex`
Repository cwd:
`/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
Inventory status: inspected

## Summary

| Automation id | Name | Status | Schedule | Model | Environment | Prompt snapshot | Runtime runbook |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `holdtype-swift-archive-completed-automation-threads` | HoldType Swift Archive Completed Automation Threads | paused | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.4-mini` / `low` | `local` | `docs/automation-prompts/installed/holdtype-swift-archive-completed-automation-threads.md` | `docs/automation-prompts/runbooks/archive-completed-automation-threads.md` |
| `holdtype-swift-backlog-archiver` | HoldType Swift Backlog Archiver | paused | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.4-mini` / `low` | `local` | `docs/automation-prompts/installed/holdtype-swift-backlog-archiver.md` | `docs/automation-prompts/runbooks/holdtype-swift-backlog-archiver.md` |
| `holdtype-swift-backlog-groomer` | HoldType Swift Backlog Groomer | paused | `FREQ=HOURLY;INTERVAL=2` | `gpt-5.5` / `xhigh` | `local` | `docs/automation-prompts/installed/holdtype-swift-backlog-groomer.md` | `docs/automation-prompts/runbooks/holdtype-swift-backlog-groomer.md` |
| `holdtype-swift-blocker-resolver` | HoldType Swift Blocker Resolver | paused | `FREQ=HOURLY;INTERVAL=1` | `gpt-5.5` / `xhigh` | `local` | `docs/automation-prompts/installed/holdtype-swift-blocker-resolver.md` | `docs/automation-prompts/runbooks/holdtype-swift-blocker-resolver.md` |
| `holdtype-swift-implementer` | HoldType Swift Implementer | paused | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.5` / `xhigh` | `local` | `docs/automation-prompts/installed/holdtype-swift-implementer.md` | `docs/automation-prompts/runbooks/holdtype-swift-implementer.md` |
| `holdtype-swift-tooling-unblocker` | HoldType Swift Tooling Unblocker | paused | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.5` / `xhigh` | `local` | `docs/automation-prompts/installed/holdtype-swift-tooling-unblocker.md` | `docs/automation-prompts/runbooks/holdtype-swift-tooling-unblocker.md` |

Installed automation count for this repository: 6.
Active count for this repository: 0.
Paused count for this repository: 6.

Current-user MCP cleanup gate: only three installed automations may call
`python3 scripts/automation_resource_cleanup.py`:

- `holdtype-swift-implementer`, once at the end of an implementation run;
- `holdtype-swift-tooling-unblocker`, once at the end of a tooling recovery
  run;
- `holdtype-swift-archive-completed-automation-threads`, once at the end of
  each housekeeping run.

The script takes no parameters, ignores processes owned by other OS users, and
runs current-user killall cleanup for the allowlisted Codex helper/MCP process
names.

All other installed automations must not call
`python3 scripts/automation_resource_cleanup.py`. They may only terminate or
close resources clearly started by their own run and must finish with
`Thread archive: external_sweeper`. Only archive-housekeeping may call
`set_thread_archived`, and only for a different readback-verified completed or
safely stale automation thread by explicit `threadId`.

## Installed Automations

### `holdtype-swift-archive-completed-automation-threads`

- Installed status: `PAUSED`
- Schedule: `FREQ=MINUTELY;INTERVAL=15`
- Model / reasoning effort: `gpt-5.4-mini` / `low`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-archive-completed-automation-threads.md`
- Runtime contract: `docs/automation-prompts/runbooks/archive-completed-automation-threads.md`
- Purpose: Archives other completed or safely stale Codex automation threads for this exact repository cwd after readback verification, runs the allowed final resource cleanup gate, and leaves its own run for a later external sweeper.
- Prompt length: `3358` characters

### `holdtype-swift-backlog-archiver`

- Installed status: `PAUSED`
- Schedule: `FREQ=MINUTELY;INTERVAL=15`
- Model / reasoning effort: `gpt-5.4-mini` / `low`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-backlog-archiver.md`
- Runtime contract: `docs/automation-prompts/runbooks/holdtype-swift-backlog-archiver.md`
- Purpose: Runs the completed-backlog archive workflow, moving verified done task files from active backlog into backlog/done when the archive script reports safe moves.
- Prompt length: `965` characters

### `holdtype-swift-backlog-groomer`

- Installed status: `PAUSED`
- Schedule: `FREQ=HOURLY;INTERVAL=2`
- Model / reasoning effort: `gpt-5.5` / `xhigh`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-backlog-groomer.md`
- Runtime contract: `docs/automation-prompts/runbooks/holdtype-swift-backlog-groomer.md`
- Purpose: Maintains small executable backlog/spec/workflow tasks for the macOS MVP without implementing Swift product code.
- Prompt length: `886` characters

### `holdtype-swift-blocker-resolver`

- Installed status: `PAUSED`
- Schedule: `FREQ=HOURLY;INTERVAL=1`
- Model / reasoning effort: `gpt-5.5` / `xhigh`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-blocker-resolver.md`
- Runtime contract: `docs/automation-prompts/runbooks/holdtype-swift-blocker-resolver.md`
- Purpose: Sweeps blocked backlog tasks and either resolves them, records precise operator-only unblock actions, or creates/refines one concrete follow-up task.
- Prompt length: `888` characters

### `holdtype-swift-implementer`

- Installed status: `PAUSED`
- Schedule: `FREQ=MINUTELY;INTERVAL=15`
- Model / reasoning effort: `gpt-5.5` / `xhigh`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-implementer.md`
- Runtime contract: `docs/automation-prompts/runbooks/holdtype-swift-implementer.md`
- Purpose: Runs one selector-approved product implementation iteration with claim/completion checkpoints, verification, cleanup, and external sweeper archive handoff.
- Prompt length: `1305` characters

### `holdtype-swift-tooling-unblocker`

- Installed status: `PAUSED`
- Schedule: `FREQ=MINUTELY;INTERVAL=15`
- Model / reasoning effort: `gpt-5.5` / `xhigh`
- Execution environment: `local`
- Cwd: `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift`
- Prompt snapshot: `docs/automation-prompts/installed/holdtype-swift-tooling-unblocker.md`
- Runtime contract: `docs/automation-prompts/runbooks/holdtype-swift-tooling-unblocker.md`
- Purpose: Repairs local Xcode/build/test/tooling blockers, runs the current-user Codex helper cleanup gate, and reruns a bounded health check so normal backlog automation can proceed.
- Prompt length: `1733` characters

## Missing Or Paused Roles

All six installed automations for this repository are paused until a separate
safe re-enable. No installed automation role is missing in the inspected local
registry.

## Verification

Commands/evidence used:

```sh
rg -n '/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift' /Users/eugenepotapenko/.codex/automations/*/automation.toml
git diff --check
git diff --cached --check
```

The old-phrase audit over `docs/automation-prompts`, `docs/agent-tooling.md`,
and exact-cwd HoldType Swift `automation.toml` files returned no matches.
