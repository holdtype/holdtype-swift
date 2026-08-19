# iOS Voice And Keyboard Fixes

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.text-fixes@3`
- Clauses: `TF.IOS.VOICE`, `TF.IOS.KEYBOARD`
- Read when: immediate Fixes in iOS Voice or HoldType Keyboard are in scope.
- Do not read when: only macOS or automatic post-transcription actions are in scope.
- Maximum size: 100 physical lines.

## iOS Voice

- Draft actions use one Fixes launcher: Translate, Correct Text, then enabled customs.
- Transform the selection or complete confirmed Draft. During editing, capture
  working text/range before ending focus, commit, validate against Draft, then
  reserve. Recording/start/finalize/process/another Fix makes it unavailable.
- Splice into the exact reserved range after revision/source validation.
  Success creates one app Undo and clears Redo. Auto Translate/Correction stay
  next-dictation modes. Library owns the native editor; prompts stay app-private.

## Keyboard presentation and handoff

- A 44-point top-rail control replaces Voice with a scrollable tile workspace;
  close restores live Voice state. Quick Insert and Fixes are mutually
  exclusive. Starting/Listening/Processing leaves Fixes visible but unavailable.
- Extension metadata contains only ID/kind/title/icon/order/enabled: at most
  100 actions and 64 KiB JSON; ID/kind/icon at most 128 UTF-8 bytes and title 80 characters.
- One expiring request carries opaque request/action IDs, chosen source/kind,
  non-empty document ID, and fingerprint—never surrounding text. Request JSON
  is at most 40 KiB; source 32 KiB; opaque IDs/fingerprint 128 UTF-8 bytes.
- App resolves prompt/action, authorization, and credential, then publishes one
  result: text at most 64 KiB, JSON 72 KiB, closed error 256 bytes. Overflow
  fails closed without truncation. Records atomically replace and expire at 60 seconds.
- Visible controller must still own exact request, document, selection, and
  fingerprint. Result invokes replacement at most once; uncertain replacement
  is never retried.
- Full Access is required for app mediation; without it, local editing/Quick
  Insert remain and UI explains the requirement. Secure fields, phone pads,
  opt-out, partial/oversized context, and unprovable complete fields fail closed.
- Extension writes requests; app writes results. The app-owned runtime processes
  them without sharing Keychain/provider client. This is transient coordination,
  not History/replay.

## Release gate

Keyboard Fixes may ship only for selected text after signed-device proof of
continuity and app mediation. Complete-field support requires a later contract
change backed by public-API proof; it does not block macOS or iOS Voice.

More-specific current iOS release and handoff contracts win any conflict.
