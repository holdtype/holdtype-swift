# HoldType iOS V1.1 Release Contract

- Node type: hybrid
- Status: Active
- Authority: canonical current iOS product contract
- Stability: Accepted
- Contract: `holdtype.ios.v1-release@1`
- Approved/revised: 2026-07-15 for keyboard-to-app handoff
- Read when: current iOS scope, precedence, release, or cross-feature behavior matters.
- Do not read when: only historical/deferred iOS evidence is requested.
- Maximum size: 100 physical lines.

`V1.1` is the first planned iOS release designation; it does not imply a
shipped V1.0. This contract supersedes conflicting P5H–P8 behavior for V1.1.
Legacy iOS specs are evidence and cannot expand this release unless explicitly
linked. `ios-keyboard-handoff-and-delivery.md` wins every conflict about
keyboard launch, capture, reconnection, or result delivery.

## Goal

Ship one coherent iPhone product: a useful containing app for voice input and
personal writing rules, plus a compact command keyboard whose primary action
controls an app-owned dictation session and inserts accepted text into the
active host field. The keyboard complements system keyboards; it is not QWERTY.

The bounded background session is scope because keyboard extensions cannot use
the microphone. The extension sends bounded Start, Finish, Cancel, claim, and
acknowledgement commands; the app owns capture, OpenAI, text rules, Latest, and
History. Cold microphone handoff opens HoldType and valid preflight starts
capture with the swipe-back sheet. Signed-device qualification is mandatory.

## Children

- [Scope and non-goals](ios-v1-release/scope-and-non-goals.md) — included product
  and excluded persistence/typing expansion.
- [Navigation and Settings](ios-v1-release/navigation-and-settings.md) — five
  destinations, launch routing, credentials, and saving.
- [Setup](ios-v1-release/setup.md) — keyboard, Full Access, practice, permissions.
- [Foreground Voice](ios-v1-release/foreground-voice.md) — recording, limits,
  Auto modes, Draft delivery, cancellation, and ordering.
- [Pending and Latest](ios-v1-release/pending-and-latest.md) — one recoverable
  attempt and one internal accepted-result record.
- [Compact History](ios-v1-release/compact-history.md) — 20 text entries,
  Saved Recording exception, policy, states, and failure isolation.
- [Recording Cache](ios-v1-release/recording-cache.md) — optional retained audio.
- [Keyboard surface](ios-v1-release/keyboard-surface.md) — Brand Stage command UI.
- [Keyboard session and delivery](ios-v1-release/keyboard-session-and-delivery.md)
  — app-owned capture, ownership, and at-most-once automatic insertion.
- [Keyboard Latest projection](ios-v1-release/keyboard-latest-projection.md) —
  replaceable History-derived cache and explicit insertion.
- [Privacy and failures](ios-v1-release/privacy-and-failures.md) — consent,
  access, protected data, timeouts, and degradation.
- [Release gates](ios-v1-release/release-gates.md) — automated/device proof.
- [Guardrails and decision](ios-v1-release/guardrails-and-decision.md) —
  complexity limits, verification mapping, and selected activation model.

## Direct dependencies

Current Voice, keyboard handoff/experience, Settings, audio, diagnostics, usage,
Text Fixes, and Voice Draft contracts refine their named responsibilities;
this release contract sets scope and precedence.
