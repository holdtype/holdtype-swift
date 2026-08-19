# Settings Defaults, Storage, And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.DEFAULTS`, `SETTINGS.STORAGE`, `SETTINGS.VERIFY`
- Read when: canonical defaults, persistence inventory, invariants, failures, or acceptance is in scope.
- Do not read when: only Settings navigation is in scope.
- Maximum size: 100 physical lines.

## Defaults

`gpt-transcribe`; Auto language; empty custom code/prompt/dictionary; emoji on
with English; Nearby Text off; correction off using `gpt-5.5` and standard
minimal prompt; typography on; no replacements; translation shortcut on,
Same as Transcription, source/target unconfigured, `gpt-5.4-mini`, standard
prompt; default Fixes catalog; insertion/Last Result/sounds/indicator on; tail
off; max 5 minutes; System Default mic; login/Dock off; History on; completed
recording retention off (enabled count 10); update checks on/downloads off.
API key has no default/UserDefaults value.

## Storage boundary

- UserDefaults may store every non-secret listed behavior/transcription/
  dictionary/correction/translation/cache/history/Dock setting, mic ID/name,
  and JSON local usage records. Login Item state comes from macOS.
- Keychain stores only API key. Debug key file is explicit/non-production.
- Fixes catalog is versioned local non-secret action/prompt data with no source,
  result, credential, host, or history; corrupt bytes are preserved/reported.
- `gpt-transcribe` local price is `$0.0045`/audio minute as reviewed 2026-08-04;
  future prices affect new records unless a later migration says otherwise.

## Verification and failures

Verify settings/key lifecycle without secret logging, usage math/reset/unknown
pricing, mic persistence/disconnect, duration normalization 1–15, Dock immediate
behavior, cache list/retention/clear, local-only diagnostics/updates, and defaults.
Correction failure leaves successful transcript usable. Runtime credential loss
blocks unauthenticated request. Unknowns: import/export and whether Custom
language remains free text versus constrained code.
