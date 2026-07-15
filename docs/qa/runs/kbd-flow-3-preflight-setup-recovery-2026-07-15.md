# KBD-FLOW-3 Preflight And Setup Recovery QA

Date: 2026-07-15

Scope: the scene-bound keyboard-handoff preflight, shared Voice setup gates,
provider-consent and microphone-permission policy, and targeted Settings
recovery. This checkpoint intentionally stops before app-owned capture and
production handoff-sheet presentation.

## Result

- A fresh accepted handoff runs the existing Voice configuration, consent,
  credential, microphone, and final revalidation gates through one workflow.
- Preflight stops before History arbitration, draft mutation, audio-session
  activation, recorder creation, provider work, Listening publication, or
  handoff-sheet presentation.
- Provider disclosure that is not authorized routes to Privacy & Permissions
  without presenting the ordinary Voice consent sheet.
- An undetermined microphone permission is requested from the exact active
  initiating scene. Preflight continues only when the returned and re-read
  permission is granted.
- Missing credentials, invalid transcription, invalid translation, provider
  consent, denied microphone access, Full Access, and the remaining existing
  `RecoveryDestination` values map through one central recovery function.
- Transcription and Translation recovery resolve their exact invalid field
  from the current durable settings. Other recoveries use their exact owning
  field: OpenAI key, Keyboard practice or system settings, provider consent,
  or microphone guidance.
- The launch intent is consumed before preflight. Setup routing clears the
  accepted in-memory request, and a repeated launch URL is inert; repair can
  continue only after a fresh keyboard tap creates a new request.
- The current correction workflow reports no distinct invalid correction
  configuration, so this slice does not invent a Writing & Correction route.

## Automated Evidence

- `HoldType-iOS` Debug build on iPhone 16 Pro, iOS 18.6 Simulator: passed.
- Focused workflow, exact-scene owner, and Settings mapping matrix: 82 tests
  passed, 0 failed.
- Workflow tests prove the shared gates run while History, audio activation,
  recorder creation, and provider dispatch remain untouched.
- Setup fixtures cover invalid transcription, invalid translation, missing
  consent, missing credential, denied microphone permission, and granted
  first-use microphone permission.
- Settings tests cover all current `RecoveryDestination` values and exact
  custom transcription/source/target fields.
- Scene-host tests prove that a passive or background scene cannot prompt and
  that the exact active scene lease owns preflight.
- Existing launch-router tests prove repeated consumption is rejected.
- macOS `HoldType` baseline build and final `git diff --check` are required
  before the checkpoint commit.

## Device Boundary

Simulator and deterministic tests prove routing, exact-scene ownership, and
the absence of capture side effects in this slice. They do not prove physical
microphone permission UI, signed-device URL opening, real recording, the return
gesture, keyboard reconnection, or insertion. Those claims remain assigned to
KBD-FLOW-4 through KBD-FLOW-8.
