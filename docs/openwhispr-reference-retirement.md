# OpenWhispr Reference Retirement

Status: historical evidence record

The local copied OpenWhispr snapshot was retired on 2026-08-10. It was an
ignored, untracked research checkout and was never a build, package, runtime,
or release dependency of HoldType.

The snapshot must not be restored or required for normal development, backlog
grooming, investigation, or verification. Current product intent comes from
active specs selected through `docs/specs/index.md`; current realization and
ownership are verified against HoldType source and tests.

## Evidence Migration

The completed reference audits covered the following areas. Their current
authority is:

| Historical audit area | Current authority |
| --- | --- |
| Menu bar and app shell | `docs/specs/features/menu-bar-app-shell.md` |
| Hotkey activation and registration | `docs/specs/features/global-hotkey.md` |
| Recording lifecycle and cancellation | `docs/specs/features/microphone-text-input.md` and `docs/specs/features/recording-durability-and-interruption.md` |
| Clipboard and active-app handoff | `docs/specs/features/text-output-workflow.md` |
| Permission behavior | `docs/specs/features/privacy-and-permissions.md` |
| Settings and secret storage | `docs/specs/features/settings-and-secret-storage.md` |
| Floating recording state | `docs/specs/features/floating-indicator.md` |
| Transcript history and recovery | `docs/specs/features/transcript-history.md` |

Later HoldType specs may intentionally differ from conclusions in the old
reference audit. For example, current text handoff does not use the macOS
system clipboard as fallback storage. The active spec always wins.

## Historical Citations

Completed task records under `backlog/done/` may retain paths such as
`references/openwhispr-main/...`. Those paths identify evidence that was read
when the historical task ran. They are not live links, current instructions,
or a requirement to reconstruct the removed checkout.

`docs/openwhispr_swiftui_codex_tz.md` remains a historical fallback brief for
initial MVP context only. Current active specs take precedence wherever they
settle behavior.
