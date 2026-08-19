# iOS Usage Retention And Validation

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.ios.transcription-usage-estimate@1`
- Clauses: `IOS-USAGE.RETENTION`, `IOS-USAGE.VALIDATE`, `IOS-USAGE.FENCE`
- Read when: compaction, duplicate IDs, pricing/event validation, or reset/write ordering is in scope.
- Do not read when: only UI rendering or provider acceptance is in scope.
- Maximum size: 100 physical lines.

- Retain current local calendar day plus prior 364 using injected Calendar start
  of day/calendar arithmetic; preserve valid finite future time across clock correction.
- `load` atomically rewrites expired rows or removes empty file. `record` compacts
  before duplicate decision and combines insertion with replacement. Compaction
  failure preserves source and returns error, never stale success.
- Missing file loads empty without creation and resets idempotently. Confirmed
  Reset may delete corrupt/unsupported source that ordinary load preserves.
- Canonical order: newest timestamp, then ascending UUID. Runtime duplicate
  preserves first frozen event and writes only required stale compaction.
  Idempotency ends with retention: expired prior UUID may be inserted again.
- New duration is finite >0. Pricing key is trimmed/lowercased; empty/colliding
  keys, negative/nonfinite rates, or empty source reject. Known snapshot requires
  finite nonnegative rate/cost and source; cost equals duration/60×rate, exact
  zero or tolerance `max(1e-12, abs(expected)*1e-9)`, no overflow.
- Persisted model/source must already be canonical. Duplicate UUID, bad order,
  invalid timestamp/number/duration/snapshot is corrupt—not normalized/deduped/clamped.
- Every write has monotonic opaque token. Successful Reset returns fence;
  callbacks ≤ fence cannot recreate warning. Counter exhaustion fails closed by
  showing every later failure rather than treating it as old.
