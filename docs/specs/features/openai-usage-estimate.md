# macOS OpenAI Usage Estimate

- Node type: hybrid
- Contract ID: `holdtype.macos.openai-usage-estimate`
- Domain ID: `holdtype.macos.usage-estimate`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released
- Contract revision: `holdtype.macos.openai-usage-estimate@2`
- Read when: macOS local OpenAI request measurement, pricing, Billing UI, persistence, or Reset is in scope.
- Do not read when: iOS Usage or actual provider billing/account usage is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Show a transparent device-local estimate from successful macOS Transcription,
Text Correction, Translation, and immediate Fix requests without presenting an
invoice, balance, or complete provider dashboard.

## Children

- [Events, categories, and pricing](openai-usage-estimate/events-categories-and-pricing.md) — producer timing, token/audio measurements, category routing, and frozen rates.
- [Billing, storage, and verification](openai-usage-estimate/billing-storage-and-verification.md) — summaries/charts, V2 persistence, Reset, failures, and evidence.

## Invariants

- Never call provider billing/usage/balance APIs or estimate tokens from text.
- Missing/invalid measurement never changes a successful product result and
  creates no invented event; failures without a successful response create none.
- Records exclude content, prompts, credentials, payloads, audio, host/document identity.
- Every known cost freezes its reviewed rate; unknown models remain measurable
  but unpriced. Historical records are not silently repriced.
- Usage remains local and separate from iOS, Keychain, logs, diagnostics,
  exports, keyboard, cloud sync, telemetry, and analytics.

## Consumer boundary

`settings-and-secret-storage.md` owns sidebar placement only. Future features
require an explicit category/producer and cannot be folded into an existing one.
