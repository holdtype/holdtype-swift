# iOS Output Actions

## Goal

Define how final accepted HoldType text becomes recoverable and reaches an iOS
destination without guessing the previous app or inserting a late result into
the wrong field.

Output delivery must prefer safety over seamlessness. Automatic insertion is
on by default as a preference, but it becomes eligible only after the
bidirectional acknowledgement gate passes and the current keyboard target can
be matched conservatively.

## Scope

- final accepted text and output intent;
- latest and pending result behavior;
- containing-app practice, Copy, and Share actions;
- keyboard automatic and explicit insertion;
- insertion identity, acknowledgement, duplicate prevention, and Undo;
- recovery when the keyboard, target, bridge, or app lifecycle changes.

## Non-goals

- transcription, correction, or translation request internals;
- durable transcript-history and recording-retention policy;
- rich text, templates, snippets, or an external-app editor;
- a general clipboard manager;
- automatic keyboard selection, app launch, host-app identification, or return
  to the previous field;
- writing text from the containing app into an unrelated external app.

## Accepted Output

- Only trimmed, non-empty final text is eligible for output.
- Normal sessions output the accepted transcription after configured local and
  optional correction stages.
- Translation-mode sessions output only successful final translated text. A
  failed translation must not silently insert, copy, share, or save the
  untranslated transcript as though translation succeeded.
- The output record carries one session identity and one transcript identity.
  Repeated provider responses or bridge refreshes for those identities must not
  create additional accepted outputs.
- Raw provider responses, pre-correction text, prompts, audio, API keys, and
  surrounding host text are not output records.

## Defaults

- `Insert automatically when the current target matches` is on by default.
  The preference does not bypass the eligibility and gate rules below.
- `Keep latest result` is on by default and does not write to the system
  clipboard automatically.
- Normal literal dictation with punctuation is the default output intent.
- The Translate action remains visible but unavailable with a route to
  Translation setup until its target configuration is valid.
- Copy and Share always require explicit user action.

## Containing-App Actions

- The Voice destination shows the final accepted result and may place it in
  HoldType's own practice/editor field.
- Copy writes only the selected accepted text to the system clipboard after an
  explicit tap. It does not count as insertion, alter insertion identity, or
  start provider work.
- Share exposes only the selected accepted text or an explicitly selected
  app-owned recording. Cancelling Share does not delete or consume the result.
- The containing app may publish an accepted result for keyboard delivery, but
  it cannot insert into the previously active external app or return the user
  there automatically.
- Turning Keep latest result off disables post-session latest-result retention;
  it does not allow HoldType to discard an in-flight accepted result before its
  current delivery or recovery decision finishes.
- Latest result is independent of History. Clearing or disabling History does
  not silently rewrite the current latest result, and Copy does not create a
  History entry by itself.

## Keyboard Insertion

- The keyboard inserts text only while HoldType is the active keyboard
  extension in an editable host field.
- Automatic insertion requires all of the following:
  - the production acknowledgement contract and its Full Access disclosure
    have passed M0C;
  - the shared record is supported, unexpired, and contains accepted text;
  - session and transcript identities match the active delivery;
  - a non-empty source document identifier was captured for the session;
  - the current non-empty document identifier still matches it;
  - the transcript has not already been acknowledged as inserted.
- A document identifier is only a conservative guard. It is not proof of the
  host app, field, cursor position, or user intent.
- If any automatic-insertion condition is missing, HoldType keeps the result
  recoverable and offers an explicit Insert or Copy action where the platform
  and approved bridge allow it.
- Explicit Insert is a user confirmation to place the displayed accepted text
  into the field that is active at tap time. It may proceed after a missing or
  changed document identifier, but only while HoldType is visibly active and
  the user can see which result is being inserted.
- One successful Insert consumes the primary Insert action for that transcript
  in that keyboard presentation. Refresh, reappearance, or a late result must
  not repeat it automatically.
- Without Full Access, the keyboard remains usable for ordinary typing and may
  explicitly insert a valid read-only result after the M0B read path is proven.
  It cannot send start, stop, or insertion acknowledgement commands to the app,
  so automatic insertion remains unavailable.
- After successful insertion, the keyboard presents a short Undo opportunity.
  Undo is available only while the same target still safely contains the just-
  inserted text; otherwise it disappears without editing another field.

## Acknowledgement And Recovery

