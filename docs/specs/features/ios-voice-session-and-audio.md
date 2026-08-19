# iOS Voice Session And Audio

- Node type: hybrid
- Status: Active foreground-audio reference
- Contract: `holdtype.ios.voice-audio@1`
- Read when: foreground capture, audio-session lifecycle, provider handoff, or recovery matters.
- Do not read when: expanding V1.1 with standalone Quick Session behavior.
- Maximum size: 100 physical lines.

V1.1 release is authoritative. Every Quick Session clause here is Historical
exploration and supplies no duration or product requirement absent new review/
Active update. Goal: reliable foreground dictation without hidden microphone or
lost completed recording.

Scope: one-shot app recording, 1–15 minute max (default five), audio lifecycle,
cues/tail/interruption/routes/lock/background, completed journal/provider handoff,
cancel/recovery. No extension microphone, streaming, indefinite background,
silence endpointing, microphone-held networking, or bypassed device gates.

## Children

- [Foreground capture](ios-voice-session-and-audio/foreground-capture.md) — Start,
  tail/Cancel/limit, descriptor validity, durable completion.
- [Preflight](ios-voice-session-and-audio/preflight.md) — ordered process-owned admission.
- [Audio session](ios-voice-session-and-audio/audio-session.md) — configuration,
  routes, warnings, interruptions, finalization assertion.
- [Adapter gate](ios-voice-session-and-audio/adapter-gate.md) — target isolation,
  permission, recorder feasibility, descriptor proof.
- [Production composition](ios-voice-session-and-audio/production-composition.md)
  — owners, scenes, launch recovery, credentials, local checkpoints.
- [Lifecycle and actions](ios-voice-session-and-audio/lifecycle-and-actions.md) —
  foreground loss, exact recovery matrix, and named actions.
- [Provider handoff](ios-voice-session-and-audio/provider-handoff.md) — journal-
  before-provider, consent stages, usage, and frozen History transition.
- [Runtime state](ios-voice-session-and-audio/runtime-state.md) — phases/stages/progress/outcomes.
- [Safety and verification](ios-voice-session-and-audio/safety-and-verification.md)
  — invariants, edge cases, background gate, and evidence.
- [Quick Session history](ios-voice-session-and-audio/quick-session-history.md) —
  explicitly non-normative exploration.

## Dependency

- [V1.1 release](ios-v1-release.md) — current scope and keyboard precedence.
