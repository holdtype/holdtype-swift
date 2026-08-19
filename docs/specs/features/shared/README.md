# Shared Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting behavior shared by macOS and current iOS product flows.
- Do not read when: the task is strictly platform presentation or an unmigrated capability.
- Maximum size: 100 physical lines.

Shared contracts define ownership or behavior that platform-specific contracts
may specialize only without weakening their invariants.

## Children

- [Recording durability and interruption](../recording-durability-and-interruption.md) —
  cross-platform terminal causes, audio ownership, teardown, interruption,
  provider authority, and recovery boundaries.
- [OpenAI transcription](../openai-transcription.md) — file-based request,
  prompt composition, secure bounded transport, response, retry, and privacy.
- [Text correction](../text-correction.md) — optional fail-open OpenAI
  correction, local typography, emoji commands, and replacement rules.
- [Text Fixes](../text-fixes.md) — shared catalog, target, processing,
  replacement, and iOS/macOS platform boundaries.
- [Voice emoji commands](../voice-emoji-commands.md) — built-in/custom catalogs,
  prompt hints, local matching, and final-output handoff.

## Pending shared domains

Other shared capabilities remain in the
[legacy authority index](../../index.md) until their bounded batches migrate.

## Dependencies

- [Specification root](../../README.md) — project authority and precedence conventions.
