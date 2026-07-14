# iOS Transcription Usage Estimate

## Goal

Show a transparent device-local estimate of successful OpenAI audio
transcription usage without presenting it as an invoice, account balance, or
complete provider-usage dashboard.

## Scope

- one local event for each successful audio transcription
- today, recent daily average, last-30-day total, and projected 30-day cost
- daily cost/minutes chart
- known, unknown, and mixed local pricing behavior
- bounded versioned persistence, empty/error states, and Reset

## Non-goals

- OpenAI billing, usage, balance, or account API calls
- correction or translation token/cost estimates
- failed, rejected, empty, locally invalid, or cancelled-before-acceptance
  transcription attempts
- raw audio, transcript text, prompts, dictionary content, credentials, or
  provider payloads in usage records
- analytics, telemetry, cloud sync, or cross-device aggregation

## Recording Contract

- A successful provider transcription records exactly one event after a
  non-empty transcript is accepted from the transcription stage. Later local
  cleanup, correction, translation, output delivery, or History failure does
  not create a second audio-usage event.
- The containing app creates the usage handoff immediately after accepting that
  non-empty provider transcript and before correction, translation, History,
  or output delivery. A later failure in any of those stages does not revoke
  the already successful audio transcription or create another handoff.
- A successful explicit retry with valid positive finite duration metadata
  records one event for that new provider transcription. A failed retry or one
  cancelled before acceptance records none. Cancellation after its
  transcription was already accepted does not revoke that event. A successful
  legacy retry with missing or invalid duration still returns its text but
  creates no invented usage event.
- Before each actual audio-transcription provider request, the containing app
  creates one local transcription UUID. Callback duplication or replay for
  that request reuses the UUID; every new provider request, including an
  explicit Retry, gets a new one. Correction, translation, History, and output
  retries never get audio-transcription IDs.
- The portable handoff contains only that local idempotency UUID, the
  lowercased surrounding-whitespace-trimmed model, and a finite audio duration
  greater than zero. Empty models, zero or negative durations, NaN, and
  infinite durations are invalid and produce no event; rejection is
  non-blocking for the accepted transcript.
- The handoff is an `Equatable`, `Sendable`, runtime-only non-Codable value. It
  has no timestamp, price, persistence, transcript, prompt, provider payload,
  credential, or keyboard/App Group meaning. The UUID is not a provider,
  analytics, session, document, or account identifier. The containing-app usage
  repository uses it as the event ID, adds time and the frozen local price
  snapshot, and treats a repeated UUID as an idempotent no-op.
- Each event contains only a local ID, timestamp, normalized transcription
  model, positive audio duration, optional known USD-per-minute price, optional
  calculated cost, and optional local pricing-source/version label.
- The event freezes the known rate used at recording time. Later price-table
  updates do not silently rewrite historical estimates.

## User-Visible Behavior

- Settings exposes one independent `Transcription Usage Estimate` route. It is
  available without a saved API key, microphone permission, Full Access, a
  running Voice session, or a live provider request.
- Settings labels the destination `Transcription Usage Estimate` and explains
  in plain language that values come from successful transcriptions on this
  iPhone. The screen does not expose repository or persistence terminology.
- The summary shows `Today`, `Average per day`, `Last 30 days`, and `Estimated
  30-day cost`. Duration is always available in minutes when valid events
  exist.
- The recent average uses the elapsed calendar days from the first event in the
  30-day window through today, with at least one day. Projection is that recent
  known-cost daily average multiplied by 30; it is not a promise about future
  use.
- A segmented daily chart switches between estimated cost and audio minutes
  over the same 30-day calendar window.
- If every event uses an unknown model price, cost is `Unavailable` while
  minutes remain visible. If known and unknown prices are mixed, known cost may
  be shown only with a clear `partial` warning; unknown minutes are never priced
  by guessing.
- With no events, the surface says that an estimate appears after successful
  transcriptions. A storage/decode failure shows a local error rather than an
  empty-success state. That unreadable state offers both local Retry and an
  explicitly confirmed Reset; if Reset fails, the unreadable state remains and
  Reset stays retryable.
- Opening the route refreshes from the canonical repository. Pull to refresh
  and a visible retry action perform the same local read. The screen does not
  poll, contact OpenAI, or read Keychain merely to look current.
- A usage-write failure never fails or rewinds an accepted transcription. One
  process-local, content-free notice says that some usage could not be saved
  and the estimate may be incomplete. A later successful load does not pretend
  that the missing event was recovered. The notice remains for the process
  lifetime unless the user explicitly dismisses it or successfully resets the
  estimate; it is not persisted as another usage or diagnostics record.
