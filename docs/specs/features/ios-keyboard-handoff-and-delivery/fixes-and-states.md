# Keyboard Immediate Fixes And States

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-handoff.fixes@1`
- Read when: immediate keyboard Fix coordination or status vocabulary matters.
- Do not read when: only microphone destination identity matters.
- Maximum size: 100 physical lines.

Fix is separate: it writes no voice command/mode and never claims Listening.
Active visible controller captures non-empty host selection; V1.1 does no
no-selection field traversal, and uncertain/partial is unavailable.

Atomically publish one 60-second request with opaque request/action/document
identity, exact source/kind/fingerprint/date—no prompt/model/route/key/surrounding
context/history. App resolves canonical private Fix, consent, credential, makes
at most one provider call, and publishes matching result/closed failure. Cold
Fix may publicly open app but never record/change Voice. Process loss/expiry/
replacement/cancel rejects late output.

Before replacement, same active visible controller revalidates ownership,
required non-empty document ID, exact selected source/fingerprint; fingerprint
never substitutes identity. One result invokes replacement at most once, then
acknowledges and retires; uncertainty never replays. Source/result are disclosed
transient App Group content, not Latest/History/queue/clipboard.

Keyboard states: `Ready`, `Opening HoldType`, `Couldn’t open HoldType`,
`Listening`, `Processing`, `Result ready`, `Saved recording`, and `Failed` or
`Expired`. Saved offers Play, Transcribe/Retry, Delete. Pre-start permission/setup
belongs to app sheet; post-return terminal runtime may use compact failed UI.
Never show Listening before acknowledged capture or let stale state activate mic.
