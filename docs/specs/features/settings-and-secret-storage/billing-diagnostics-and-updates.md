# Billing, Diagnostics, And Updates Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.BILLING`, `SETTINGS.DIAGNOSTICS`, `SETTINGS.UPDATES`
- Read when: local usage estimates, diagnostic actions, or update preferences is in scope.
- Do not read when: account billing, automatic upload, or provider mechanics is in scope.
- Maximum size: 100 physical lines.

## Billing

- Describe estimates from successful HoldType requests on this Mac, never
  invoice/balance/account usage. Show today, recent daily average, 30-day total,
  projected 30-day cost, daily Cost/Audio/Text chart, and category breakdown.
- Unknown pricing preserves minutes and marks cost unavailable/partial. Records
  retain creation pricing. Only exact `gpt-transcribe` records with wholly absent
  snapshot may receive idempotent rollout backfill; never alter other/existing snapshots.
- Reset removes only local estimates. Empty/unreadable storage shows honest
  empty/error without blocking dictation/key management. Failed/cancelled requests
  create no successful record. No live billing/usage/balance API calls.

## Diagnostics and Updates

- Diagnostics owns local crash discovery and explicit support-bundle export.
  Recent redacted bounded events may be copied/revealed/refreshed/exported; never
  raw transcript, prompts, keys, provider payloads, audio, or automatic transmission.
- Read failure is local and does not block other Settings.
- Updates shows current version and local preferences. Defaults: automatic checks
  on, automatic downloads off. No account, telemetry, or custom backend.
- Details remain in `openai-usage-estimate.md`,
  `diagnostics-and-crash-reports.md`, and `software-updates.md`.
