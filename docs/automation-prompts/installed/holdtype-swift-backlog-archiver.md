---
kind: installed-automation-prompt
automationLayer: per-user-automation-registry
automationId: holdtype-swift-backlog-archiver
status: paused
inspectedDate: 2026-06-22
---

# HoldType Swift Backlog Archiver

## Purpose

Runs the completed-backlog archive workflow, moving verified done task files from active backlog into backlog/done when the archive script reports safe moves.

## Restore Fields

| Field | Value |
| --- | --- |
| id | `holdtype-swift-backlog-archiver` |
| kind | `cron` |
| name | `HoldType Swift Backlog Archiver` |
| status | `PAUSED` |
| rrule | `FREQ=MINUTELY;INTERVAL=15` |
| model | `gpt-5.4-mini` |
| reasoningEffort | `low` |
| executionEnvironment | `local` |
| cwds | `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift` |
| created_at | `1782075144575` / `2026-06-21T20:52:24.575000Z` |
| updated_at | `1783281199718` / `2026-07-05T19:53:19.718000Z` |
| promptSource | `docs/automation-prompts/runbooks/holdtype-swift-backlog-archiver.md` |
| sourceSnapshot | `/Users/eugenepotapenko/.codex/automations/holdtype-swift-backlog-archiver/automation.toml` |
| promptLength | `965` characters |

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
Run one scheduled HoldType Swift Backlog Archiver pass by following the versioned runbook at /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift/docs/automation-prompts/runbooks/holdtype-swift-backlog-archiver.md. The runbook is the runtime contract for reading order, safety limits, archive script, selector readback, verification, checkpoint commits, cleanup, external-sweeper archive handoff, and final report. Stop and report the blocker if the runbook cannot be read. Do not claim backlog tasks, implement product code, resolve blockers, groom tasks, or run the broad MCP cleanup script. Close only resources clearly started by this run. Do not call set_thread_archived from this worker. Finish with the final report only; a separate housekeeping sweeper may archive the completed run later by explicit threadId after readback verification. The final report must include Cleanup for run-owned resources only, plus Thread archive: external_sweeper.
```
