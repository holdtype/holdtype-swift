# Feature Specs

- Node type: root
- Status: Active
- Read when: any task may affect HoldType product behavior, state, compatibility, or product QA.
- Do not read when: work is proven behavior-neutral or limited to marketing artifacts.
- Maximum size: 100 physical lines.

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

## Choose the next node

- [Product contracts](features/README.md) — select the smallest migrated
  platform or capability branch.
- [Legacy authority index](index.md) — select contracts and preserve status,
  precedence, and source-ownership hints while migration is in progress.
- [Migration status](migration/README.md) — resume the current bounded
  migration batch without loading completed batches or the corpus.
- [Brownfield discovery](brownfield-discovery.md) — repository orientation
  when ownership is unclear; this is evidence, not product authority.
- [Backlog](backlog.md) — product-area discovery only when backlog work is
  explicitly in scope.
- [Feature-spec template](templates/feature-spec.md) — authoring resource, not
  product authority.

## Layer boundary

This tree contains active contracts, retained historical or deferred evidence,
authority and precedence, product invariants, failure and compatibility rules,
and directly routed product evidence. It excludes agent workflow, queue
mechanics, Swift rules, step-by-step QA, and implementation-only design notes;
those remain in `AGENTS.md`, `BACKLOG_DEVELOPMENT.md`, `SWIFT.md`, source, or
QA artifacts as appropriate.

## Structure

```text
docs/specs/
  README.md
  index.md
  migration/
    README.md
  brownfield-discovery.md
  backlog.md
  templates/
    feature-spec.md
  features/
    README.md
    <platform-or-capability>/README.md
    <legacy-feature>.md
    <legacy-feature>/<responsibility>.md
```

Legacy feature paths remain stable. An oversized legacy contract becomes a
small hybrid at the same path and links responsibility-specific child nodes.
