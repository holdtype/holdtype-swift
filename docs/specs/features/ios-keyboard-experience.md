# iOS Keyboard Experience

Status: detailed design appendix. For V1.1, `ios-v1-release.md` controls the
required first locale, prediction/autocorrection scope, voice handoff, explicit
insertion, and background-session exclusions. Do not resume the Quick Session
state train from this file without a new approved spec.

## Goal

Make HoldType feel like a dependable everyday iPhone keyboard with an added
voice-input action, while presenting iOS platform limits honestly.

## Experience Principles

- Keyboard first, voice second: voice features must not weaken ordinary typing.
- Familiar, not cloned: follow iOS conventions without copying Apple trade dress
  or embedding Apple emoji artwork.
- Preserve Space cursor movement; use a dedicated microphone control.
- Keep the total height close to a normal keyboard by placing voice controls in
  one compact prediction/action bar.
- Use literal transcription with punctuation by default. AI polishing requires
  an explicit user choice.
- Never discard a completed recording before provider success or an explicit
  attempt discard. Once final accepted text is durable, insertion failure must
  preserve that text; raw-audio retention then follows the independent cache
  setting.

## Required Keyboard Behavior

A production iPhone keyboard must provide:

- alphabetic, number, and symbol layouts;
- Shift, Caps Lock, Delete with repeat, Space, Return, `123`, and Globe;
- field-appropriate Return presentation and basic auto-capitalization;
- double-space period, key callouts, useful hit targets, and light/dark appearance;
- cursor movement from a long press on Space;
- local autocorrection, a prediction row while voice is idle, and a clear Undo
  path for an unwanted correction;
- VoiceOver labels and actions that describe purpose and current state;
- a typing fallback that works without Full Access and without network access.

System emoji remains available through keyboard switching in the first product
version. A custom emoji surface is not an initial requirement.

User-editable typing preferences reach the extension only through
`ios-keyboard-settings-snapshot.md`. Missing or invalid preferences fall back to
bundled ordinary typing and never block Globe or Unicode entry.

The Phase 0 extension declares `en-US` only as feasibility metadata. Before the
typing-engine milestone starts, the product must approve the first-release
typing layouts, their autocorrection dictionaries, supported dictation
languages, and whether automatic language detection is enabled. Dictation
language and typing layout are separate user choices; QWERTY alone is not a
language contract.

## Voice States

The compact action bar presents one of these product states:

- `needsSetup`: keyboard, privacy, API key, or microphone setup is incomplete;
- `needsActivation`: the containing-app voice session is not active;
- `arming`: HoldType is activating the explicit Quick Session; no utterance
  action is available yet;
- `ready`: an already-active bounded Quick Session is armed and an utterance
  can start;
- `listening`: waveform, elapsed time, Cancel, and Done are visible;
- `finalizing`: HoldType is validating and durably saving the completed
  recording; neither Cancel Utterance nor Cancel Processing is available;
- `processing`: recording is safe locally while transcription completes;
- `confirmedInserted`: the same document/context confirms the submitted suffix
  and a short safe Undo opportunity is available;
- `deliveryUnverified`: `insertText` was submitted or durably claimed but its
  void result cannot be confirmed; inspect the field or recover in HoldType,
  with no automatic replay;
- `recoverableFailure`: available recovery is explained, with Retry or Insert
  only where its gate has passed and instructions to open Latest Result or
  History in HoldType;
- `interrupted`: a call, Siri, route change, or lock stopped work;
- `expired`: the bounded Quick Session reached its independent deadline.

`interrupted` and `expired` may share a compact recovery layout, but remain
distinct reasons and must not be relabelled as each other.
Reaching the separate five-minute utterance maximum is a visible recording
failure, not Quick Session expiry, and its maximum-duration artifact is not
uploaded.

The UI must never label a state `ready` when tapping the microphone will first
require an unexplained app switch.

## Voice Activation Contract

The initial product hypothesis is a five-minute Quick Session that the user
explicitly starts in the containing app. It never starts automatically. The app
shows the active duration and provides an immediate Stop action; expiry, app
termination, interruption, and force quit stop the session.

During Quick Session, the microphone/audio engine remains visibly active and
the system microphone indicator remains present. In `ready`, samples are
discarded immediately in memory and are never persisted or uploaded. Tapping
the keyboard microphone changes the state to `listening` and only then starts
retaining the current utterance. The keyboard and onboarding must call this
armed state `Voice session on`, not imply that the microphone is inactive.

