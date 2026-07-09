# iOS Containing App Experience

## Goal

Define the native iPhone and iPad app that owns HoldType setup, voice capture,
settings, recovery, and user-managed content around the keyboard extension.

The app must remain useful as a standalone one-shot dictation and recovery
surface. It must explain the limits of third-party keyboards instead of
promising an automatic return to another app or pretending that unverified
setup is complete.

## Scope

- top-level iPhone and iPad navigation;
- first-run setup and later setup recovery;
- the Voice destination, one-shot dictation, latest result, and practice field;
- the gated Quick Session entry and manual-return education;
- routes to Library, History, Settings, and system-managed setup;
- containing-app behavior during permission, provider, lifecycle, and bridge
  failures.

## Non-goals

- production keyboard layout, typing, autocorrection, or prediction behavior;
- the complete settings schema or editor details;
- audio-session implementation details;
- durable history and recording-retention policy;
- automatic insertion into an external app from the containing app;
- a private app-launch or automatic-return mechanism;
- making Full Access, background Quick Session, or iPad keyboard support
  available before their physical-device gates pass.

## Navigation

- iPhone uses four stable top-level destinations: Voice, Library, History, and
  Settings.
- Voice is the default destination and owns setup progress, current session
  state, Start and Stop, the latest result, and a practice field.
- Library owns custom dictionary entries, built-in and custom voice emoji
  commands, and ordered literal replacement rules.
- History owns accepted results and recoverable failed attempts only to the
  extent permitted by the approved iOS history contract.
- Settings owns keyboard, transcription, correction, translation, voice,
  provider, storage, usage, privacy, diagnostics, and About configuration.
- First-run setup may temporarily lead the experience, but completing or
  dismissing it returns the user to the normal destinations. Setup must not
  remain a separate permanent product mode.
- iPad presents the same destinations in a sidebar/detail experience and keeps
  the selected destination stable across ordinary size changes. This does not
  imply that the production iPad keyboard is ready.

## Setup Contract

The app guides setup in this order:

1. Explain that HoldType is a separate keyboard, cannot modify Apple's
   keyboard, and cannot automatically return to the previous field.
2. Help the user add and enable HoldType Keyboard, then verify it with the
   in-app practice field.
3. Explain what ordinary typing and manual result insertion can do without
   Full Access. Show Full Access setup only after the bidirectional Quick
   Session bridge has passed its product gate.
4. Configure the user's OpenAI key and request microphone permission only from
   an explicit voice action.
5. Choose the approved typing layout and dictation language. Explain the fixed
   five-minute Quick Session only when that feature is available.
6. Run a guided dictation, result recovery, and insertion example.
7. Teach Globe re-selection, system emoji, Space cursor movement, manual
   return, and Apple Dictation fallback.

- App launch may show incomplete setup, but it must not start recording, open a
  system permission prompt, read surrounding host text, or contact OpenAI.
- Microphone, keyboard, Full Access, and OpenAI readiness are separate states.
  Resolving one must not falsely mark the others complete.
- The app provides public system-settings actions and written fallback
  instructions. It must not claim that it can enable a keyboard or Full Access
  programmatically.
- Keyboard readiness is evidence-based. A successful practice-field check may
  show that HoldType was recently used; absence of fresh evidence is `Not
  currently verified`, not a definitive disabled state.
- A fresh extension report may show that Full Access was recently verified.
  Once that evidence becomes stale, the app must not claim that Full Access is
  still enabled or that it is definitely disabled.
- Denial or later revocation must leave a clear recovery path without requiring
  reinstalling the app.

## Voice Destination

- Before Quick Session is proven, foreground one-shot dictation is the default
  and complete voice path. It remains available as the safe fallback later.
- A start action must settle required microphone and OpenAI setup before actual
  capture begins. The UI must not show `Recording` or `Ready` when another
  setup step or unexplained app switch is still required.
- One-shot dictation records one bounded utterance, processes it, and presents
  the final accepted result in HoldType.
- The containing app may place accepted text in its own practice/editor field
  and offer explicit Copy and Share. It cannot insert into a previously active
  external app.
- When bridge publication is available, the accepted result may wait for an
  explicit or eligible keyboard insertion under `ios-output-actions.md`.
- The latest result shows only final accepted text: normal transcription,
  corrected text when correction succeeds, or translated text for a successful
  translation-mode session.
- Normal literal dictation with punctuation is the default output intent.
  Translation remains a visible but unavailable action with a setup route
  until its target configuration is valid.
- A completed recording becomes recoverable before provider work starts. The
  app must not discard it merely because the network, provider, app lifecycle,
  or output delivery fails.
