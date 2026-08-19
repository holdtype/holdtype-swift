# iOS V1.1 Foreground Voice

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.foreground-voice@1`
- Read when: governing containing-app recording and accepted Draft delivery.
- Do not read when: only keyboard or relaunch recovery behavior matters.
- Maximum size: 100 physical lines.

- `Start Dictation` records in foreground. Done stops capture before processing;
  deliberate long press reveals compact Cancel without moving/reserving primary
  activity. Completed audio becomes recoverable before provider request.
- Frozen Settings limit is 1–15 minutes, default five. Boundary performs Finish,
  not failure: close capture, make Pending, process once. Count down final 15s;
  cues at 60, 30, 10, 8, 6, then 5…1, omitting Start cue at one minute; confirm saved.
- Only one recording/provider chain is active or pending. Provider stages have
  explicit timeouts and real cancellation.
- Standard dictation is primary. Session-only `Auto` menu below Draft has native
  `Clear Draft`, `Translate Result`, `Correct Result`; no badge. Auto Clear starts
  on; Translate/Correction off; process-local choices persist between app attempts
  but never rewrite Settings. Translate route stays tappable and opens its exact
  incomplete input; Correction forces saved configuration; both may coexist.
- Flexible space separates `Auto` from labeled `Copy`. Above are Fixes, Undo,
  Redo, with Clear trailing. Fixes offers Translate, Fix, and enabled custom
  actions. A Fix uses committed non-empty selection, else entire Draft; shows
  purple processing, atomically replaces only captured range, joins app Undo,
  and leaves Latest, History, Pending, and Usage unchanged.
- Apply Dictionary, Voice Emoji, Replacements, cleanup, correction, and
  translation in their documented order. Success becomes Latest even if History fails.
- On admitted Start, Auto Clear is the final local step before microphone. Empty
  is no-op; failure preserves Draft, blocks recording, and reports exact failure.
  Later failure does not restore cleared text automatically; Undo may. Retry never re-clears.
- Offer every accepted result exactly once to separate Draft. New attempts append
  after optional clear; with Auto Clear off join with one blank line. Draft
  failure never rolls back Latest/History/Pending cleanup. Legacy attempts retain
  recorded replace/append mode without destructive migration.
- Draft edits only while Voice inactive and starts unfocused. Tap enables normal
  selection/typing/paste/emoji. One completed meaningful edit is one app Undo;
  accepted-result deduplication is separate. Blank states are never Undo/Redo
  targets; Undo may restore Clear without making blank redoable.
- Phase motion communicates Listening but is not metering; collect, persist, or
  log no recorder meter values for presentation. Recovery never auto-repeats provider work.