- Automatic insertion must not ship until the shared-state contract includes
  idempotent insertion acknowledgement.
- An acknowledgement identifies the session, transcript, source document, and
  terminal insertion outcome without copying transcript text into logs.
- A missing or delayed acknowledgement must never trigger a second insertion.
  The keyboard suppresses duplicates locally while visible, and the app keeps
  the result recoverable until delivery is reconciled.
- If insertion fails or the host rejects text, show a compact recoverable
  failure and retain the result for explicit Insert, Copy, or app recovery.
- If the result arrives while HoldType Keyboard is not active, it remains
  pending. HoldType does not open another app, select a keyboard, or guess a
  target.
- If the shared result expires before insertion, the keyboard stops offering it
  from that snapshot. Any longer-lived latest result or history remains owned
  by the containing app under its own retention contract.
- Copy or Share does not acknowledge insertion or consume a pending insert.
- Dismissing a failure hides the message but must not delete recoverable text or
  audio as a side effect.

## Invariants

- No output path uses a private automatic-return API or claims to know the
  previous host app.
- No automatic insertion occurs with a missing or changed document identifier,
  an expired result, an inactive HoldType keyboard, or an already inserted
  transcript.
- No accepted result is inserted twice because of refresh, retry, process
  restart, or a late provider response.
- Automatic insertion, latest-result retention, History, Copy, and Share are
  separate behaviors and controls.
- The system clipboard is never used as bridge transport, fallback storage, or
  an automatic side effect.
- Output actions and acknowledgements never default-log transcript text, host
  context, ordinary keystrokes, API keys, prompts, audio, or provider payloads.
- Secure fields, selected phone fields, and hosts that reject third-party
  keyboards are platform limitations, not successful delivery.

## Edge Cases And Failure Policy

- Empty or whitespace-only text produces no output action and leaves the
  previous accepted result unchanged.
- If the field, app, cursor context, or keyboard changes while provider work is
  running, automatic insertion is disabled for that result.
- If the user explicitly inserts after a target change, the tap targets only
  the currently visible editable field; HoldType does not claim it is the
  original field.
- If the host field becomes unavailable during Insert, retain the result and
  show recovery instead of falling back to automatic clipboard writes.
- If Copy or Share fails or is cancelled, retain the result and leave insertion
  eligibility unchanged.
- If Full Access is revoked during a session, stop bidirectional commands,
  preserve ordinary typing, and fall back to read-only/manual delivery where
  proven.
- If the bridge record is missing, corrupt, incompatible, or expired, do not
  insert and do not expose raw decoding data in the error.
- If the containing app or extension is evicted, reconcile the latest session,
  transcript, and acknowledgement identities before offering another action.
- If Undo can no longer prove that it would remove only the last HoldType
  insertion, it safely becomes unavailable.

## Route, State, And Data Implications

- Output presentation distinguishes pending, automatically eligible, explicit
  action required, inserted, recoverable failure, and expired.
- Setup errors route to their owning section: OpenAI, Transcription,
  Translation, Keyboard, Full Access, or microphone/privacy.
- The containing app owns complete accepted text and longer-lived recovery. The
  keyboard sees only the bounded accepted-result snapshot required for current
  delivery.
- Pending result, latest result, History entry, and insertion acknowledgement
  have independent lifetimes.
- The production bridge must define bounded expiry before automatic insertion
  is enabled.

## Verification Mapping

- Pure coverage should verify normalization, default settings, eligibility,
  missing or changed identity, expiry, duplicate suppression, and terminal
  acknowledgement.
- Bridge coverage should verify late results, delayed or missing
  acknowledgements, corrupt records, process restart, and Full Access
  revocation without duplicate insertion.
- Containing-app coverage should verify practice-field output, explicit Copy
  and Share, latest-result independence from History, and absence of external-
  app insertion.
- Physical-device QA must cover representative hosts, secure and phone fields,
  host rejection, keyboard switching, process eviction, explicit Insert,
  automatic insertion, and Undo.

## Gates And Open Decisions

- M0B must prove the read-only accepted-result path before manual keyboard
  delivery is treated as supported.
- M0C and an updated `ios-keyboard-shared-state.md` must pass before extension
  writes, automatic insertion, or cross-process acknowledgement are enabled.
- Exact production expiry and Undo durations require approval with the bridge
  and keyboard interaction specs.
- Durable latest/history retention remains governed by the future iOS history
  and storage spec.
