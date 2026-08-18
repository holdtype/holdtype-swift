# Dev Vlogs Final Acceptance — 2026-08-18

Status: `BLOCKED`

Contract: `DV-ACTIVE-5`

## Runtime QA

- Runtime QA: required
- Tool: Computer Use
- Build: current `master` Debug product launched through
  `HOLDTYPE_DEV_VLOGS_FINAL_QA=camera-to-publish script/build_and_run.sh --verify`
- Environment: sanitized automation credential, transcription, correction,
  translation, and output adapters; live Keychain and provider access disabled
- Idle guard: scoped `caffeinate -dimsu` remained active for the bounded UI pass
- Scenario: open the real Dev Vlogs window and reach the camera-to-Publish
  acceptance entry gate
- Actions: inspected Overview, opened Camera setup, and independently queried
  the macOS camera inventory
- Expected: at least one selectable camera, followed by several eligible
  dictation clips and the Finder/Refresh/Create Video/Play/Reveal/Share flow
- Observed: the window opened correctly, Overview reported Setup required,
  Camera reported access allowed, and the product truthfully displayed
  `No cameras are currently available.` The system camera inventory was empty.
- Result: `BLOCKED`
- Blocker: no built-in, USB, or Continuity Camera was visible to macOS, so no
  real capture, clip, media, or Publish action was attempted

## Protected Behavior

- No live OpenAI request or Keychain credential was used.
- No camera or microphone capture started.
- No Dev Vlogs source, export, or archive fixture was created or deleted.
- The task-owned Debug HoldType process and idle guard were stopped after the
  observation.
- The pre-existing installed HoldType instance was relaunched after macOS
  terminated it while the duplicate bundle instance was closed.

## Release Disposition

Do not mark `DV-FINAL-QA` accepted and do not publish a release that claims the
camera-to-Publish workflow passed. Resume this exact gate after macOS exposes
one connected camera. The full developer test/build gate remains independent
and green.
