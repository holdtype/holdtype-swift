# OpenAI Credential Settings

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.settings-and-secret-storage@1`
- Clauses: `SETTINGS.KEYCHAIN`, `SETTINGS.CREDENTIAL-GATE`
- Read when: API-key UI, storage, runtime resolution, automation, or credential failure is in scope.
- Do not read when: only provider request/response mechanics is in scope.
- Maximum size: 100 physical lines.

## Settings and persistence

- Explain that the user's Platform API key enables OpenAI transcription, with
  links to keys, billing, and safety; billing is separate from ChatGPT and any
  prepaid minimum is current provider guidance, not HoldType pricing.
- Persist one stable macOS Keychain item; replace in place. Never warm cache at launch.
- Configured status is non-secret and does not unnecessarily read/reveal full key.
  Replacement field may show a masked saved state.
- Non-empty typed/pasted input auto-saves; adjacent icon-only paste reads
  non-empty plain clipboard text. No Save button. User may replace/remove.
- Save/replace/remove immediately updates process credential cache. Only direct
  save/replace may cause Keychain authentication UI.

## Runtime and failure

- Launch/passive Settings/permission refresh never reads Keychain. Explicit
  recording/provider action may perform one lazy non-interactive read when cache
  is empty; failure blocks before capture and opens OpenAI Settings.
- Recording/retry resolves once; transcription/correction/translation services
  receive that credential and never resolve credentials or developer files.
- Provider rejection of a resolved non-empty key is `Invalid API key`; missing,
  unreadable, locked, or unauthorized storage is missing/unavailable before upload.
- Post-recording rejection shows menu recovery with explicit Open Settings,
  not automatic Settings. Failure handling never mutates the key.
- Unreadable stale/per-save legacy items are not prompt-migrated; user re-saves.

## Automation and Debug

- XCTest/UI/repository QA never opens authentication UI. `HOLDTYPE_AUTOMATION=1`
  avoids live Keychain and Debug key files; `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip`
  is a narrower explicit policy, never automatic for normal runs.
- Debug live key file is explicit, lazy, gitignored, Release/automation-disabled,
  and read-only. Save failure is visible and never claims success.
