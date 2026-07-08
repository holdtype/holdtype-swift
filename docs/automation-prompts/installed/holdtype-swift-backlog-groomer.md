---
kind: installed-automation-prompt
automationLayer: per-user-automation-registry
automationId: holdtype-swift-backlog-groomer
status: paused
inspectedDate: 2026-06-22
---

# HoldType Swift Backlog Groomer

## Purpose

Maintains small executable backlog/spec/workflow tasks for the macOS MVP without implementing Swift product code.

## Restore Fields

| Field | Value |
| --- | --- |
| id | `holdtype-swift-backlog-groomer` |
| kind | `cron` |
| name | `HoldType Swift Backlog Groomer` |
| status | `PAUSED` |
| rrule | `FREQ=HOURLY;INTERVAL=2` |
| model | `gpt-5.5` |
| reasoningEffort | `xhigh` |
| executionEnvironment | `local` |
| cwds | `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift` |
| created_at | `1781966689120` / `2026-06-20T14:44:49.120000Z` |
| updated_at | `1783281206368` / `2026-07-05T19:53:26.368000Z` |
| promptSource | `docs/automation-prompts/runbooks/holdtype-swift-backlog-groomer.md` |
| sourceSnapshot | `/Users/eugenepotapenko/.codex/automations/holdtype-swift-backlog-groomer/automation.toml` |
| promptLength | `886` characters |

## Recreation Notes

To recreate through the Codex automation tool, use `mode: create` with
the restore fields above. Use the prompt block below exactly as the
`prompt` value. If an automation with the same role already exists, view
that automation first and update it instead of creating a duplicate.

The recorded `id` is the installed local automation id observed at the
snapshot time. If the tool derives ids from names during create, verify
the resulting id after creation and update this file in the same commit.

## Installed Prompt

```text
Run one scheduled HoldType Swift Backlog Groomer pass by following the versioned runbook at /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift/docs/automation-prompts/runbooks/holdtype-swift-backlog-groomer.md. The runbook is the runtime contract for reading order, safety limits, selector/script, verification, checkpoint commits, cleanup, external-sweeper archive handoff, and final report. Stop and report the blocker if the runbook cannot be read. Do not run the broad MCP cleanup script; this automation may close only resources clearly started by this run. Do not call set_thread_archived from this worker. Finish with the final report only; a separate housekeeping sweeper may archive the completed run later by explicit threadId after readback verification. The final report must include Cleanup for run-owned resources only, plus Thread archive: external_sweeper.
```
