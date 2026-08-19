# Keyboard Handoff Warm Session

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-handoff.warm@1`
- Read when: reconnecting, finishing, expiring, or reusing a keyboard session.
- Do not read when: only cold sheet recovery matters.
- Maximum size: 100 physical lines.

- Reconnect by durable request, not extension process lifetime. After delivery,
  unexpired app session stays Ready; next tap starts without reopening app.
- Warm session keeps a live input pipeline between attempts. Stop/cancel/expiry/
  replacement releases it and system indicator. Auxiliary failure during active
  recorder disables reuse but does not stop recording.
- Idle `Ready` lifetime is 60 s. Listening cancels idle timer and uses frozen
  1–15 minute recording limit (default five). Processing closes input and uses
  provider timeout. Old idle timer never stops capture/provider.
- Voice/error area owns messages; identity/decorative areas do not duplicate.
  Quick Insert and next-request Auto remain enabled/open through all phases and
  never change active request. Freeze modes at Start; later changes affect next.
- During capture microphone finishes. No keyboard Cancel beside center; sheet
  close is pre-return cancellation and after retained bytes saves partial, not
  confirmed Discard. Finish runs app transcription and optional rules.
- Limit performs same Finish, saves Pending before provider, and shows
  `Processing — recording limit reached; audio saved` without live extension need.
- Auto-insert requires active/visible controller, exact app-consumed request,
  immutable/current equal non-empty document ID, never-invalidated eligibility,
  and exact granted claim.
- Unsafe delivery preserves canonical Latest. While same-request transient result
  lives, explicit `Latest` has priority and uses claim/ack into current input;
  acknowledgement retires attempt and returns healthy warm session Ready. It is
  silent exception recovery, not normal flow.
