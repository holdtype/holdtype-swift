# Privacy Disclosures And Retention

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.privacy-and-permissions@2`
- Clauses: `PRIVACY.DISCLOSE`, `PRIVACY.RETAIN`, `DV-PRIVACY-1..3`
- Read when: remote-processing copy, content retention, logs, diagnostics, or Dev Vlogs privacy is in scope.
- Do not read when: only system permission status or setup routing is in scope.
- Maximum size: 100 physical lines.

## Processing disclosure

- Near transcription controls—not Permissions—disclose OpenAI audio, optional
  nearby editable-text excerpt, second correction request, and separate
  post-correction translation request.
- Fixes disclosure says selected/compatible-field source plus instruction goes
  to OpenAI without a separate consent gate. Voice Prompt additionally sends
  explicit instruction audio, omits Nearby Text, then sends frozen source and
  instruction separately. Keyboard coordinates only invoked source through App Group.
- Typography and literal replacements run locally and make no remote request.
- MVP has no accounts, subscription, analytics, telemetry, server state, or cloud sync.

## Retention and sensitive data

- Default is no retained audio; completed attempt audio is deleted when cache
  retention is off. Failed retry audio is bounded/session-only and clears on
  success, deletion, History clear/disable, or quit.
- Explicit local recording cache supports Finder recovery/export and accepted
  History playback without upload/retranscription/path logging. Enabled default
  is last 10; unlimited is explicit and paired with size/clear controls.
- Accepted History is local, default-on, durable, and capped at 20.
- Nearby text, correction/translation inputs/outputs, and Fix source/result are
  request-only except final outputs stored by their owning contracts. Catalogs
  may store prompts, never source/result. Voice Prompt content is attempt-only
  except its bounded playable failed recording.
- API keys stay in Keychain; only explicit gitignored Debug live-key files are
  allowed, ignored by Release and automation.

## Dev Vlogs and diagnostics

- Camera is optional and never blocks core flow. Request only after an explicit
  Dev Vlogs camera action—not open/status/Off/Setup.
- Eligible enabled configuration may retain local camera plus same-dictation
  audio in the selected archive, separate from cache/History/recovery, never
  uploaded. Share consumes only a completed export.
- Default logs use compact closed lifecycle/outcome categories and omit content,
  prompts, context, keys, headers, audio, paths, payloads, and full responses.
- Crash reports/runtime logs are revealed/exported only by explicit user action,
  never automatically uploaded or broadened to system logs; exported app logs
  remain bounded, local, and redacted.
