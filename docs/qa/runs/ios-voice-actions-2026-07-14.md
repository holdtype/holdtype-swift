# iOS Voice One-Shot Actions QA — 2026-07-14

## Scope

Qualify the visible Translate and Correction actions added above the Voice
Draft. This is Simulator evidence for containing-app layout and deterministic
workflow routing only; it is not physical microphone or live-provider proof.

## Environment

- Commit under test: working tree after `77b8b7a`.
- Destination: iPhone 16 Simulator, iOS 18.6, 393 × 852 points at 3×.
- Launch: `HOLDTYPE_AUTOMATION=1`, non-interactive Keychain policy, deterministic
  Voice qualification routes, no live provider.

## Evidence

- Ready state: `assets/ios-voice-actions-2026-07-14/iphone-16-light.png`.
- OpenAI setup blocked:
  `assets/ios-voice-actions-2026-07-14/iphone-16-setup-blocked.png`.

## Results

- Translate and Correction are visible above Current text with equal geometry,
  native labels, and the same book and wand symbols used by the keyboard.
- Ready state keeps both actions, the complete Draft, status, large Start
  Dictation control, and all first-level tabs visible without clipping.
- Setup-blocked state keeps both one-shot actions visible but disabled, keeps
  the Draft copyable, exposes the owning OpenAI Settings recovery action, and
  greys the primary Start Dictation control.
- Controller and workflow tests prove that Correction starts standard output
  with forced correction for that request, while Translate retains its current
  valid-route gate.
- Full serialized iOS regression: 1,082 tests in 143 suites passed on the same
  Simulator with the sanitized Keychain boundary.

No actionable P0, P1, or P2 visual finding remains.
