# iOS Settings Guided Recovery

Status: approved product contract; 2026-07-15.

## Goal

Replace silent disabled setup-dependent controls with one consistent path to
the exact setting that makes the requested action usable.

## Behavior

- A mode or action that is unavailable only because setup is incomplete remains
  tappable. The tap opens the owning Settings destination instead of doing
  nothing or starting partial work.
- Settings scrolls the exact owning input into view when necessary and presents
  one short inline explanation beside that input. A generic banner at the top of
  the screen does not replace this field-level guidance.
- Every editable Settings input has a stable field identity and supports this
  targeted presentation by default, even when no current recovery route uses it.
- Guidance persists until the user resolves the condition or leaves the editor.
  It disappears in place as soon as the owning screen observes the resolved
  state; resolving guidance never pops navigation, changes, or saves a value by
  itself.
- Privacy review is resolved only when the current OpenAI disclosure is accepted
  and authorized. Microphone recovery is resolved when microphone access is
  granted. A completed consent change is communicated by the updated durable
  status plus one accessibility announcement, not by a second persistent
  success row.
- Returning from Settings does not automatically enable a session mode, start
  recording, contact a provider, or replay the original action. The user repeats
  the intended action after setup is valid.
- VoiceOver announces the inline explanation after navigation without reading
  secret or user-entered values.

## Safety And Navigation

- Transient safety states such as Saving, Listening, Finalizing, or Processing
  may still prevent conflicting actions. They are not presented as missing
  setup and never route to Settings.
- Targeted navigation flushes a pending valid General Settings autosave and
  does not require confirmation for ordinary pending or in-flight saves. A
  validation-blocked or failed local value remains visibly unapplied and must
  not be presented as durable after the route changes. Explicit-save Library
  editors preserve their existing unsaved-editor confirmation.
- A route received while Settings is still loading remains pending and is
  applied once the owning editor is available.
- Keyboard recovery reuses the bounded keyboard-to-app launch route. The launch
  carries only a closed route identifier and no settings, prompts, credentials,
  transcript text, or host content.
- The keyboard itself contains no written navigation route. Its microphone
  opens the exact containing-app owner; full setup instructions remain on that
  destination.

## Translation

- iOS has no durable Translation enabled/disabled preference. Translation is
  available whenever its saved source and target route is valid.
- Immediate Translate remains the first item inside the Voice and keyboard
  Fixes surfaces. Auto Translate remains a separate Voice next-dictation mode.
- If the route is incomplete, tapping immediate Translate from Voice or Fixes,
  or selecting Auto Translate, opens Translation Settings and targets the
  invalid source control or missing target control.
- A keyboard Fix blocked by missing or outdated provider consent, API key, or
  Translation route uses the opaque containing-app recovery route for the exact
  owning Settings destination. No host text, prompt, credential, or provider
  payload enters that route.
- A legacy persisted iOS Translation action preference is accepted during
  migration but cannot disable Translation and is not written by new iOS saves.
