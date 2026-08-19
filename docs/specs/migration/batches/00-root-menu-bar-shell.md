# Batch 00 — Root and Menu Bar Shell

- Node type: leaf
- Status: complete
- Batch ID: `00-root-menu-bar-shell`
- Change mode: Reconcile
- Source documents: 3
- Source words: 3232
- Read when: batch 00 is active or its source disposition is reviewed.
- Do not read when: another migration batch is active and batch 00 is already accepted.
- Maximum size: 100 physical lines.

## Sources and baseline hashes

- [Specification root](../../README.md) — `d6caad1a78cf33fb9f3323e5b1a825444ff97a357d3df9339a966414d8c1fa67`.
- [Legacy authority index](../../index.md) — `46e4cef50752c1372c0e50d40bddabee65e4b2e3475fba24cb8c9324fd9d4738`.
- [Menu bar app shell](../../features/menu-bar-app-shell.md) — `375cf2173aca415352241b6ac1667b1de718bc4298ff9e24d332e0836b660b64`.

## Intended targets and dispositions

- Root: `contract` — preserved as the canonical Markdown entrypoint.
- Index: `resource` — preserved as the legacy authority and precedence view.
- Menu bar shell: `contract` — preserved at its inbound path as a hybrid with
  lifecycle, primary-controls, and state/status children.

## Protected meaning

- Shipped macOS behavior remains conservatively legacy-released.
- Menu shell stays Active; no command, state, recovery, or quit behavior changes.
- Floating indicator, updates, Dev Vlogs, Fixes, microphone, permissions,
  output, and History remain independently governed dependencies.
- iOS authority and precedence are untouched.

## Acceptance

- Every source has one visible disposition and preserved provenance.
- All created nodes are at most 100 physical lines and linked from the root.
- Source meaning is represented without implementation or behavioral change.
- Coverage against the pinned original source revision reports exactly 3
  represented and 51 pending sources.
- No JSON routing state exists.

## Next

After the scoped checkpoint is pushed, activate batch `01-capture-controls`.
