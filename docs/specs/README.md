# Feature Specs

This directory is the HoldType product-contract layer. It records expected
user-visible behavior and keeps that behavior separate from implementation and
verification evidence.

## Project Context

HoldType is a native macOS menu bar dictation utility with in-progress iOS
targets. The macOS product is shipped behavior that must not regress. Current
iOS release scope is governed by
[`features/ios-v1-release.md`](features/ios-v1-release.md) and its directly
linked contracts and plans.

Early macOS contracts were seeded from the repository description and
`docs/openwhispr_swiftui_codex_tz.md`. The current checkout contains the real
implementation, so use `docs/specs/brownfield-discovery.md` for repository
orientation and targeted search for exact ownership evidence.

## Registry Conventions

`docs/specs/index.md` is the project registry for selecting product contracts.

- Rows without a historical, legacy, deferred, or draft qualifier are active
  and govern their named product area.
- Rows marked historical, legacy, deferred, or draft are evidence only unless
  a current contract explicitly activates them.
- Explicit `canonical`, `governs`, `wins`, or `supersedes` language defines
  local precedence between overlapping contracts.
- Source hints in the index are ownership-discovery aids, not product
  contracts.

## Contents

This directory contains:

- active product contracts;
- historical or deferred contracts retained as evidence;
- the product-area registry and precedence map;
- product-level invariants, edge cases, failure policies, and compatibility
  boundaries;
- links to representative plans or verification evidence when they are part of
  a domain's routing.

It does not contain:

- agent workflow or orchestration policy;
- queue mechanics;
- Swift engineering rules;
- step-by-step QA procedures;
- implementation-only design notes.

Those live in `AGENTS.md`, `BACKLOG_DEVELOPMENT.md`, `SWIFT.md`, source files,
or QA artifacts as appropriate.

## Structure

```text
docs/specs/
  README.md
  index.md
  brownfield-discovery.md
  backlog.md
  templates/
    feature-spec.md
  features/
    <feature-name>.md
```
