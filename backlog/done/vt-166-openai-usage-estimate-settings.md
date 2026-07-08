---
id: VT-166
title: OpenAI Usage Estimate Settings
status: done
priority: P1
lane: settings
dependencies:
allowed_paths:
  - backlog/vt-166-openai-usage-estimate-settings.md
  - docs/specs/features/settings-and-secret-storage.md
  - docs/specs/features/openai-transcription.md
  - VibeType/**
  - VibeTypeTests/**
verification:
  - git diff --check
---

# VT-166 - OpenAI Usage Estimate Settings

Status: done
Priority: P1
Lane: settings
Dependencies: none
Expected outputs: usage estimate spec, local usage model/store, Settings Billing UI, focused tests
Verification: git diff --check

## Scope

Add a local-only OpenAI usage estimate surface in Settings so users can see
recent transcription minutes, estimated OpenAI API cost, and a 30-day
projection.

## Requirements

- Keep the feature local-only; do not call live OpenAI billing or usage APIs.
- Store only timestamp, model, duration, and derived cost metadata.
- Do not store API keys, prompts, nearby context, transcript text, raw audio, or
  provider responses in usage records.
- Add a Settings sidebar entry for Billing or Usage.
- Show summary values for today, recent average, recent total, and projected
  30-day cost.
- Show a compact Swift Charts graph for daily usage.
- Make unknown model pricing explicit instead of showing a false cost.
- Add fake-backed tests; do not call live OpenAI, microphone, Keychain, or
  paste services.

## Completion Notes

- Added local-only OpenAI usage estimate specs, pricing and summary models,
  local persistence, controller success-flow recording, Billing Settings UI
  with Swift Charts, and fake-backed tests.
- Split the Billing Settings UI into small private subviews for storage errors,
  empty state, summary rows, chart, partial-cost warning, reset action, and
  formatting.
- `git diff --check` passed.
- Xcode build/test was intentionally skipped after repeated local Xcode stalls
  and the user's instruction to stop spending time on Xcode build verification.
