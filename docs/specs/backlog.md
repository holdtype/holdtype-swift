# Spec Backlog

- Node type: leaf
- Status: Historical resource
- Read when: reviewing initial bootstrap provenance or first-pass planning context.
- Do not read when: selecting executable backlog work or deciding current product behavior.
- Maximum size: 100 physical lines.

This historical planning note came from the initial spec-first bootstrap.
Executable tasks live under root `backlog/` and follow `BACKLOG_DEVELOPMENT.md`;
normal compact selection uses `python3 scripts/backlog_next.py --compact-json`.

## Historical evidence and first pass

- Initial checkout had no implementation, docs, tests, or commits.
- Seed description: “Project for an app for work - text input via microphone”.
- Product brief: `docs/openwhispr_swiftui_codex_tz.md`; Bootstrap reference:
  `https://github.com/potapenko/spec-first-bootstrap`.
- First-pass specs covered microphone, privacy, shell, settings, output,
  post-processing, hotkey, OpenAI, indicator, History, platform testing, and verification.
- No first-pass spec is currently missing from this note; executable backlog
  owns implementation/refinement work.

## Historical queue shape

Umbrella parents described product areas; small children were intended as one
agent checkpoint. The first slice prioritized a visible native menu bar item.
The original note deferred iOS until macOS MVP or direct user reopening; that
statement is historical and does not override current iOS contracts.

Initial unknowns included final name, macOS 14 target, default hotkey,
hold-versus-toggle recording, and later model/timeout QA. Current Active
contracts supersede any item they resolve.
