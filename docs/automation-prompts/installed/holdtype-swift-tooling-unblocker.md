---
kind: installed-automation-prompt
automationLayer: per-user-automation-registry
automationId: holdtype-swift-tooling-unblocker
status: paused
inspectedDate: 2026-06-22
---

# HoldType Swift Tooling Unblocker

## Purpose

Repairs local Xcode/build/test/tooling blockers and reruns a bounded health check so normal backlog automation can proceed.

## Restore Fields

| Field | Value |
| --- | --- |
| id | `holdtype-swift-tooling-unblocker` |
| kind | `cron` |
| name | `HoldType Swift Tooling Unblocker` |
| status | `PAUSED` |
| rrule | `FREQ=MINUTELY;INTERVAL=15` |
| model | `gpt-5.5` |
| reasoningEffort | `xhigh` |
| executionEnvironment | `local` |
| cwds | `/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift` |
| created_at | `1782072101740` / `2026-06-21T20:01:41.740000Z` |
| updated_at | `1783281226338` / `2026-07-05T19:53:46.338000Z` |
| promptSource | `docs/automation-prompts/runbooks/holdtype-swift-tooling-unblocker.md` |
| sourceSnapshot | `/Users/eugenepotapenko/.codex/automations/holdtype-swift-tooling-unblocker/automation.toml` |
| promptLength | `1733` characters |

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
Run one scheduled HoldType Swift Tooling Unblocker pass by following the versioned runbook at /Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift/docs/automation-prompts/runbooks/holdtype-swift-tooling-unblocker.md. The runbook is the runtime contract for mandatory local tooling recovery, bounded Xcode health check, selector readback, current-user Codex helper cleanup, checkpoint handling when files change, external-sweeper archive handoff, and final report. Fix local Xcode/build/test/simulator/cache/DerivedData/missing-local-tool blockers automatically; do not ask the user to clear local tooling. Mandatory final cleanup gate: after recovery, verification/checkpoint handling, and before the final response, run exactly `python3 scripts/automation_resource_cleanup.py` from the repository root. The script takes no parameters and performs current-user cleanup for Codex MCP/helper processes, including node, node_repl, browser/playwright/xcodebuildmcp/Pencil/Computer Use helpers. Include the cleanup JSON summary and any residual current-user pid/owner/command details; do not inspect or clean processes owned by other OS users; do not claim cleanup succeeded while residual current-user resources remain. Do not perform destructive database or object-storage operations, destructive Git rollback, external account login, payment/account changes, or manual system privacy approval. Do not call set_thread_archived from this worker. Finish with the final report only; a separate housekeeping sweeper may archive the completed run later by explicit threadId after readback verification. The final report must include Cleanup with terminated resources and residual resources, plus Thread archive: external_sweeper.
```
