# iOS Transcription Usage Estimate

- Node type: hybrid
- Contract ID: `holdtype.ios.transcription-usage-estimate`
- Domain ID: `holdtype.ios.usage-estimate`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.ios.transcription-usage-estimate@1`
- Read when: iOS local successful audio-transcription usage, Usage UI, storage, pricing, or Reset is in scope.
- Do not read when: macOS text-token usage or actual provider billing is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Show a device-local estimate for accepted OpenAI audio transcriptions: today,
elapsed-day average, 30 days, projection, cost/minutes chart, frozen local
pricing, bounded persistence, honest errors, and isolated Reset.

Correction/translation token costs, failures/rejections/empty transcripts,
content, credentials, provider payloads, telemetry, cloud/cross-device usage,
and live billing APIs are excluded.

## Children

- [Recording and idempotency](ios-usage-estimate/recording-and-idempotency.md) — accepted timing, retry, runtime handoff, UUID, measurement, and frozen event.
- [Usage UI and operations](ios-usage-estimate/ui-and-operations.md) — destination, summaries, chart, refresh, notices, accessibility, and Reset.
- [Repository and wire format](ios-usage-estimate/repository-and-wire-format.md) — one actor, file protection, strict JSON limits, and canonical v1 rows.
- [Retention and validation](ios-usage-estimate/retention-and-validation.md) — 365-day compaction, atomic writes, duplicate semantics, pricing validation, and reset fence.
- [Failures and verification](ios-usage-estimate/failures-and-verification.md) — typed errors, concurrency, privacy, release isolation, and evidence.

## Invariants and precedence

- One successful audio request creates at most one event despite replay; later
  cleanup/output/History never revokes it or creates another.
- Containing app alone owns usage; never App Group, keyboard, Keychain, logs,
  diagnostics, export, backup, or provider billing endpoint.
- Cost is never guessed. Runtime domain values are Equatable/Sendable/non-Codable;
  only private repository wire values are Codable.
- Current iOS release, Voice persistence, and keyboard handoff contracts retain precedence.
