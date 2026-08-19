# Keyboard Handoff Start And Recovery

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-handoff.start@1`
- Read when: cold microphone handoff, sheet behavior, or retained audio matters.
- Do not read when: only warm-session delivery matters.
- Maximum size: 100 physical lines.

- Existing microphone is sole voice action; no black/Open/handoff button. Tap
  creates request, opens app, and starts real app capture after permission/setup.
  Denial is recoverable and never Listening.
- Preserve selected app destination/ordinary Voice. Large temporary sheet may
  say Starting, then Listening only after capture. Listening return track sits
  at physical bottom above home indicator with right chevrons and `Swipe right
  to return`; no copy below/second Start. App return is user gesture, not claimed automatic.
- Before capture, close cancels request/dismisses. After capture, close stops and
  preserves non-empty partial; only separately labeled confirmed Discard deletes.
  Disable interactive dismissal during capture. Every terminal handoff cleans
  keyboard-owned presentation without altering ordinary Voice recovery/Draft.
- Setup blocker stays in dismissible sheet without navigation/Voice mutation;
  repair never replays—return and tap again. Incomplete Translate uses same
  bounded launch to exact Translation input without dictation/provider.
- Pre-start/expired may dismiss. Once non-empty audio exists, show saved Play +
  Transcribe/Retry or Delete in sheet and History, even before Pending promotion.
  Unpromoted is `Ready to Transcribe`; Retry only after Pending/provider failure;
  unavailable metadata is blocked. Explicit action expectation-binds exact source,
  promotes when needed, and enters exactly-once retry. Failed promotion preserves it.
- Fresh tap may supersede only pre-start/cancelled/empty. Never replace Pending,
  Processing, failed, or actively Listening/retained-capture audio; reveal same
  recovery/session without rerunning preflight. Preserve accepted Latest/History.
- Transient state-publish failure never discards recorder. Durable ownership
  finalizes and surfaces recovery. Sheet/History share one process Saved Recording
  owner; uncertain read shows blocked + Retry Refresh on both and blocks admission.
  Keyboard cleanup keeps Starting visible and silently retries stale-session conflict.
- These ownership rules also apply across host apps/documents.
