# Recording Durability and Interruption

- Node type: hybrid
- Contract ID: `holdtype.shared.recording-durability`
- Domain ID: `holdtype.shared.recording-durability`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; iOS scope remains governed by current iOS contracts
- Contract revision: `holdtype.shared.recording-durability@2`
- Read when: recording ownership, interruption, teardown, recovery audio, or destructive authority is in scope.
- Do not read when: only platform presentation or provider response parsing is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Every retained microphone attempt remains recoverable when recording, local
finalization, lifecycle, or provider work ends unexpectedly. Internal state
writes, cancellation, route change, process exit, and other non-user events do
not become Discard.

This cross-platform contract governs macOS capture and iOS Voice/keyboard
capture. Platform contracts may define presentation and mechanics only while
preserving these ownership rules.

## Children

- [Terminal causes and capture ownership](recording-durability-and-interruption/terminal-causes-and-capture.md) —
  cause classification, durable identity, exact-once terminal races, and relaunch repair.
- [iOS handoff and Dev Vlogs boundaries](recording-durability-and-interruption/ios-handoff-and-dev-vlogs.md) —
  cancellation, supersession, warm input, and separately owned vlog media.
- [Saved recordings, Voice Prompt, and feedback](recording-durability-and-interruption/saved-recordings-and-feedback.md) —
  playable validation, provider authority, recovery actions, user messaging, and verification.

## Shared invariants

- Only explicit user destruction may intentionally delete retained positive-byte audio.
- Every non-destructive terminal cause leaves exactly one durable owner.
- Provider dispatch occurs at most once and only after durable ownership.
- Late callbacks cannot accept text, delete audio, or create another owner.
- Recovery is bounded and never automatically uploads audio after relaunch.
- Default logs contain cause, attempt ID, durability result, and provider
  authorization only—never audio, text, secrets, or local paths.

## Consumers

The platform consumers remain `microphone-text-input.md`, current iOS Voice and
keyboard contracts, `transcript-history.md`, and the Voice Prompt portion of
`text-fixes.md`. These paths do not weaken this cross-platform contract.
