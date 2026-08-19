# Voice Draft And Editing

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-draft.editing@1`
- Read when: Draft text, focus, scrolling, mutation, persistence, or conflicts matter.
- Do not read when: only primary activity presentation matters.
- Maximum size: 100 physical lines.

- Draft is app-private and independent of Latest/History/Pending/cache/projection.
  Scrollable editor starts unfocused; tap enables selection/typing/paste/emoji.
- At standard type, use ~20 pt then one ~18 pt compact step when text stops
  fitting, with 1–2 lines return headroom; never shrink again. Accessibility
  sizes never auto-shrink. Then scroll vertically; inner swipes are not stolen.
  Useful text remains selectable read-only/editable.
- Append follows tail only if user remains at end without manual scroll/selection.
  Otherwise preserve position and offer compact return-to-newest; reaching/using
  it resumes. Replacement/Clear start at beginning. Undo/Redo preserve position.
  While editing, system owns caret visibility—no competing scroll/type transition.
- Done/interactive dismissal commits one app Undo snapshot. System owns character
  Undo while focused; app Undo/Redo disabled. Copy uses working text. Clear first
  commits working text, then atomically empties exact Draft so Undo restores it.
  Dictation waits for safe commit. Fixes captures working text/selection, ends
  focus, commits, validates range, then reserves provider.
- Active Voice phases make editor read-only and disable mutations/keyboard.
  Replace is default: admitted attempt hides prior Draft with new-text promise
  but does not mutate confirmed state. Cancel/failure/Pending restores it with no
  Undo; success publishes one mutation. Explicit Append keeps text visible and
  appends once per `resultID` with one blank line. Promise/mode freezes at Start;
  VoiceOver matches. Keyboard dictation defaults Replace.
- Replace/Append are atomic/exact-once, create one process Undo when prior text
  meaningful, and never roll back Latest/History/Pending on Draft failure.
- Durable Draft stores canonical text separately from ≤100 accepted IDs, ≤4 MiB,
  no audio/provider/prompt/key/host/history log. Migrate segment records losslessly.
  Full/unavailable fails visibly without Latest/History change.
- Copy writes whole Draft, disabled for visually empty, target ≥44 pt, no visual
  notice/layout change; assistive confirmation is allowed. Whitespace-only
  commits canonical empty. Clear is neutral `xmark.circle`, visible only with
  working text, ≥44 pt, no confirmation, affects no other domain.
- App Undo/Redo covers successful replace/append/committed edit/Clear, process-
  local, ≤20 meaningful snapshots, no blank targets. First text has no empty
  Undo; Undo can restore Clear/delete-to-empty without blank Redo. New mutation
  drops Redo; changed confirmed refresh drops both; cold launch restores no history.
- Edit uses CAS from confirmed start. Concurrent append/scene cannot be
  overwritten; unsaved working text remains copyable while reload/retry occurs.
- Copy/Clear/Fixes/Undo/Redo add no visible banner/toast/footer/technical result
  or inline Undo; outcomes keep Draft/viewport/actions/Voice center geometry.
