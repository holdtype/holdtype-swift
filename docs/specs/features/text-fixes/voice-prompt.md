# macOS Voice Prompt Fix

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.text-fixes@3`
- Clause: `TF.VOICE-PROMPT`
- Change: `TF-DELTA-R3-VOICE-PROMPT`
- Read when: macOS Voice Prompt capture, transformation, or recovery is in scope.
- Do not read when: a persisted catalog Fix or iOS Fix is in scope.
- Maximum size: 100 physical lines.

## Capture and instruction

- `Voice Prompt…` freezes an existing macOS Fix target and starts one explicit,
  mutually exclusive instruction recording; ordinary dictation/another Fix blocks it.
- The palette replaces search/rows with recording state. Return or Stop
  finishes; Escape or Cancel discards. Click-outside is disabled during capture.
- Capture lasts at most 60 seconds, ignores configurable recording tail, and
  retains visible cues, permissions, credentials, durability, exact-once,
  timeout, and cancellation boundaries.
- Audio transcription uses saved transcription model, language, prompt, emoji,
  and dictionary settings, but omits Nearby Text. Normal optional correction
  and local post-processing produce an instruction capped at 8 KiB UTF-8.
- The instruction is not accepted dictated output and never updates Last
  Transcript, Last Result, History, insertion, Pending, or Recording Cache.

## Transformation and recovery

- Revalidate the target before transformation and again before replacement.
  Use Writing & Correction with low reasoning, `store: false`, 20-second
  timeout, and exact custom-output semantics.
- Audio transcription and transformation record required content-free usage events.
- Failed/interrupted audio is a visible Voice Prompt Saved Recording with Play
  and Delete, never ordinary Retry, insertion, or delayed application. The
  active palette may retry a failed stage only while its in-memory target validates.
- Relaunch, History, or another Fix never reconstructs/reapplies the target.
  Successful completion removes recovery state in the accepted-provider cleanup transaction.

This additive revision leaves catalog schema, existing Fixes, ordinary
dictation, iOS Voice, and Keyboard behavior protected.
