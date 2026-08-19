# macOS Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting shipped macOS-only HoldType behavior.
- Do not read when: the task is iOS-only or belongs to an unmigrated shared capability.
- Maximum size: 100 physical lines.

macOS is the shipped product boundary. Migration preserves its existing public
behavior conservatively as legacy-released until an explicit release baseline
records finer-grained revisions.

## Children

- [Menu bar app shell](../menu-bar-app-shell.md) — menu bar lifecycle, primary
  commands, compact state and status, recovery, and quit behavior.

## Pending macOS domains

Other macOS and shared contracts remain selectable through the
[legacy authority index](../../index.md) until their own batches are migrated.

## Dependencies

- [Specification root](../../README.md) — project-wide status and precedence
  conventions.
