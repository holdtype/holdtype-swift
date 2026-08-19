# iOS V1.1 Keyboard Session And Delivery

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.keyboard-delivery@1`
- Read when: app-owned keyboard capture, request state, or automatic insertion matters.
- Do not read when: only explicit History-derived Latest insertion matters.
- Maximum size: 100 physical lines.

- Extension never records, requests microphone, reads Keychain, or contacts
  OpenAI. App owns recorder/provider/text rules. Immediate Fixes are separately
  bounded/app-mediated: extension sends selected source and opaque action only;
  app resolves prompt/provider.
- Start joins the same process Voice workflow/arbitration as foreground Voice;
  no second recorder, provider, persistence, or recovery. Voice, Pending
  Retry/Discard, and keyboard request are mutually exclusive while owning work.
- Unavailable/expired session makes microphone write one bounded intent and open
  HoldType, showing `Opening HoldType…`, never manual-session instruction.
  Full Access is required for voice command exchange; editing, Globe, safe Latest
  fallback remain. HoldType declares dictation support; suppressed/disabled
  system-strip Dictation icon is Apple-owned.
- Microphone writes Start for one request ID and freezes Auto modes. Show
  `Listening…` only after real capture acknowledgement; second tap writes Finish;
  Cancel skips provider. Fix-workspace Translate/Fix never starts capture.
  `Processing…` means app provider chain with timeout/cancel and no relaunch auto-start.

## Automatic insertion

One accepted result invokes insertion at most once only when a live controller
is active/visible, owns the exact request through originating lifetime or exact
consumed handoff, and current non-empty document ID equals immutable non-empty
source ID. Inactive controllers may observe but cannot claim/consume; recheck on
visibility. Missing/changed identity, stale ownership, or prior disqualification
permanently disables auto insertion. Recreation alone cannot authorize a target.

Publish transient result only when accepted Latest came from that keyboard
capture. Failure, cancellation, duplicate command, or another request cannot
fabricate it. Unsafe insertion still commits canonical Latest and optional
History so the user may explicitly choose `Latest`.

Extension writes one replaceable command; app writes one replaceable state/result.
Command is bounded action enum; state may add only Translation-available boolean;
both expire. One opaque claim and claim-consumption acknowledgement provide
at-most-once invocation. This is no History, outbox, ledger, tombstone family,
lease, replay queue, or reopened persistence architecture.
