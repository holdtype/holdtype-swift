# Floating Indicator

- Node type: hybrid
- Contract ID: `holdtype.macos.floating-indicator`
- Domain ID: `holdtype.macos.floating-indicator`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.floating-indicator@1`
- Read when: optional floating recording/transcription feedback is in scope.
- Do not read when: only menu status, recording ownership, or transcript content is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

The optional floating surface gives immediate recording confidence while the
currently active app keeps focus. It covers visibility, recording and
transcribing visuals, countdown, placement, non-interference, disablement, and
fallback when it cannot be shown.

## Non-goals

- AppKit or SwiftUI implementation mechanics, transcript editing/history, and
  Notification Center behavior.

## Children

- [Presentation and countdown](floating-indicator/presentation-and-countdown.md) —
  visual states, final-15-second treatment, appearance, and placement.
- [Lifecycle and state](floating-indicator/lifecycle-and-state.md) — visibility,
  focus/input safety, failure ordering, ownership, and verification.

## Shared invariants

- The indicator never owns recording, transcription, output, clipboard,
  Settings, permissions, or transcript content.
- It never steals focus, activates HoldType during normal display, intercepts
  active-app keyboard input, or exposes secrets, paths, payloads, or debug detail.
- Hidden, disabled, or failed indicator presentation never disables core menu,
  capture, transcription, clipboard, or paste behavior.

## Dependencies

- [Microphone input](microphone-text-input.md) — recording and transcribing state.
- [Settings and secrets](settings-and-secret-storage.md) — local enablement.

Compact fallback status remains owned by `menu-bar-app-shell.md`; this
indicator contract does not create a reverse dependency on that shell.

## Unknowns

- Whether the user may drag or reposition the indicator remains unresolved.
