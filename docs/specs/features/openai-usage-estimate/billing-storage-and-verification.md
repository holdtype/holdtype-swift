# macOS Billing, Storage, And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.openai-usage-estimate@2`
- Clauses: `USAGE.UI`, `USAGE.STORAGE`, `USAGE.FAILURE`, `USAGE.VERIFY`
- Read when: Billing summaries/charts, event persistence, Reset, errors, or acceptance is in scope.
- Do not read when: only event production or model pricing lookup is in scope.
- Maximum size: 100 physical lines.

## Billing UI

- Settings destination `Billing`, title `OpenAI Usage Estimate`, explains local
  successful HoldType requests. Show Today, Last 30 days, Average/day, projected
  30-day cost across priced categories.
- Daily chart switches Cost (stacked four categories), Audio (transcription
  minutes), and Text (stacked Fixes/Correction/Translation tokens). Category
  breakdown shows cost, primary measure, count; omit empty categories.
- Token detail is one collapsed disclosure. Unknown pricing marks known cost
  `partial`; empty/storage/incomplete states are honest and non-blocking.
- Confirmed Reset removes only local usage store. Accessible chart segments
  expose day/category/value; textual summaries are full nonvisual equivalent.

## Persistence and failures

- One process-wide owner stores versioned V2 bounded events. Migrate legacy
  transcription rows losslessly; never invent historical text tokens/events.
- Retain current local day plus prior 364; 30-day UI groups by current calendar.
- Reset atomically removes complete store. Corrupt/unsupported data is not
  silently replaced; local error keeps Reset available.
- Persistence never blocks/rewinds producer result. Write/missing-usage warning
  is process-local and content-free. Public errors/logs omit event values and content.

## Verification

Cover migration/V2/retention/duplicates/unknown/partial/reset isolation; exact
cached/reasoning math; every producer and failure; today/30-day/average/
projection/buckets/counts/minutes/tokens; empty/audio/mixed/error/incomplete UI,
accessibility, and fake-only automation with no live provider usage calls.
