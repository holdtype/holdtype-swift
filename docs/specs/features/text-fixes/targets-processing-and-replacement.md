# Text Fix Targets, Processing, And Replacement

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.text-fixes@3`
- Clauses: `TF.TARGET`, `TF.PROCESS`, `TF.REPLACE`
- Read when: source capture, provider transformation, stale validation, or replacement is in scope.
- Do not read when: only catalog editing or Voice Prompt recording is in scope.
- Maximum size: 100 physical lines.

## Target capture

- Capture precedes palette presentation or app transition. A non-empty
  selection is source and range. With none, macOS uses the complete compatible
  AX field, iOS Voice the confirmed Draft, and Keyboard requires a selection.
- Blank or over-32-KiB UTF-8 input starts no request. macOS supports only
  compatible non-secure public-AX controls; uncertain/partial keyboard context
  is never treated as a complete field.

## Processing

- One immediate Fix may be active per surface; further taps are ignored, not queued.
- Freeze action, exact source, target identity, and revision/fingerprint.
- Custom actions resolve their saved profile and do not inherit automatic
  correction length-ratio safety rules.
- Requests use the app-owned credential, applicable platform authorization,
  `store: false`, and explicit cancellation. Maximum wait is 20 seconds, or
  60 seconds for explicit Sol Best Quality.
- Custom output is used exactly as returned, without trimming, typography
  normalization, Markdown stripping, or whitespace rewriting. Empty/blank is
  invalid. Typed Translate/Correct Text keep their own normalization/failure rules.

## Replacement and outcome

- Immediately before replacement, revalidate target, document, source range,
  and source text. Missing, changed, unsupported, or stale targets reject the result.
- Success replaces only the captured range and creates one logical Undo where supported.
- Cancellation, timeout, provider/invalid-output/persistence failure, and stale
  result preserve current text.
- Successful immediate Fixes do not mutate Latest, Pending, History, Recording
  Cache, or transcription usage. macOS text provider usage may be recorded by
  `openai-usage-estimate.md` without content.