- Cancel, Stop, processing, result, and recoverable failure must be visibly
  distinct. Repeated actions must not create parallel recordings or duplicate
  provider work.

## Quick Session Gate

- Quick Session is hidden or clearly unavailable until the M0B prerequisites
  and the minimal M0C physical-device gate pass.
- The first approved hypothesis is a fixed five-minute armed session started by
  an explicit foreground action. Its duration is separate from the five-minute
  maximum for one retained utterance.
- Before first use, the app explains that the microphone session remains
  active while armed, may continue in the background, consumes battery, shows
  the system microphone indicator, and ends through Stop or expiry.
- While armed but not listening, samples are discarded immediately and are not
  persisted or uploaded. Only an explicit microphone action begins retaining
  the current utterance.
- The Voice destination shows remaining time and an immediate Stop action.
  Expiry, interruption, app termination, or force quit must never leave the app
  presenting a stale active session.
- After activation, the user returns to the host app manually and may need to
  reselect HoldType with Globe. The app does not attempt a private automatic
  return.
- If M0C fails, HoldType retains one-shot dictation and read-only/manual result
  insertion and does not expose a production background Quick Session.

## Invariants

- The containing app is the only owner of microphone capture, OpenAI work,
  secrets, complete settings, recoverable audio, history, and diagnostics.
- The keyboard extension never receives the API key, raw audio, provider
  payloads, prompts, or complete app repositories.
- The app never records on launch or from a passive status refresh.
- Full Access is not microphone permission and is not required for the
  standalone one-shot path or ordinary keyboard typing.
- The app never promises a seamless round trip to the previous app or field.
- No inactive, gated, or unimplemented setting is shown as a working control.
- Multiple app scenes must not create parallel voice sessions. Every visible
  scene reflects the same canonical recording or processing state.
- Default logs and setup diagnostics must not contain transcript text, prompts,
  dictionary entries, API keys, raw audio, ordinary keystrokes, or provider
  payloads.

## Edge Cases And Failure Policy

- If the keyboard cannot be used in a secure field, selected phone field, or a
  host that rejects third-party keyboards, explain the platform limitation and
  preserve any accepted result in HoldType.
- If microphone permission is denied or revoked, remain out of recording and
  show the next available system recovery action.
- If the OpenAI key is missing or unavailable, remain out of recording and
  route to OpenAI setup without presenting the state as a microphone failure.
- If the app is offline or provider work fails, retain the completed artifact
  and offer only recovery actions supported by the approved history contract.
- If the app is evicted or relaunched, do not restore an active microphone or
  Quick Session state from stale UI state. Reconcile any completed pending
  attempt before offering retry or a new recording.
- If a keyboard or Full Access heartbeat is stale, show `Not currently
  verified` and allow a fresh practice/setup check.
- If an accepted result arrives while HoldType Keyboard is not active, keep it
  recoverable; do not switch apps or keyboards automatically.
- If the user closes setup, preserve honest incomplete statuses and re-present
  the relevant next action when they next request a dependent feature.

## Route, State, And Data Implications

- Setup recovery routes target the specific owning destination: keyboard setup,
  microphone/privacy, OpenAI, transcription, or translation.
- Voice presentation distinguishes idle, setup blocked, recording, processing,
  accepted result, recoverable failure, and gated or active Quick Session.
- The containing app owns one canonical voice-session identity across all of
  its scenes.
- The practice field is app-owned test content. Success there is not proof that
  every host app or field accepts third-party keyboards.
- Latest-result, history, pending-recording, and keyboard-bridge lifetimes are
  separate product states and must not be inferred from one another.

## Verification Mapping

- Navigation coverage should verify the four destinations on iPhone and the
  equivalent iPad sidebar/detail experience.
- Setup coverage should verify no permission prompt or recording on launch,
  honest stale verification, denial recovery, and practice-field guidance.
- Voice coverage should verify one-shot success, cancel, repeated-action
  suppression, pending-artifact recovery, and the absence of external-app
  insertion from the containing app.
- Multi-scene coverage should verify that two visible scenes cannot start
  parallel recordings.
- Physical-device QA is required for keyboard enablement, Full Access,
  background Quick Session, manual return, Globe re-selection, interruption,
  expiry, force quit, and host-app limitations.

## Gates And Open Decisions

- Production Quick Session and extension writes require M0C approval.
- Production QWERTY and iPad keyboard work remain under their existing gates.
- Durable accepted and failed history remains unavailable until
  `ios-history-and-storage.md` approves it.
- A configurable Quick Session duration, Live Activity, first production typing
  layouts, and the iPad hardware-keyboard trigger require later decisions.
