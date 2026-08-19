# iOS Keyboard Handoff And Delivery

- Node type: hybrid
- Status: Active
- Authority: canonical keyboard-originated dictation contract
- Contract: `holdtype.ios.keyboard-handoff@1`
- Read when: keyboard microphone launch, capture, reconnection, or delivery matters.
- Do not read when: only ordinary containing-app Voice behavior matters.
- Maximum size: 100 physical lines.

This contract supersedes older requirements for no app opening or a manually
prepared session. It also governs bounded coordination for immediate keyboard
Fixes, while the Fixes contract owns product/target rules and Fix never joins
the microphone request.

A handoff lands on the existing Voice screen with a temporary sheet—not a tab,
destination, or mutation of ordinary Voice/Draft/recovery. Status/recovery stays
inside that sheet and the keyboard voice/error area.

## Product decision

Microphone creates one request, opens HoldType, starts app capture, lets the
user return, reconnects after extension recreation, finishes/cancels from the
keyboard, and auto-inserts only when the active visible controller proves the
app-consumed request and exact immutable non-empty destination. Recreation may
recover request control, never destination proof. If reliable/compliant flow
cannot ship, release app-only—not a degraded manual-session keyboard.

## Children

- [Start and saved recovery](ios-keyboard-handoff-and-delivery/start-and-recovery.md)
  — temporary sheet, capture ownership, supersession, and completed audio.
- [Continue and warm session](ios-keyboard-handoff-and-delivery/warm-session.md)
  — reconnect, Finish, idle lifetime, pipeline ownership, and fallback Latest.
- [Immediate Fixes and states](ios-keyboard-handoff-and-delivery/fixes-and-states.md)
  — separate transient request and truthful keyboard vocabulary.
- [Identity and delivery](ios-keyboard-handoff-and-delivery/identity-and-delivery.md)
  — immutable destination, claim/ack, at-most-once insertion, expiry races.
- [Privacy and release](ios-keyboard-handoff-and-delivery/privacy-and-release.md)
  — bounded shared state, app-only fallback, and acceptance criteria.

## Dependencies

- [V1.1 release](ios-v1-release.md) — scope and app-owned product state.
- [Text Fixes](text-fixes.md) — action catalog and target qualification.
