# macOS OpenAI Usage Estimate

Status: active product contract.
Contract revision: 1.

## Goal

Show a transparent, device-local estimate of the OpenAI resources used by
successful HoldType requests without presenting the result as an invoice,
account balance, or complete provider-usage dashboard.

## Scope

- successful audio transcription, text correction, translation, and immediate
  Fix requests made by the macOS app
- provider-reported token usage for Responses API text requests
- audio duration for successful transcription requests
- frozen local pricing snapshots and estimated cost
- 30-day summaries, daily charts, category breakdown, versioned persistence,
  migration, empty/error states, and Reset

## Non-goals

- OpenAI billing, usage, balance, or account API calls
- telemetry, analytics, cloud sync, cross-device aggregation, or iOS Usage
- reconstructing text usage that occurred before this contract shipped
- estimating token counts from source or result text
- storing prompts, source text, results, transcripts, credentials, provider
  payloads, audio, host-app identity, or document identity in usage records

## Event Contract

- The macOS app records one local event for each successful provider response
  that has valid measurement metadata.
- Audio transcription events use accepted non-empty transcription plus a valid
  positive finite recording duration and retain their existing exactly-once
  request behavior.
- Text correction, translation, and immediate Fix events use the token usage
  reported by the successful Responses API response. HoldType must not estimate
  tokens from characters, words, source text, result text, or request limits.
- A text event contains the semantic feature, actual response model when the
  provider supplies one, nonnegative input, cached-input, output, and reasoning
  token counts, and a frozen local pricing snapshot when the model is known.
- Cached input is a subset of input. Reasoning tokens are a subset of output.
  Neither subset is charged twice. Estimated text cost is uncached input at the
  input rate, cached input at the cached-input rate, and all output at the
  output rate.
- A successful response with absent or invalid usage remains a successful
  product result but creates no invented event. Billing shows one process-local,
  content-free incomplete-estimate notice.
- Provider, network, timeout, cancellation, invalid-request, and other failures
  without a successful response create no usage event.
- A text response may be billable even when later local result validation or
  stale-target replacement rejects the result. The provider event is recorded
  after response decoding and before downstream product validation.
- Every event freezes the local rate and calculated cost used at recording
  time. Later pricing-table changes do not rewrite historical estimates.
- Unknown models retain measurements and request counts while cost remains
  unavailable or partial. HoldType never guesses a price.

## Categories

- `Transcription` means audio recognition only.
- `Text Correction` means the optional automatic post-transcription correction
  request and the built-in Correct Text immediate Fix.
- `Translation` means post-transcription translation and the built-in Translate
  immediate Fix.
- `Fixes` means custom-prompt immediate Fix requests.
- A future feature requires an explicit category and event producer; it must
  not be silently folded into an existing category.

## Billing UI

- The Settings sidebar keeps the `Billing` destination. Its content title is
  `OpenAI Usage Estimate` and explains that values come from successful OpenAI
  requests made by HoldType on this Mac.
- The summary shows `Today`, `Last 30 days`, `Average per day`, and `Estimated
  30-day cost`. Cost includes every locally priced category.
- One compact daily chart switches between:
  - `Cost`, using stacked daily values for Transcription, Fixes, Text Correction,
    and Translation;
  - `Audio`, showing transcription minutes;
  - `Text`, using stacked text-token totals for Fixes, Text Correction, and
    Translation.
- A compact category breakdown shows each category's estimated cost, primary
  measurement, and successful request count. Categories with no activity may
  be omitted.
- Input, cached-input, output, and reasoning-token details are available through
  one collapsed `Usage details` disclosure and are not the default scan path.
- If any retained event has unknown pricing, known cost is labelled `partial`.
  Measurements and request counts remain visible.
- With no events, Billing says the estimate appears after successful OpenAI
  requests. Storage failures remain local, visible, and non-blocking.
- `Reset Usage Estimate` requires destructive confirmation and removes only the
  local usage event store. It does not change API key, Settings, History, Last
  Result, recordings, Fixes, or external OpenAI data.
- Chart segments expose day, category, and formatted value to accessibility.
  Textual summary and breakdown remain the complete nonvisual equivalent.

## Persistence And Migration

- macOS keeps one versioned local event store with one process-wide owner.
- The V2 root records a schema version and bounded events. Existing legacy
  transcription-only rows migrate losslessly to V2 Transcription events.
- Migration cannot invent historical text events or token counts.
- Events retain the current local calendar day and previous 364 calendar days.
  The 30-day presentation groups by the current local calendar.
- Reset removes the complete versioned usage store, including migrated audio
  and later text events, as one isolated local action.
- Usage data remains local and does not enter Keychain, logs, diagnostics,
  exports, the keyboard, or a provider usage endpoint.

## Pricing

- New text events use the model's reviewed local input, cached-input, and output
  rates per one million tokens.
- A valid pricing entry has a canonical non-empty model key, finite nonnegative
  rates, and a non-empty source/version label.
- Reviewed aliases and dated snapshots are explicit pricing keys. HoldType does
  not infer pricing from an unreviewed model-name prefix.
- Custom and unknown model identifiers remain unpriced.
- Pricing updates apply only to new text events unless a later contract defines
  a narrow idempotent backfill.

## Failure Policy

- Usage persistence never fails, rewinds, or blocks the successful product
  request that produced it.
- A write failure or missing provider usage creates a process-local,
  content-free warning that the estimate may be incomplete.
- Corrupt or unsupported saved data is not silently replaced with an empty
  success. Billing presents a local error and keeps Reset available.
- Public errors and default logs contain no event contents, model usage values,
  source text, result text, prompt, credential, audio, or provider payload.

## Verification Mapping

- Test legacy transcription migration, V2 round trips, retention, duplicate
  event handling, unknown pricing, partial cost, and Reset isolation.
- Test exact text-cost math, including cached input and reasoning tokens without
  double charging.
- Test each successful Correction, Translation, built-in Fix, and custom Fix
  producer, plus missing/invalid usage and every failure path.
- Test Today, 30-day, elapsed-day average, projection, daily category buckets,
  request counts, audio minutes, and text-token totals.
- Render empty, audio-only, mixed-category, unknown-price, storage-error, and
  incomplete-estimate states. Verify Cost, Audio, Text, disclosure, Reset, and
  accessibility through macOS runtime QA.
- Normal tests and automation use provider fixtures and never call live OpenAI
  billing or usage endpoints.
