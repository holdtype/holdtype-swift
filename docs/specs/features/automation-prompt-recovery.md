# Automation Prompt Recovery

- Node type: leaf
- Status: Active
- Contract: `holdtype.operations.automation-recovery@1`
- Read when: recreating or intentionally changing a Codex automation for this repository.
- Do not read when: running an installed automation or working in another repository.
- Maximum size: 100 physical lines.

Keep every installed Codex automation for this repository recoverable from
versioned files without chat history or memory.

## Scope

This contract covers automations whose configured cwd exactly matches:

```text
/Users/eugenepotapenko/Projects/potapenko-github/holdtype-swift
```

Sibling repositories and every other cwd are out of scope.

## Required Repository Records

Keep:

- one per-user inventory under `docs/automation-prompts/users/`;
- one restore-ready prompt snapshot per installed automation under
  `docs/automation-prompts/installed/`;
- the runtime runbooks that short pointer prompts reference under
  `docs/automation-prompts/runbooks/`;
- this contract for the recovery layer.

Each snapshot records automation ID, kind, human-readable name, installed
status, schedule/period (`rrule`), model and reasoning effort, execution
environment, configured cwd, prompt source/runbook when applicable, full
installed prompt, source `automation.toml` path, and inspection date.

## Recovery Behavior

When asked to recreate an automation, an agent must:

1. Read this contract.
2. Read the matching file in `docs/automation-prompts/installed/`.
3. Restore schedule, model, reasoning effort, environment, cwd, status, name,
   and kind from the snapshot.
4. Use the snapshot's `Installed Prompt` block exactly as the automation
   prompt.
5. Prefer updating an existing matching automation over creating a duplicate.
6. View the result and compare every restored field to the snapshot.
7. Commit snapshot changes when the local ID differs or prompt/schedule changes intentionally.

## Update Rule

An intentional change updates these git-backed files in the same task:

- `docs/automation-prompts/users/eugenepotapenko.md`;
- the matching `docs/automation-prompts/installed/<automation-id>.md`;
- the referenced runbook when the prompt delegates behavior to a runbook.

The local registry is live installation state; repository snapshots are the
recovery source and must not be replaced by chat memory.

## Verification

For docs-only recovery registry changes, run:

```sh
git diff --check
```

When the local registry exists, also inspect:

```sh
/Users/eugenepotapenko/.codex/automations/*/automation.toml
```

Compare every exact-cwd automation with its installed snapshot before reporting current.

## Non-Goals

- Do not back up automations for other repositories here.
- Do not run or change scheduled automations just to update the registry.
- Do not store secrets in automation prompts or recovery snapshots.
- Do not use chat memory as a recovery source.
