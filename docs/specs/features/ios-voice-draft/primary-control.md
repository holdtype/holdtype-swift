# Voice Draft Primary Control

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-draft.primary-control@1`
- Read when: governing Voice activity phases, geometry, or recovery presentation.
- Do not read when: only Draft persistence or Fix action semantics matter.
- Maximum size: 100 physical lines.

- Large Start stays centered in flexible area below status/above tabs, never
  bottom-stuck. Use text-free macOS-indicator artwork/motion, not microphone,
  spinner, or label overlay; VoiceOver retains name/state.
- Ready is complete static cyan Start—no invented grey idle. Listening uses same
  location as Done with cyan orbits/point/pulse. No reserved Cancel; deliberate
  long press overlays compact Cancel without moving activity. Finalizing/
  Processing is unavailable purple particle ring/slower pulse; status text
  distinguishes finalization/transcription/refinement/saving. Arming uses native
  progress and same long-press cancellation.
- Every phase uses one stable envelope centered exactly in flexible Voice area.
  Status and cancel overlay do not affect layout.
- After audio-session activation, freeze/validate exact input before route
  observation/start cue. Output-only route during Arming revalidates and
  continues; changed/unavailable/muted input stops safely.
- After recorder publishes Pending, first transcription reads canonical protected
  record and must not call it stale due to normalized timestamps.
- Setup/Pending/blocked recovery/unavailable runtime/Draft replace artwork with
  explicit native problem, next action, and exact admitted commands—never disabled
  image or generic `Voice unavailable`.
- Transient Start failure preserves valid setup and restores Start immediately.
  Credential failure routes OpenAI Settings; microphone failure routes Privacy.
  Waiting protected recording shows blocking Settings alongside Retry/Discard.
- Unclassifiable readiness offers `Check Again`: bounded non-destructive local
  refresh, no provider, Draft deletion, or Discard. Setup problems link one exact
  owner; Draft capacity/storage stays Voice with Copy/Clear/Retry. Reconciliation
  shows checking progress, never false Ready. No unavailable state fabricates
  readiness/provider work.
- Reduce Motion uses complete static cyan/purple state art.
