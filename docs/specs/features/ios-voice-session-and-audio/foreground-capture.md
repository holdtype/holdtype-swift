# iOS Foreground Capture

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-audio.capture@1`
- Read when: Start/Done/Cancel/limit or finalized-source validity matters.
- Do not read when: only provider stages or keyboard handoff matters.
- Maximum size: 100 physical lines.

Explicit app Voice preflights mic/consent/key/config/storage. Blocked starts no
audio/file/provider. Capture shows listening/time/Cancel/Done. Start cue ends
before retained audio; stop cue after finalization. Done applies frozen tail
Off/0.5/1/1.5/2 s (default Off); tail remains listening and duplicate Done is
ignored. Cancel capture/tail removes incomplete exact artifact, deactivates,
no provider. Frozen max 1–15 minutes/default five; boundary is normal Finish,
Pending, provider once.

Runtime artifact carries descriptor capability + duration/bytes; only adapter
sees transient URL. Persistence maps to stable attempt-relative Pending before
provider. Publish protected copy, commit single journal, then provider; source
stays until complete handoff.

Auto provider requires trusted 300 ms…frozen limit+2 s, absolute 902 s, positive
bytes below Pending limit. Invalid/short/overbound uses frozen monotonic fallback
clamped or unknown `0`, durably before provider. Exact empty Done removes.
Every bounded non-empty becomes durable completed/playable/discardable; unknown
never auto-dispatches but explicit Transcribe/Retry may admit once. Limit cause
and frozen elapsed outrank false delegate success and get protected retention.
Oversize/identity/protection uncertainty blocks, never deletes for duration.

Descriptor owner marks completed before Pending copy. Loss in gap offers Recover
Recording/confirmed Discard, no auto-upload. Same-process Done prepares
readyForTranscription with frozen settings; recovery prepares awaitingRecovery
with current compact settings. One explicit Saved Recording action may perform
promotion+retry; failure preserves source. Provider reads protected Pending only.
