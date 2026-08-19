# Dev Vlogs Failure And Durability

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV.FAILURE`, `DV.DURABILITY`
- Read when: vlog capture/storage/finalization/build failure or recovery is in scope.
- Do not read when: only happy-path UI is in scope.
- Maximum size: 100 physical lines.

- Permission/camera/eligibility/destination/low-space problems skip only vlog
  with compact recovery; dictation continues. No silent camera/storage fallback.
- Drive loss stops vlog, preserves fragments, and classifies. Late video keeps
  truthful bounds without indefinitely delaying dictation.
- Mux failure preserves owned pieces and offers Retry Finalize while
  transcription/output continue. Quit/crash recovers only validated fragments,
  never publishes. Build failure/cancel preserves recipe/sources and does not
  affect dictation.
- Vlog finalizer receives a bounded lease on finalized dictation audio; it
  releases only after playable clip or truthful recoverable terminal state.
  Vlog media remains separate from History, Recording Cache, and retry audio.
- Default logs omit video/audio/transcript/path/app content/prompt/key/payload.
- Future uncertain remote publication must preserve export and require explicit
  confirmation before another attempt; no blind duplicate retry.
