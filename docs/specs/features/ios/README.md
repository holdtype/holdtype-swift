# iOS Contract Branch

- Node type: branch
- Status: Active
- Read when: selecting current iOS-only HoldType behavior.
- Do not read when: the task is macOS-only or belongs to an unmigrated iOS domain.
- Maximum size: 100 physical lines.

This branch grows one bounded migration batch at a time. Unmigrated current and
historical/deferred contracts remain selectable through the
[legacy authority index](../../index.md).

## Children

- [Transcription usage estimate](../ios-usage-estimate.md) — local accepted
  audio events, Usage presentation, strict repository, pricing, and Reset.
- [V1.1 release](../ios-v1-release.md) — canonical current scope, navigation,
  cross-feature precedence, privacy, complexity, and release gates.
- [Voice state](../ios-v1-voice-state-persistence.md) — one Pending/Latest,
  stage checkpoints, replay safety, cleanup, and process-loss recovery.
- [Voice Draft](../ios-voice-draft.md) — app-private composed text, editing,
  actions, Voice activity, recovery, accessibility, and presentation.
- [Keyboard handoff](../ios-keyboard-handoff-and-delivery.md) — canonical cold
  launch, app-owned capture, reconnection, destination proof, and delivery.
- [Keyboard experience](../ios-keyboard-experience.md) — subordinate Brand Stage
  composition, local utilities, Fixes, Voice states, and qualification.
- [Settings and secrets](../ios-settings-and-secret-storage.md) — app-owned
  configuration, Library, Keychain, protected records, editors, and setup truth.
- [Settings guided recovery](../ios-settings-guided-recovery.md) — exact owning
  field routing for setup-dependent actions.
- [Voice session and audio](../ios-voice-session-and-audio.md) — current
  foreground capture/audio/provider reference with Quick Session kept Historical.
- [Diagnostics](../ios-diagnostics.md) — local redacted runtime/crash evidence,
  explicit export, bounded retention, and delivery-proof limits.

## Historical foundations

- [Keyboard feasibility](../ios-keyboard-feasibility.md), [shared state](../ios-keyboard-shared-state.md), and [containing app](../ios-containing-app-experience.md) — legacy evidence superseded by current V1.1 contracts.

## Dependencies

- [Specification root](../../README.md) — authority and precedence conventions.
