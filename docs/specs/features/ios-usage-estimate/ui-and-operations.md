# iOS Usage UI And Operations

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.ios.transcription-usage-estimate@1`
- Clauses: `IOS-USAGE.UI`, `IOS-USAGE.OPERATION`
- Read when: Usage destination, presentation state, refresh, notice, accessibility, or Reset is in scope.
- Do not read when: only event recording or wire validation is in scope.
- Maximum size: 100 physical lines.

- Independent `Usage` destination immediately before Settings is available
  without key, mic, Full Access, Voice session, or live request; not duplicated in Settings.
- Title `Transcription Usage Estimate` explains successful transcriptions on
  this iPhone. Show Today, elapsed-calendar-day Average/day (minimum one day),
  Last 30 days, and known-cost daily-average ×30 projection.
- Segmented daily chart switches Cost/Minutes over same window. Unknown-only
  cost is Unavailable; mixed cost is clearly partial without guessing unknown minutes.
- Empty and decode/storage errors differ. Unreadable state offers Retry and
  confirmed Reset; reset failure preserves unreadable state and remains retryable.
- Opening, pull-to-refresh, and Retry perform canonical local read; no polling,
  OpenAI, or Keychain. One shared process presentation owner rejects competing
  operations and ignores cancelled late completion.
- Write failure never affects accepted text; process-local content-free warning
  persists until dismiss or successful Reset and is not stored in diagnostics.
- Confirmed Reset affects only usage and immediately empties on success. During
  reset disable duplicate Reset/Refresh; failure preserves last confirmed UI,
  never optimistically clears.
- Chart/picker bars expose day/formatted value; four text summaries are the full
  nonvisual equivalent.
