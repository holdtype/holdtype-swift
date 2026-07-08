# Text Output Workflow

## Goal

Define how generated text becomes useful after a microphone transcription
session.

The MVP is optimized for fast dictation that inserts successful transcripts
into the active macOS app automatically. An app-owned Last Result slot keeps
the last accepted transcript recoverable on demand.

## Scope

This spec covers:

- last transcript visibility
- relationship to optional transcript history
- output handoff actions
- automatic active-app insertion
- automatic Last Result save behavior
- Paste Last Result shortcut and menu command
- optional text correction handoff before output delivery
- optional post-transcription actions such as translation before output
  delivery
- failure behavior around output delivery

## Non-goals

- final editor UI design
- rich formatting, templates, or command language
- review-first editing workflow
- integration with a specific host application beyond active-app paste
- custom keyboard extension behavior

## User-visible behavior

- A successful transcription may remain in current-session Last Transcript
  state, but the menu bar dropdown must not display dictated transcript text.
- Last Transcript state and Last Result saves must use text after
  trimming leading and trailing whitespace and newlines.
- When text correction is enabled, Last Transcript state, Last Result,
  recovery history, and automatic insertion use the final corrected text.
- When text correction is disabled or skipped, those surfaces use the accepted
  transcription text.
- When a post-transcription translation action succeeds, Last Transcript state,
  Last Result, recovery history, and automatic insertion use the
  translated text.
- The menu may show a compact output status after transcription, insertion, or
  recovery, but it must not show the transcript itself.
- The menu does not provide a manual Save Last Transcript action. Users recover
  accepted text through Transcript History or by using Paste Last Result when
  that setting is enabled.
- If automatic insertion is enabled, every accepted transcript should be
  inserted into the current active app at the cursor after transcription
  succeeds.
- Automatic insertion and Paste Last Result should deliver the accepted
  text as one bulk handoff. The user should not see characters typed one by
  one, and long transcripts should not be truncated by per-character delivery
  delays.
- Automatic insertion must use the same native, Accessibility-gated
  text-insertion boundary as the recovery paste path. It must not depend on
  Electron, Node.js, AppleScript paste helpers, or a macOS system clipboard
  fallback.
- If the Keep last result setting is enabled, every accepted transcript is
  saved as Last Result after transcription succeeds and before the
  automatic insertion attempt completes, so a failed insertion remains
  recoverable.
- Last Result is app-owned current-session state. It is not the macOS system
  clipboard and must not overwrite `NSPasteboard.general`.
- `Control+Command+V` and the menu's `Paste Last Result` command should insert
  the current Last Result text into the current active app at the cursor when
  the setting is enabled.
- Turning the Keep last result setting off disables new Last Result saves and
  disables Paste Last Result. It does not disable automatic insertion.
- Turning automatic insertion off must leave Last Result recovery available
  when Keep last result is enabled.
- If Accessibility permission is missing, automatic insertion and Paste Last
  Result must not simulate text insertion into the active app and must not fall
  back to the macOS system clipboard.
- If the automatic insertion or recovery paste event fails or times out, the
  transcript should remain available as Last Result when that setting is enabled
  and the app should show a recoverable output status when a visible surface is
  available.
- If output delivery fails, the last transcript should remain in
  current-session state and be recoverable through any enabled recovery
  surface.
- Last Transcript is current-session state and does not require persistent
  transcript history to be enabled.
- Optional transcript recovery history is governed by `transcript-history.md`.
  Enabling history must not change the Last Result save or paste
  behavior for the current transcript.

## Invariants

- Automatic insertion and Paste Last Result must target the current
  active app at the cursor, not an internal hidden destination.
- Failed handoff must not discard the transcript.
- Failed optional text correction must not discard the successful transcript.
- Failed post-transcription translation must not silently output the
  untranslated transcript for a translation-mode session.
- Copy and paste actions must not log transcript content by default.
- Clipboard, accessibility, or host-app automation must be treated as
  user-visible behavior, not hidden implementation detail.
- Automatic insertion and automatic Last Result save/paste must each have a
  settings-controlled off switch.
- The app must not use the macOS system clipboard as transcript storage,
  fallback storage, or restoreable state for this workflow.

## Edge cases and failure policy

- If transcription output is empty or whitespace-only after trimming, the app
  should show a clear error instead of saving or pasting empty text as a
  successful result.
- If optional text correction fails after a successful transcription, output
  delivery should continue with the successful transcription text.
- If a required translation action fails after a successful transcription,
  output delivery should not run for that session and the previous successful
  transcript should remain visible.
- If no Last Result is available, the paste shortcut and menu command should
  safely no-op and report that no last result is available when a visible
  surface is available.
- If the host app is unavailable or text insertion fails, the app should show a
  recoverable output error when a visible surface is available and preserve the
  Last Result recovery value when enabled.
- Paste delays and event posting must be bounded.
- If the active app changes between recording start and insertion time,
  automatic insertion and recovery paste should follow the product's
  current-active-app rule unless a future spec pins the target at recording
  start.

## Route / state / data implications

- The app stores the last transcript in current app state, but the menu must
  not expose the transcript text.
- The app stores only the final accepted output text as Last Transcript. It
  does not need to expose raw and corrected transcript variants in MVP UI.
- The final accepted output text may be either the accepted transcript, the
  corrected transcript, or the translated text depending on enabled
  post-transcription stages and the session output intent.
- The app may store one Last Result text value in memory for the current app
  session when the setting is enabled.
- Automatic insertion is a local UserDefaults-backed behavior setting and
  defaults on for the MVP.
- If transcript recovery history is enabled, accepted transcripts may also be
  kept in session-only recovery history under `transcript-history.md`.
- Output handoff may require platform permissions such as Accessibility control
  or keyboard event simulation.
- Persistent drafts outside transcript history require a separate storage spec.

## Verification mapping

- Add tests or manual QA for automatic insertion success, automatic Last Result
  save, disabled setting behavior, successful `Control+Command+V` and menu paste,
  missing Accessibility behavior, empty output, handoff failure, and absence of
  transcript text in the menu when implementation exists.

## Unknowns requiring confirmation

- Whether the app needs command phrases for punctuation, formatting, or editing.
- Whether target app should be captured at recording start or paste time.
