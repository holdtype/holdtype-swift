# iOS Keyboard Experience

Status: active V1.1 MVP UX contract; revised 2026-07-14 for truthful recovery
states and keyboard-controlled dictation. `ios-v1-release.md` wins any conflict.

## Goal

Provide a compact HoldType command keyboard whose primary action is voice
dictation. After one-time setup and while an app-owned Keyboard Dictation
Session is available, the user taps the keyboard microphone, speaks, finishes,
and receives the accepted text in the active host field.

The extension itself never records audio. The containing app owns microphone
capture, OpenAI processing, text rules, Latest, and History. The keyboard owns
only the controls, one bounded command handoff, transient status, and insertion
through `UITextDocumentProxy`.

## Platform Boundary

- A custom keyboard extension has no microphone access. HoldType does not try
  to bypass that restriction.
- The containing app may run an explicit, user-started Keyboard Dictation
  Session and process keyboard commands while that session remains available.
- The keyboard never launches the containing app. If the session is absent or
  expired, it says `Session not running` and replaces the microphone with the
  exact containing-app recovery path.
- The keyboard requests no external launch. System setup and product settings
  remain in the containing app, while the keyboard always provides written
  fallback instructions that do not depend on a system callback.
- HoldType declares that it supplies dictation. iOS therefore disables or
  suppresses its own Dictation key; on systems that retain the disabled icon in
  the bottom strip, that icon remains Apple-owned and is not a HoldType action.
- Physical-device evidence must prove that the app-owned background session can
  receive commands reliably and with acceptable privacy, energy, and App Review
  behavior. Simulator success cannot settle this boundary.
- If the device spike requires private APIs, fabricated state, indefinite
  silent audio, or recording user audio outside an explicit listening action,
  keyboard-controlled dictation is a no-go and implementation stops.

## Product Role

- HoldType is selected with Globe when the user wants voice dictation, Latest
  insertion, or compact sentence-editing controls.
- The system keyboard remains the normal alphabetic, numeric, emoji, and
  language-layout keyboard.
- HoldType inserts accepted Unicode text in any transcription language
  supported by the containing app. It has no keyboard-locale promise.
- Canonical History and every History action remain in the containing app. The
  keyboard never renders History rows, transcript previews, or detail.
- The API key, provider client, prompts, Library, Pending audio, canonical
  Latest, and canonical History never enter the extension.

## Brand Stage Adaptive Composition

The keyboard keeps one stable composition in Light and Dark Mode:

1. Top rail: a compact three-button utility group on the left, the HoldType
   mark centered without any status text, and `Latest` on the right. The group
   contains Quick Insert, Translate, and Improve actions represented by the
   standard smile, translation, and magic-wand symbols.
2. Workspace: either the Voice stage or Quick Insert. One toggle tap replaces
   Voice directly with Quick Insert; there is no intermediate launcher, task
   picker, menu, or containing-app transition. The close icon restores the
   exact Voice, progress, or recovery presentation underneath.
3. Editing row: Globe, wide Space, Delete, and adaptive Return.

The HoldType mark is identity only. No state label appears under or beside it.
Ready, unavailable, listening, starting, processing, and failure information
belongs exclusively to the voice stage so the interface never repeats the same
state in two places.

The approved Brand Stage reference remains the geometry source of truth. On
iPhone the surface uses approximately 18-point side insets, 8-point editing-key
gaps, an approximately 80-point voice circle, and an editing-key relationship
close to `Globe : Space : Delete : Return` of `1 : 4.35 : 1.15 : 1.25`.
Every action is at least 44 by 44 points.

Compact-height landscape may use the existing two-column reflow. Wider iPad
layouts keep a centered maximum content width. V1.1 release qualification is
iPhone-first; iPad remains compatibility UI.

The surface has rounded top corners and stays visually distinct from the host
application. The HoldType mark uses a transparent background in both themes.
The interface contains no History button, transcript card, alphabet layout,
number deck, Shift, Caps Lock, `123`, prediction row, or manual Refresh.

## Setup And Recovery Actions

- The keyboard has no permanent Settings action.
- Full product settings and system-setup assistance remain available from the
  containing app.
- A recovery state names the missing prerequisite and includes the full path:
  - stopped or expired session: `Open HoldType → Voice → Keyboard Dictation
    Session → Start Keyboard Session. Then return here.`;
  - Full Access: `iPhone Settings → General → Keyboard → Keyboards →
    HoldType → Allow Full Access.` This full route is visually emphasized,
    followed by `Then open HoldType and start a session.` and the secondary
    shortcut `Shortcut: hold 🌐 → Keyboard Settings.`;
  - request failure: `Open HoldType → Voice to review the problem and start a
    new keyboard session.`
