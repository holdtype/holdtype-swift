# Settings And Secret Storage

- Node type: hybrid
- Contract ID: `holdtype.macos.settings-and-secret-storage`
- Domain ID: `holdtype.macos.settings`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released
- Contract revision: `holdtype.macos.settings-and-secret-storage@1`
- Read when: macOS Settings navigation, defaults, local persistence, or OpenAI credential storage is in scope.
- Do not read when: current iOS settings/persistence or a feature's detailed behavior alone is in scope.
- Maximum size: 100 physical lines.

## Platform boundary

This is the macOS contract for Settings, UserDefaults, Keychain, Finder, Login
Items, and Sparkle. iOS may reuse domain defaults but is governed by its own
settings/storage contracts and never inherits these macOS UserDefaults keys.

## Children

- [Window and navigation](settings-and-secret-storage/window-and-navigation.md) — sidebar, titles, technical fields, Permissions, and Dev Vlogs separation.
- [OpenAI credential](settings-and-secret-storage/openai-credential.md) — setup copy, stable Keychain item, runtime cache, automation, and errors.
- [Transcription and dictionary](settings-and-secret-storage/transcription-and-dictionary.md) — model/language/prompt, Nearby Text, Dictionary, emoji, and correction.
- [Behavior and audio](settings-and-secret-storage/behavior-and-audio.md) — insertion, Last Result, sounds, indicator, microphone, tail, duration, login, and Dock.
- [Cache and History](settings-and-secret-storage/cache-and-history.md) — recording retention/listing/clear and transcript recovery controls.
- [Shortcuts, translation, and Fixes](settings-and-secret-storage/shortcuts-translation-and-fixes.md) — shortcut capture, translation ownership, and separate Manage Fixes.
- [Billing, diagnostics, and updates](settings-and-secret-storage/billing-diagnostics-and-updates.md) — local usage estimates, redacted export, and update preferences.
- [Defaults, storage, and verification](settings-and-secret-storage/defaults-storage-and-verification.md) — canonical defaults, UserDefaults inventory, invariants, failures, and evidence.

## Core invariants

- API key is Keychain-only persistently, never logged, and provider services
  receive an already-resolved process credential rather than reading storage.
- Settings are local-only: no accounts, telemetry, cloud sync/billing/backup,
  provider marketplace, local-model download, or automatic diagnostics upload.
- Selecting a Settings section changes no dictation state.
- Dev Vlogs uses focused feature stores/windows and only reads shared microphone status.

## Dependencies and precedence

Detailed behavior remains with `privacy-and-permissions.md`, [usage](openai-usage-estimate.md),
`transcript-history.md`, [Text correction](text-correction.md), [Text Fixes](text-fixes.md),
`post-transcription-actions.md`, `diagnostics-and-crash-reports.md`, and `software-updates.md`.
Those narrower contracts win; specifically, Text Fixes has no Restore Defaults action.