After activation, the user manually returns to the host app. iOS may leave
Apple's keyboard selected, so onboarding teaches Globe re-selection. HoldType
does not attempt a private automatic return.

With Full Access off, ordinary typing, read-only insertion of a transcript
published by the app, and conditional Apple Dictation fallback remain
available. The keyboard cannot send voice-action commands or insertion
acknowledgement to the containing app.

After an explicit Full Access disclosure, an active Quick Session may support
the phase-valid named voice actions and acknowledgement through the shared
bridge. When the session is inactive, the keyboard shows `needsActivation`; it
does not pretend the microphone is ready and does not launch the containing app.

The compact bar keeps Normal dictation as the primary voice action. Translate
remains visible but unavailable with instructions to configure Translation in
HoldType until its target is valid. The extension never claims it can launch or
deep-link into the containing app. Retry, explicit Insert, Copy, and History
recovery follow
`ios-output-actions.md`; they do not overload Space or another standard key.

The action bar uses the same distinct `Finish Utterance`, `Cancel Utterance`,
`Stop Voice Session`, and `Cancel Processing` semantics as
`ios-voice-session-and-audio.md`. It shows only actions valid for the published
phase and never makes session Stop look like utterance Done or provider Cancel.

While a visible voice attempt is listening or processing, the extension uses
the bounded observation cadence in `ios-output-actions.md`; App Group
publication does not wake an evicted keyboard.

## Insertion Safety

The extension inserts only a non-empty accepted transcript.

When a voice session is tied to a `documentIdentifier`, the extension compares
the current identifier before automatic insertion. If it changed or is absent,
HoldType keeps the transcript recoverable and asks for an explicit Insert or
Copy action instead of guessing.

Repeated refreshes or late provider results must not insert the same transcript
twice.

The first production accepted-result snapshot expires 10 minutes after it
becomes ready. Expiry removes keyboard delivery eligibility but does not delete
app-owned latest result or durable History. The app physically clears the
expired transient snapshot at the first bounded maintenance opportunity.

## Failure And Fallback

- Secure fields, selected phone pads, and host-app keyboard rejection fall back
  to the system keyboard.
- Offline or provider failure does not block ordinary typing.
- Expired or corrupt shared state shows a compact unavailable state and does not
  insert text.
- Revoked microphone permission routes setup to the containing app.
- The keyboard never asks for credentials, microphone permission, or lengthy
  onboarding inline.
- Apple Dictation may appear as a system-provided control in some configurations.
  Otherwise the fallback is Globe, Apple keyboard, then Dictation.

## Keyboard Education Contract

`ios-containing-app-experience.md` is the single source of truth for setup
order, microphone requests, provider setup, and Quick Session availability.
Keyboard-specific education must additionally demonstrate:

- Globe re-selection and the required next-keyboard control;
- system emoji through keyboard switching;
- long-press Space cursor movement;
- ordinary typing plus M0B-proven explicit Insert without Full Access;
- secure-field, selected phone-field, and host opt-out fallback to the system
  keyboard;
- conditional Apple Dictation fallback when HoldType voice is unavailable.

The keyboard never requests microphone permission, asks the user to choose an
unapproved Quick Session behavior, or promises Copy without its own gate.

## iPhone And iPad

The first production milestone is iPhone in portrait and landscape.

iPad begins only after the iPhone typing and voice gates pass. It requires
separate validation for docked and floating keyboards, Stage Manager, multiple
windows, and Magic Keyboard/Bluetooth-keyboard workflows. A stretched iPhone
layout is not considered iPad support.

## Non-Goals For The First Product Version

- pixel-identical reproduction of Apple's keyboard;
- GIFs, stickers, or custom Apple-style emoji artwork;
- dozens of typing layouts;
- always-on background microphone by default;
- hidden semantic rewriting;
- a promised seamless return to the previous app through private APIs.

## Acceptance Gate

Before positioning HoldType as a default keyboard, dogfood must show that a
user can type for a normal working day without repeated fallback caused by tap
accuracy, Space, Delete, Return, Globe, cursor movement, or basic field types.
Autocorrection and predictions must also be useful enough that users do not
disable HoldType to repair routine typing.

Voice QA must show that completed speech is recoverable, Stop always stops the
microphone, and no late result is silently inserted into the wrong field.

When the production keyboard ships its own dedicated voice key, its controller
sets `hasDictationKey = true` so iOS does not add a duplicate system Dictation
key. Phase 0 keeps the value false. The transition must be verified on physical
iPhone and iPad hardware with supported OS versions before release.
