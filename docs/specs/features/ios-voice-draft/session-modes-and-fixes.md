# Voice Draft Session Modes And Fixes

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-draft.modes@1`
- Read when: Auto Clear/Translate/Correction or immediate Draft Fixes matter.
- Do not read when: only manual editing or recovery routing matters.
- Maximum size: 100 physical lines.

- Compact labeled `Auto` popover above intrinsic leading button contains native
  switches `Clear Draft` (`When a new dictation starts`), `Translate Result`,
  `Correct Result`; ≥44 pt, no badge, stays open for multiple changes, accessibility
  names enabled modes. Flexible space separates intrinsic trailing Copy.
- Cold defaults: Clear on, Translate/Correction off. Choices persist only in
  process for later app Voice attempts and never rewrite Settings.
- Freeze Clear at admitted Start. After all preflight, atomically clear confirmed
  Draft before microphone; empty succeeds. Failure preserves Draft, blocks
  activation, uses fixed recovery. Later failure leaves it cleared with local
  Undo possible. Retry never clears twice.
- Top Fixes shows enabled catalog with Translate/Fix first, never records or
  changes Auto selection. Freeze confirmed Draft and non-empty selection or
  whole-Draft fallback, show purple processing, splice accepted output exactly.
  If editing, capture working text/selection, end focus, commit, then require
  exact text and UTF-16 range match before request.
- Translate uses saved route; Fix forces saved Writing & Correction model/prompt
  without changing durable preference; custom actions use app-private prompts.
  Incomplete Translation remains tappable and opens exact invalid/missing input
  with guidance. Provider/consent/timeout/validation/stale/save failure leaves
  Draft unchanged and adds no card copy.
- Success creates one app Undo and clears Redo. Repeat after completion uses new
  confirmed Draft. Ignore taps while active; never queue/concurrently run.
- Immediate Translate/Fix stay separate. New dictation selecting both preserves
  correction-before-translation. Freeze modes and accepted-result insertion at
  Start in Pending so Retry/relaunch cannot change meaning. Clear is one-time.
- Auto Translate/Correction never transform existing Draft. Only Clear mutates
  before acceptance. New app results append after optional clear; without it use
  one blank line. Active Voice/edit/nonwritable Draft may block changes; missing
  Translation setup never turns Translate into dead control.
