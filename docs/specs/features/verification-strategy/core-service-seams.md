# Core Verification Seams

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.verification-strategy@1`
- Clauses: `VERIFY.SESSION`, `VERIFY.RECORDER`, `VERIFY.PERMISSION`, `VERIFY.PROVIDER`, `VERIFY.OUTPUT`, `VERIFY.HOTKEY`
- Read when: adding or selecting deterministic seams for MVP behavior.
- Do not read when: only platform runtime presentation is in scope.
- Maximum size: 100 physical lines.

- Central session controller with fake recorder/transcription/settings/
  permissions/history/output covers start/stop/cancel/transcribe/accept/fail,
  repeats, stop-without-recording, output failure, and last-good preservation.
- Recorder logic uses fake callbacks and local temp files; AVFoundation gets
  build/focused seams and bounded runtime only when changed. No indefinite waits.
- Permission fakes cover mic allowed/denied/not-determined/unavailable and AX
  trusted/not-trusted; production AX status is non-prompting by default.
- Provider builder/parser covers multipart/model/language/prompt/formats/empty;
  URL/service fakes cover credentials/rate/server/network/cancel and injectable timeout.
- Settings use isolated UserDefaults/in-memory and fake Keychain. Automation
  disables live Keychain; a login-keychain dialog is regression/blocker. Debug
  key file is manual only. Prove no key in defaults/logs.
- Output fakes cover Last Result enabled/disabled, empty, AX absence,
  insertion failure/timeout. Hotkey fakes cover hold/toggle/repeat/unmatched-up/
  transcribing rejection/registration/fallback.
- View/model tests precede macOS build and bounded Computer Use for changed UI.