- Recovery instructions are visible text, not accessibility-only hints or
  transient status.
- A shortcut never replaces the complete route. It is a smaller secondary hint
  for users who already recognize the system Globe menu.

## Quick Insert And Editing Controls

- The left utility group remains one stable visual unit. Its first control
  shows a smile icon while Voice is visible and a close icon while Quick Insert
  is visible.
- Quick Insert opens and closes in one tap. It never shows a mode chooser or a
  second confirmation step.
- Quick Insert has no visible title or explanatory label; the available keys
  fill the workspace.
- The punctuation row contains `.`, `,`, `?`, `!`, `:`, `;`, `—`, and `…`.
- Two emoji rows contain the bundled set `🙂`, `😂`, `❤️`, `👍`, `🙏`, `🔥`,
  `✅`, `✨`, `😊`, `😍`, `🤔`, `👏`, `💯`, `🎉`, `🚀`, and `👀`. These are fixed
  keyboard-local Unicode values, not copied Apple artwork or user Library data.
- Each selection performs exactly one local `insertText` call and closes Quick
  Insert immediately, restoring the underlying Voice or recovery workspace.
- Rows may scroll horizontally on narrow layouts, but every item keeps at least
  a 44-by-44-point target.
- Compact-height landscape may combine both emoji sets into one horizontally
  scrolling row so punctuation and every emoji remain reachable without making
  the keyboard taller.
- Quick Insert remains available without provider setup, network, microphone
  permission, or Full Access. Opening it may temporarily cover recovery copy;
  closing it restores that copy unchanged.
- Starting, Listening, and Processing keep their active Voice controls visible.
  The Quick Insert toggle is unavailable during those states and an incoming
  active state closes Quick Insert.
- A short Space tap inserts one space.
- Long-press then horizontal drag on Space moves the cursor without inserting a
  space.
- Delete removes once on tap and repeats with bounded acceleration while held.
- Return follows the current text-input traits when public information is
  available.
- Globe uses the system input-mode API and remains reachable whenever iOS
  requires it.
- Quick Insert, Space, Delete, Return, Globe, and an already-available
  restricted-mode Latest remain useful without provider setup, network, or Full
  Access.

## One-Shot Voice Actions

- Translate and Improve are secondary one-tap starts beside Quick Insert. They
  do not open a menu, mode chooser, confirmation, settings sheet, or containing
  app transition.
- Translate starts the next keyboard dictation with the saved Translation
  route. It is enabled only while the keyboard session is Ready and the
  containing app reports that Translation is enabled with a valid target and
  source route. Otherwise it remains visible and disabled.
- Improve starts the next keyboard dictation in standard output mode and forces
  the saved Writing & Correction model and prompt for that request only. It
  does not change the durable correction preference. Correction retains its
  existing safe fallback to the accepted transcript when the correction stage
  cannot produce a safe result.
- A Translate or Improve tap closes Quick Insert if necessary, starts exactly
  one request, and then uses the existing microphone for Finish and the
  existing Cancel action. Starting, Listening, and Processing disable all
  three utility controls.
- The action chosen at Start is frozen for that request. Later taps or settings
  changes do not change an active request.

## Keyboard Dictation Session

### Setup

- The user opens HoldType once, configures the provider, accepts provider
  processing, grants microphone permission, enables HoldType Keyboard, and
  enables Allow Full Access for keyboard-controlled dictation.
- The containing app exposes one plain `Start Keyboard Session` action and a
  visible way to stop it.
- V1.1 may use one fixed bounded session lifetime. Configurable session lengths,
  permanent background mode, and Live Activity controls are deferred.
- Starting a session never starts a provider request and never adds a History
  row. It only makes the app-owned voice path available to keyboard commands.

### Interaction

- With a valid session, the first microphone tap requests Start for one new
  request identifier.
- The app acknowledges actual capture before the keyboard presents
  `Listening…`; an optimistic or fabricated listening state is forbidden.
- A second tap requests Finish. A visible Cancel action requests cancellation
  and never submits the cancelled audio.
- After actual capture stops, the keyboard presents `Processing…` while the
  existing app-owned OpenAI and text-rule pipeline runs.
- If the same live keyboard request still owns the active host context, one
  accepted result performs exactly one `insertText` call.
- If the extension is dismissed, restarted, changes host context, loses the
  request, or cannot prove current ownership, it does not auto-insert. The app
  still commits the accepted result to Latest and optional History, and the user
  may later select `Latest` explicitly.
- Only one keyboard or foreground Voice recording/provider chain may own the
  microphone at a time. A conflicting start is rejected with a compact state;
  it never creates a second recording.

