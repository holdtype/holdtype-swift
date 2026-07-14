# iOS Voice Draft

Status: approved product contract; 2026-07-14.

## Goal

Make Voice the useful default iPhone screen for dictating inside HoldType,
reviewing one composed text, copying it, and continuing with another dictation
without opening the custom keyboard.

## Launch And Navigation

- Voice is the first tab and the destination for every cold launch or new
  scene.
- Returning from the background preserves the current tab while that scene is
  alive.
- History remains a separate containing-app tab. Voice contains no History
  list or preview and adds no duplicate History toolbar action.
- Translation, Keyboard Dictation Session, and the practice field remain
  reachable from the compact Voice More menu; the keyboard tools are
  presented as a sheet and none of them occupies the primary Voice canvas.

## Draft

- Voice presents one app-private composed Draft independently from Latest,
  History, Pending, Recording Cache, and the keyboard projection.
- The Draft is a vertically scrollable static text surface, not a text input.
  Tapping it never focuses a field, selects text, or opens the keyboard.
- Each accepted Voice or keyboard-controlled dictation appends exactly once by
  accepted `resultID`. Accepted chunks are separated by one blank line.
- The current Draft survives relaunch. It contains accepted text and result
  identifiers only; it contains no audio, provider payload, prompt, credential,
  host context, or creation-history log.
- Copy writes the entire current Draft to the clipboard.
- Clear atomically replaces the current Draft with empty. It never changes
  Latest, History, Pending, Recording Cache, usage, settings, or the keyboard
  projection.
- Undo and Redo cover successful append and Clear mutations in the current
  process only. They are bounded to twenty snapshots and are not persisted.
  A cold launch restores the current Draft but no hidden prior text.
- New mutation after Undo removes the forward Redo branch.
- The durable Draft is one bounded protected atomic record with at most one
  hundred accepted chunks and four MiB of encoded data. A full or unavailable
  Draft fails visibly without changing Latest or History.

## Primary Voice Control

- A large Start Dictation action stays below the Draft in the lower thumb
  region. Its decorative HoldType bubble is an image asset; its microphone,
  label, progress, and accessibility state remain native controls.
- Ready shows active `Start Dictation`.
- Listening uses the same primary location for Done and shows elapsed time plus
  a separate Cancel action.
- Arming and processing keep the primary control visible but unavailable and
  show their exact progress. Cancel appears only when the controller admits it.
- Setup, Pending recovery, blocked local recovery, and unavailable runtime
  keep a grey Start Dictation control plus the exact corrective actions.
- No unavailable state fabricates readiness or starts provider work.

## Recovery

- Safely loaded Draft text remains visible and copyable while new dictation is
  unavailable.
- OpenAI, transcription, translation, and microphone/privacy setup route to
  their existing owning Settings screens.
- Recoverable capture and Pending states expose only the exact Recover, Retry,
  and confirmed Discard commands admitted by the shared Voice controller.
- Draft load or mutation failure preserves the last confirmed presentation and
  offers Retry where a safe read is possible.
- History-save and local-cleanup warnings remain nonblocking after an accepted
  result.

## Accessibility And Appearance

- VoiceOver exposes Draft as static text and names every available action and
  disabled reason.
- Dynamic Type may move actions vertically without clipping the Draft or
  recovery explanation.
- Light and Dark use the same geometry. Increase Contrast strengthens native
  boundaries; Reduce Transparency removes nonessential glow.
- The image asset contains no label or microphone glyph. Native text and SF
  Symbols remain crisp, localizable, and state-aware at every scale.

## Verification

- Focused persistence tests prove strict bounded decoding, exact-once append,
  atomic Clear/restore, identifier collision handling, and no hidden durable
  undo record.
- State-owner tests prove load, append, Clear, Undo, Redo, forward-branch
  removal, and failure preservation.
- presentation tests cover empty, populated, loading, listening, processing,
  setup, Pending recovery, full Draft, and unavailable states.
- Simulator QA covers cold launch, tab preservation while alive, non-focusable
  Draft, Copy, Clear/Undo, keyboard-session sheet, both appearances, Dynamic
  Type, and Reduce Transparency.
