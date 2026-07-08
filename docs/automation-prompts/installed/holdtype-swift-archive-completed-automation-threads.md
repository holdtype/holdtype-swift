---
kind: installed-automation-prompt
automationLayer: per-user-automation-registry
automationId: holdtype-swift-archive-completed-automation-threads
status: paused
inspectedDate: 2026-06-22
---

# HoldType Swift Archive Completed Automation Threads

## Purpose

Archives other completed or safely stale Codex automation threads for this exact repository cwd after readback verification, runs the allowed final resource cleanup gate, and leaves its own run for a later external sweeper.

## Restore Fields

| Field | Value |
| --- | --- |
| id | `holdtype-swift-archive-completed-automation-threads` |
| kind | `cron` |
| name | `HoldType Swift Archive Completed Automation Threads` |
| status | `PAUSED` |
| rrule | `FREQ=MINUTELY;INTERVAL=15` |
| model | `gpt-5.4-mini` |
| reasoningEffort | `low` |
| executionEnvironment | `local` |
| cwds | `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift` |
| created_at | `1782068006109` / `2026-06-21T18:53:26.109000Z` |
| updated_at | `1783281238028` / `2026-07-05T19:53:58.028000Z` |
| promptSource | `docs/automation-prompts/runbooks/archive-completed-automation-threads.md` |
| sourceSnapshot | `/Users/eugenepotapenko/.codex/automations/holdtype-swift-archive-completed-automation-threads/automation.toml` |
| promptLength | `3358` characters |

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
Run one current-repository-only HoldType Swift archive-housekeeping pass by following the versioned runbook at /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift/docs/automation-prompts/runbooks/archive-completed-automation-threads.md. The runbook is the runtime contract for current-user MCP cleanup, thread-tool discovery, sequential thread-management calls, current-repository installed automation inventory, readback safety gates, explicit-threadId archiving, read-only registry candidate discovery, stale interrupted and stale hanging automation-run handling, visible-page counting, installed housekeeping automation readback, external-sweeper self handling, and final reporting. Scope is exact cwd only: /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift. Mandatory final cleanup gate: after archive verification/report preparation and before the final response, run exactly `python3 scripts/automation_resource_cleanup.py` from the repository root. Include the cleanup JSON summary and any residual current-user pid/owner/command details; do not inspect or clean processes owned by other OS users. Do not inspect, read, archive, or count Codex threads from any other repository cwd.

Call thread-management tools sequentially only: do not call list_threads/read_thread/set_thread_archived through parallel wrappers, and do not run them in parallel with shell/file reads. Archive only a different completed or safely stale automation thread after read_thread verification and only by calling set_thread_archived with archived true and that candidate's explicit threadId. Never call set_thread_archived without threadId, and never pass the current housekeeping run threadId. If list_threads, read_thread, or set_thread_archived is unavailable or hangs, stop without applying archive changes and report the tool blocker. Do not write ad hoc SQLite queries or direct registry updates.

The local registry helper may be used only as read-only candidate discovery: python3 scripts/archive_codex_threads.py --target-cwd /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift --json. Do not pass --apply from this automation. Every registry-discovered candidate still requires read_thread verification, and archive apply must be set_thread_archived with that candidate's explicit threadId.

Acceptance rule for this automation: one run archives the entire readback-verified eligible batch it can safely reach. Do not stop after one thread id, one page, one default-size result set, or one archived chat. Treat active, pending, manual, or ambiguous current-repository candidates as skip reasons, not as a reason to abandon archiving separate readback-verified eligible threads in the same batch. Manual/user chats must remain skipped_manual_or_unclear, not archived.

At the end, do not archive this current housekeeping automation thread. Finish with the final report only; a later housekeeping invocation from a different thread may archive this completed run by explicit threadId after readback verification. The final report must include Cleanup with terminated resources and residual resources, first_visible_page_eligible_count, visible_page_eligible_count, archived_count, registry_candidate_count, registry_unhandled_candidate_count, registry_allowed_active_count, blocker, and self_archive=skipped_external_sweeper.
```
