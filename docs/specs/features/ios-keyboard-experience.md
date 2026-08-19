# iOS Keyboard Experience

- Node type: hybrid
- Status: Active
- Stability: Evolving V1.1 MVP UX
- Contract: `holdtype.ios.keyboard-experience@1`
- Revised: 2026-07-15
- Read when: keyboard Brand Stage composition, controls, or visible states matter.
- Do not read when: deciding launch/capture/reconnection/delivery precedence.
- Maximum size: 100 physical lines.

The canonical handoff contract wins every microphone, launch, reconnection, or
delivery conflict. Provide a compact command keyboard for voice and selected-
text Fixes. App owns microphone/OpenAI/rules/Latest/History; extension owns UI,
one bounded command, transient status, and `UITextDocumentProxy` insertion.

No microphone bypass, manual-session copy, duplicate system Dictation key, or
private/fabricated/indefinite/idle-audio workaround. Signed device must prove
privacy, energy, reliability, and review viability or keyboard dictation is no-go.

HoldType is selected via Globe for dictation, Latest, Fixes, and sentence
editing; system keyboard owns normal layouts. No locale promise. Canonical
History/actions and key/provider/prompts/Library/Pending/canonical Latest stay app-only.

## Children

- [Brand Stage composition](ios-keyboard-experience/composition.md) — zones,
  geometry, adaptive layout, mark, and setup recovery.
- [Quick Insert and Fixes](ios-keyboard-experience/utilities-and-fixes.md) —
  punctuation/emoji/editing/Latest/History and selected-text workspace.
- [Auto and voice session](ios-keyboard-experience/auto-and-session.md) — mode
  popover, artwork/phases, state vocabulary, and microphone arbitration.
- [Shared boundary and failures](ios-keyboard-experience/shared-boundary.md) —
  one-writer projections, privacy, recording, and fallback.
- [Accessibility and release](ios-keyboard-experience/accessibility-and-release.md)
  — appearances, stable rendering, Simulator/device qualification.

## Dependency

- [Canonical handoff](ios-keyboard-handoff-and-delivery.md) — higher-precedence
  microphone and delivery behavior.