- The Cost/Minutes picker and every chart bar expose the day and formatted
  value to accessibility. The four textual summary values remain the complete
  nonvisual equivalent, so chart exploration is never the only way to learn
  the totals or pricing limitation.
- `Reset Usage Estimate` requires destructive confirmation, removes only local
  usage events, and immediately returns this surface to its empty state. It does
  not change the API key, settings, History, latest result, recordings, cache,
  consent, or any external OpenAI data.
- While Reset is in flight, duplicate Reset and Refresh actions are disabled.
  A reset failure preserves the last confirmed summary and presents a local,
  retryable error; without a prior confirmed summary, it preserves the
  unreadable presentation. It never optimistically clears the chart.

## Persistence And Privacy

- The containing app is the only reader and writer. Its composition root owns
  exactly one process-wide repository actor, which serializes read-modify-write
  operations. Concurrent repository instances for the same file are unsupported;
  the keyboard, App Group, and Keychain never receive usage state.
- Foreground Voice, failed-History Retry, and the Settings presentation owner
  receive that exact composition-owned repository instance. No convenience
  initializer may create a second production actor for the canonical file.
- One process-owned presentation owner is shared by all scenes. It holds only
  the current aggregate presentation, operation state, and content-free write
  failure notice. Each load/reset command has a private monotonic operation
  identity. Competing commands are rejected until the active command finishes,
  and a cancelled refresh cannot publish a late success or failure.
- Voice and Retry record through one mandatory composition-owned client. Every
  attempted usage write receives an opaque monotonic token; a successful Reset
  returns the repository's current token as a fence. Failure callbacks at or
  before that fence cannot recreate a dismissed warning, while a later failure
  remains visible. The token contains no usage content or persistent identity.
  If its process-local counter is exhausted, its terminal token fails closed:
  every later failure is shown again even after Dismiss or Reset rather than
  being mistaken for an older callback.
- The canonical file is app-private Application Support at
  `HoldType/ios-transcription-usage.json`. It uses Complete Data Protection, is
  excluded from backup, and is limited to 4 MiB.
- Before Foundation semantic decoding, the repository validates the complete
  source as strict UTF-8 JSON with no byte-order mark and rejects duplicate
  object members at every nesting level. Member identity matches Swift
  `String` equality over decoded UTF-8 scalars, so escaped/literal spellings and
  canonically equivalent Unicode names collide without case folding or
  compatibility normalization.
- Structural validation permits at most 64 nested containers, 1,024 members in
  one object, 262,144 members in the document, 65,536 elements in one array,
  524,288 total values, 4,096 decoded key bytes, and a 256-byte number token.
  Malformed JSON, a duplicate member, or a structural-limit failure is
  `malformedData`. A source beyond 4 MiB remains `sourceTooLarge` and wins
  before structural validation.
- The structural pass covers the entire document before schema and field
  checks. It therefore wins over an unsupported schema or another semantic
  failure and preserves the exact source without compaction, replacement, or
  removal. Both `load()` and `record()` use this same decode boundary.
- The private v1 wire root is exactly `schemaVersion` plus `events`. Every event
  row contains all seven fields: canonical uppercase hyphenated local UUID,
  canonical UTC ISO-8601 timestamp in
  `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` millisecond form,
  canonical model, duration seconds, price per minute, calculated cost, and
  pricing source. The three price fields are explicit JSON `null` together for
  an unknown price or are all present together for a known frozen price.
- Events retain the current local calendar day and the previous 364 calendar
  days. The inclusive cutoff is calculated from the injected current Calendar's
  start of day with calendar-day arithmetic, never elapsed-second arithmetic.
  A valid finite future timestamp is preserved so a device clock correction
  cannot destroy an otherwise valid event.
- `load()` physically removes expired rows with one protected atomic rewrite,
  or removes the file when no rows remain. `record()` evaluates retention before
  deciding whether an ID is a duplicate and combines compaction with insertion
  in one atomic replacement. A retained duplicate with other stale rows writes
  only the required compaction. A compaction failure is surfaced and preserves
  the previous source; it does not return a stale success.
- Missing storage loads as an empty list without creating a file. A missing
  file also makes Reset an idempotent success. Reset acts directly on the usage
  file, so an explicitly confirmed Reset may remove corrupt or unsupported
  source that ordinary load preserves.
