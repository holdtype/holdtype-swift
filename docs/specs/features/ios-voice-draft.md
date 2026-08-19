# iOS Voice Draft

- Node type: hybrid
- Status: Active
- Stability: Accepted
- Contract: `holdtype.ios.voice-draft@1`
- Revised: 2026-07-16
- Read when: containing-app Voice composition, Draft editing, actions, or presentation matters.
- Do not read when: only keyboard-host insertion or canonical Latest matters.
- Maximum size: 100 physical lines.

Make Voice the useful default iPhone screen for dictating, reviewing one
composed text, copying it, and continuing without opening the custom keyboard.

Voice is first on cold/new scene; background return preserves tab. History is
separate with no Voice preview/duplicate action. Bottom leading `Auto` and
trailing labeled Copy remain intrinsic; top leading Fixes/Undo/Redo and trailing
neutral labeled Clear remain. Compact/large type may wrap the leading group but
never absorb/unlabel Clear. Keyboard session/practice live in a Voice More sheet,
never primary canvas.

## Children

- [Draft and editing](ios-voice-draft/draft-and-editing.md) — adaptive editor,
  follow-tail, focus, Replace/Append, Copy/Clear, durability, CAS, and Undo.
- [Primary control](ios-voice-draft/primary-control.md) — fixed activity geometry,
  phases, microphone validation, and truthful recovery states.
- [Session modes and Fixes](ios-voice-draft/session-modes-and-fixes.md) — Auto
  modes, start-time freeze/clear, selected-range actions, and failure isolation.
- [Recovery and verification](ios-voice-draft/recovery-and-verification.md) —
  Settings routing, accessibility/appearance, and required evidence.

## Dependencies

- [V1.1 release](ios-v1-release.md) — release scope and accepted-result ordering.
- [Voice state](ios-v1-voice-state-persistence.md) — Pending/Latest recovery.
- [Text Fixes](text-fixes.md) — enabled action catalog/provider behavior.
