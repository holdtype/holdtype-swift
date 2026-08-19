# Correction Storage and Verification

- Node type: leaf
- Contract ID: `holdtype.shared.text-correction.storage`
- Domain ID: `holdtype.shared.text-correction`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.text-correction.storage@1`
- Read when: macOS/iOS persistence, concurrent rule operations, or acceptance verification is in scope.
- Do not read when: only provider response or local pipeline order is in scope.
- Maximum size: 100 physical lines.

## Storage

- macOS compatibility may retain existing UserDefaults keys for remote enable,
  model, prompt, typography toggle, and ordered literal rules.
- iOS correction enable/model/prompt/cleanup live in app-private general Settings;
  ordered `TextReplacementRule` values live in app-private Library v1. Neither
  uses UserDefaults or App Group.
- Replacements reads cleanup through process Settings owner and rules through
  Library owner. Failures are independent and never hide/rollback the other record.
- Library preserves ID, enabled, raw strings, duplicates, and order; it never
  trims/folds/deduplicates/reorders/removes empty Search at persistence.
- Edit/delete uses UUID plus expected full row; enable uses UUID plus expected
  prior Boolean; reorder uses expected/requested full UUID sequences. Stale or
  missing targets never recreate/mutate another row; concurrent sequence conflicts do not write.
- Keychain stores only OpenAI key; correction is separate from transcription request.

## Verification

- Settings: defaults, reset, persistence, empty Search ignore, model fallback.
- Local: dash/quote/ellipsis/special-space cleanup, ordered case-insensitive
  rules, duplicate rules, empty replacement, and empty-output fallback.
- Provider: request/parse, timeout+transport cancel, explicit cancel, bounded
  noncooperative loader, late rejection, independent next request, error mapping,
  and no live API.
- Runtime value: exact preservation, enabled/disabled paths, Sendable, no Codable.
- Controller: disabled, local-only, remote success, and remote failure preserving raw text.
- Presentation: Text Correction navigation and section.

## Dependencies

- [Text correction](../text-correction.md) — shared persistence invariants.
