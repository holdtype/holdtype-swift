# macOS Usage Events, Categories, And Pricing

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.openai-usage-estimate@2`
- Clauses: `USAGE.EVENT`, `USAGE.CATEGORY`, `USAGE.PRICE`
- Read when: a successful provider response may create a macOS usage event.
- Do not read when: only Billing presentation or Reset is in scope.
- Maximum size: 100 physical lines.

- Record one local event per successful response with valid measurement metadata.
- Audio needs accepted non-empty transcript plus positive finite duration and
  retains transcription exactly-once behavior.
- Text uses provider-reported nonnegative input, cached-input, output, and
  reasoning tokens plus actual response model where supplied. Cached input is
  within input; reasoning within output. Cost = uncached input at input rate +
  cached input at cached rate + all output at output rate, with no double charge.
- Missing/invalid usage yields one process-local content-free incomplete notice.
  Record decoded billable text response before later local validation/stale rejection.
- Voice Prompt normally creates independent Transcription and Fixes events; a
  later-stage failure never removes a valid earlier event.

## Categories

- `Transcription`: audio recognition only.
- `Text Correction`: automatic correction and built-in Correct Text Fix.
- `Translation`: post-transcription and built-in Translate Fix.
- `Fixes`: custom-prompt immediate Fixes.

## Pricing

- Event freezes rate, calculated cost, and source/version. Unknown models keep
  measurement/count with unavailable/partial cost; never infer from prefixes.
- Valid pricing has canonical non-empty key, finite nonnegative input/cached/
  output rates per million tokens, and non-empty source/version.
- Aliases/dates are explicit keys; custom/unknown identifiers remain unpriced.
  Updates affect new events only unless a later narrow idempotent backfill exists.