### State Vocabulary

The centered status is short and contains no transcript text. The voice stage
provides the longer recovery instruction when needed:

- `Ready` — local controls work and a keyboard session is available;
- `Session not running` — the app-owned session is unavailable or expired;
- `Full Access required` — voice commands cannot use the shared command boundary;
- `Allow Microphone` — the app lacks microphone authorization;
- `Starting…` — Start was written and is awaiting real app acknowledgement;
- `Listening…` — the app acknowledged real capture for this request;
- `Processing…` — capture stopped and app-owned processing is active;
- `No Network` — the current request cannot reach the provider;
- `Dictation failed` — a bounded failure ended the request.

Inserted text is its own success confirmation. The keyboard returns to `Ready`
without showing `Inserted` or rendering a result preview.

## Shared Boundary

- Keyboard-controlled dictation requires `RequestsOpenAccess = true`, but the
  extension itself does not contact OpenAI or transmit host keystrokes.
- The extension writes one bounded current command, including the selected
  one-shot voice action for Start; the app writes one bounded current
  state/result. Each record has exactly one writer, one current request
  identifier, an expiry, and no history or append-only log.
- Signalling may wake an already-running app-owned session, but App Group files
  are not treated as a general background-launch mechanism.
- Commands and state use atomic replacement. They add no outbox, receipt,
  acknowledgement family, tombstone, lease, policy generation, transaction
  coordinator, or replay queue.
- App Group state may include only a boolean Translation-available capability.
  It contains no language codes, translation route, model, API key, prompt,
  dictionary, canonical History, raw audio, provider body, or durable host
  context.
- Existing bounded Latest remains a separate app-written projection. It stays
  available for explicit insertion when automatic insertion is unsafe.

## Privacy And Recording

- Microphone permission is requested by the containing app only.
- The app records, buffers, and uploads audio only after a user Start action and
  until Finish, Cancel, timeout, interruption, or failure.
- An idle Keyboard Dictation Session must not retain or upload spoken content.
- The system recording indicator and HoldType keyboard state must agree with
  actual microphone ownership. App Review notes explain that audio capture and
  provider processing are app-owned.
- Provider consent is checked before every remote request. API keys remain in
  app-owned Keychain storage.
- Accepted text follows existing Latest, History, and optional Recording Cache
  policy. The command boundary does not introduce another transcript history.

## Failure And Fallback

- Session expiry, app termination, Full Access removal, microphone denial,
  interruption, timeout, offline state, or provider failure ends the current
  keyboard request without fabricating progress.
- No failure automatically retries a provider call or inserts an older result.
- A stale request or result expires and cannot be replayed into a later field.
- Secure fields, phone pads, and hosts that reject custom keyboards fall back to
  system behavior.
- Local editing and Globe remain usable whenever iOS presents HoldType.

## Accessibility And Appearance

- VoiceOver names Quick Insert, Translate, Improve, the recovery instruction,
  microphone state/action, Latest, Globe, Space, Delete, and adaptive Return.
- Listening, processing, success, and failure never rely on color alone.
- Increase Contrast strengthens boundaries; Reduce Transparency replaces
  material effects with opaque system colors.
- Theme follows system appearance. Light and Dark use identical geometry.

## Release Acceptance

KBD-MVP-2 uses a deliberately split feasibility qualification: a signed
physical iPhone and DEBUG containing-app controls prove the real recorder,
Finish, Cancel, expiry, and idle-audio release without presenting the keyboard
through iPhone Mirroring. The microphone indicator is recorded when the chosen
wired capture surface exposes it and is otherwise reported as unavailable;
Simulator UI and focused tests prove the extension, bounded command/state
reduction, insertion, and restricted editing half. This spike split does not
replace the signed-device keyboard/host-app release matrix below.

Automated and Simulator coverage must prove composition, both appearances,
recovery instructions, local editing, state reduction, stale-request
rejection, bounded record decoding, one insertion per accepted live request,
and explicit Latest fallback.

Signed physical-iPhone evidence must additionally prove:

- real app/extension signing and App Group access with Full Access on and off;
- absence of an extension-owned Settings or containing-app launch;
- app-owned session start, expiry, and stop;
- keyboard Start, Finish, Cancel, listening acknowledgement, provider timeout,
  and accepted insertion in real host apps;
- foreground/background transitions, interruption, Low Power Mode, process
  eviction, and microphone privacy indication;
- no automatic insertion after host-context or extension ownership changes;
- one explicitly authorized live microphone-to-OpenAI-to-host-field smoke.

The first TestFlight candidate is not ready until that device evidence passes.
App Store approval is never inferred from Simulator behavior or competitor
behavior.
