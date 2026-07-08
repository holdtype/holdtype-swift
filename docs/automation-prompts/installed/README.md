---
kind: installed-automation-prompt-index
automationLayer: per-user-automation-registry
status: active
inspectedDate: 2026-06-22
---

# Installed Automation Prompt Snapshots

This directory stores the restore-ready prompt snapshot for every installed
Codex automation whose configured cwd exactly matches:

```text
/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift
```

Each file records the schedule, model, reasoning effort, execution
environment, cwd, prompt source, and the full installed prompt. These files
are the durable git-backed recovery source if the local Codex automation
registry is lost.

| Automation id | Snapshot | Schedule | Model | Status |
| --- | --- | --- | --- | --- |
| `holdtype-swift-archive-completed-automation-threads` | `docs/automation-prompts/installed/holdtype-swift-archive-completed-automation-threads.md` | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.4-mini` / `low` | `ACTIVE` |
| `holdtype-swift-backlog-archiver` | `docs/automation-prompts/installed/holdtype-swift-backlog-archiver.md` | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.4-mini` / `low` | `ACTIVE` |
| `holdtype-swift-backlog-groomer` | `docs/automation-prompts/installed/holdtype-swift-backlog-groomer.md` | `FREQ=HOURLY;INTERVAL=2` | `gpt-5.5` / `xhigh` | `ACTIVE` |
| `holdtype-swift-blocker-resolver` | `docs/automation-prompts/installed/holdtype-swift-blocker-resolver.md` | `FREQ=HOURLY;INTERVAL=1` | `gpt-5.5` / `xhigh` | `ACTIVE` |
| `holdtype-swift-implementer` | `docs/automation-prompts/installed/holdtype-swift-implementer.md` | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.5` / `xhigh` | `ACTIVE` |
| `holdtype-swift-tooling-unblocker` | `docs/automation-prompts/installed/holdtype-swift-tooling-unblocker.md` | `FREQ=MINUTELY;INTERVAL=15` | `gpt-5.5` / `xhigh` | `ACTIVE` |

## Verification

When the local Codex automation registry still exists, verify this snapshot
against `/Users/eugenepotapenko/.codex/automations/*/automation.toml` before
changing schedules or prompts. For docs-only edits, the minimum repository
gate remains:

```sh
git diff --check
```
