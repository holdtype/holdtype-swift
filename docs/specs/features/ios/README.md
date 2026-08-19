# iOS Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting current iOS-only HoldType behavior.
- Do not read when: the task is macOS-only or belongs to an unmigrated iOS domain.
- Maximum size: 100 physical lines.

This branch grows one bounded migration batch at a time. Current iOS release,
Voice, keyboard, settings, and historical/deferred contracts remain selectable
through the [legacy authority index](../../index.md) until migrated.

## Children

- [Transcription usage estimate](../ios-usage-estimate.md) — local accepted
  audio events, Usage presentation, strict repository, pricing, and Reset.

## Dependencies

- [Specification root](../../README.md) — authority and precedence conventions.
