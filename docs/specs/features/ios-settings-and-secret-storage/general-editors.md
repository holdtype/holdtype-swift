# iOS Settings Validation And General Editors

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.editors@1`
- Read when: editing/validating general Settings or autosave behavior matters.
- Do not read when: editing Library rows or credentials only.
- Maximum size: 100 physical lines.

Empty custom language means Auto; non-empty is supported 2/3 ASCII letters.
Empty models use defaults. Dictionary trims/ignores empty/dedupes case-insensitive
first spelling. Correction/Translation expert model/instructions live in
Advanced even off; Reset restores standard without exposing built-in prompt.
Translation has no durable toggle: valid route means available; incomplete
controls remain tappable and target exact missing source/target with guidance.
Only bounded route-valid boolean may reach keyboard. Usage is device-local
`Transcription Usage Estimate`, never invoice; usage contract governs.

Root pushes Transcription, Writing & Correction, Translation, Voice & Recording
Forms only—no typing/Quick Session/History/cache/auto-insertion/Nearby/macOS
except current Voice Recording Cache controls specified below. Each scene has
memory-only non-secret group draft; editing does no provider/mic/Keychain/
clipboard/bridge/filesystem. Every field stable-identifiable for guided route.

No normal Save/Cancel. Valid changes enter latest-wins group autosave; discrete
immediate, text may briefly coalesce, blur/leave flushes. Owner applies group to
latest durable, preventing stale cross-scene overwrite. One write active while
newer edits replace queued. Clean adopts durable; stale completion cannot overwrite.
Navigation never requires confirmation for pending save; consumer sees durable
after queued work. Failed local value stays `Not Saved`, persistent bottom warning,
shared truth remains durable; Try Again/Use Saved. Commit adopts canonical return.
Changed-elsewhere remains unapplied. Announce warnings content-free.

Language uses searchable list+Custom; invalid never autosaves. Advanced Reset
autosaves. Voice exposes cues, max 1–15 (default 5), outcome-tail, cache off/
newest20/unlimited explicit; changes apply next recording. Keep Latest is not
editable without its storage coordinator. Never echo model/prompt in state,
validation, notices, accessibility, diagnostics, reflection, logs.