- Before dispatching a replayable provider request, the pending-attempt journal
  durably stores its local transcription UUID. Replaying the same accepted
  handoff reuses that UUID; only a genuinely new provider request allocates a
  new one.
- Usage data is excluded from device backup and never enters App Group,
  Keychain, the keyboard extension, logs, diagnostics, or exports by default.
- Normal app use and automated tests never call a live provider billing or
  usage endpoint.

## Invariants

- Newly created handoffs and events require finite, strictly positive audio
  duration, and cost is never invented for an unknown model. Legacy decoded
  zero, negative, or non-finite events are quarantined or migrated by the
  versioned repository before they enter summaries; they are never silently
  clamped into new valid events.
- One successful audio request produces at most one event even after callback
  duplication, lifecycle replay, or output retry.
- Runtime event and pricing values are `Equatable`, `Sendable`, and non-Codable;
  only the repository's private wire values are Codable. Model keys are trimmed
  and lowercased before runtime lookup. Empty normalized keys, normalized-key
  collisions, non-finite or negative rates, and an empty pricing source are
  rejected.
- A known event price snapshot requires a finite nonnegative rate and cost plus
  a trimmed non-empty source. Cost must equal `duration / 60 * rate`; zero
  expected cost requires exact zero, and other values allow only
  `max(1e-12, abs(expected) * 1e-9)` absolute error. Overflow is invalid.
- Persisted model and pricing-source strings must already be canonical. A
  noncanonical row, inconsistent price snapshot, duplicate UUID, out-of-order
  event log, non-finite timestamp or numeric value, or invalid duration is
  corrupt v1 storage; it is never silently normalized, deduplicated, or
  clamped.
- Canonical order is newest timestamp first, then ascending UUID text for equal
  timestamps. A runtime duplicate preserves the first frozen event. It performs
  no write when no retention compaction is needed; if stale rows exist, only
  the required compaction is persisted before the duplicate result is returned.
  Idempotency is bounded by retention: when the only prior row for a UUID has
  expired, compaction removes it and a later handoff with that UUID is inserted
  as a new retained event.
- Correction and translation requests do not affect this estimate until a
  separate token-estimate contract is approved.
- Reset isolation is exact and a failed reset does not pretend the events were
  removed.

## Edge Cases And Failure Policy

- Unsupported schema or corrupt storage produces a recoverable local error and
  preserves the source for bounded recovery; it is not silently overwritten.
- A failed append leaves the successful dictation/output available and shows a
  non-blocking estimate-storage error.
- Cancellation of a view-driven refresh is not shown as a storage failure and
  its late completion is ignored. While one refresh or Reset is active, another
  scene cannot admit a competing command.
- A source larger than 4 MiB is rejected before decode. If adding a valid event
  would exceed 4 MiB, the append fails without modifying the old file; valid
  within-retention events are not evicted merely to make the new event fit.
- Reset and retention-compaction failures are typed local errors and preserve
  the existing source. Public errors contain no file path, stored field value,
  transcript, prompt, credential, audio, or provider payload.
- Calendar/time-zone changes regroup the 30-day presentation by the current
  local calendar without changing event timestamps or duplicating events.
- A future pricing-table update applies only to new events unless a separate
  migration contract explicitly says otherwise.

## Verification Mapping

- Test exactly-once success/retry recording and exclusion of every failed,
  cancelled, duplicate, correction, and translation path.
- Test today, elapsed-day average, 30-day window, projection, daily buckets,
  time zones, known/unknown/mixed pricing, and frozen historical rates.
- Test that foreground Voice, failed-History Retry, and presentation use the
  exact same repository actor and that concurrent records cannot lose an
  event through independent read-modify-write owners.
- Test 365-day pruning, migrations, corrupt storage, append/reset failures,
  confirmation, and reset isolation.
- Test initial refresh, explicit retry, cancelled late-completion rejection,
  competing-command suppression, reset-failure preservation, and process-local
  write-error notice dismissal.
- Render empty, known-price, mixed-price, unknown-price, load-failure,
  write-warning, and reset-failure states on compact iPhone and regular-width
  iPad at maximum Dynamic Type. Verify chart marks expose day/value labels and
  no total depends on chart color.
- Make the iOS Release verifier fail when the containing-app bundle contains
  the usage qualification fixture or the keyboard bundle contains usage
  repository, estimate, storage-filename, or qualification markers.
- Inspect fixtures and stores for all forbidden content and prove normal tests
  make no live billing/usage request.

## Unknowns Requiring Confirmation

- Correction and translation token estimates require a separate product and
  pricing contract.
