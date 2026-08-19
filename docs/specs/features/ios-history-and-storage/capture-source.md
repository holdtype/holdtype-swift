# Historical P4D Capture Source

- Node type: leaf
- Status: Historical
- Read when: reviewing the retired protected capture-source protocol.
- Do not read when: choosing the current release recorder implementation.
- Maximum size: 100 physical lines.

Persistence alone owned an app-private Capture namespace and opaque recording
lease. Creation durably recorded an exact attempt/intent/format/time intent,
exclusively created a hidden file, verified protected descriptor identity,
wrote strict marker/identity/phase xattrs, no-overwrite published, synced, then
cleared intent before exposing a transient URL.

Phases were active, finalizing, completed, preparing-pending, transferred, and
discarding with exact binary identity/completion manifests. Missing/wrong/future
metadata, ownership/link/path replacement, overflow, or phase mismatch was
unknown state and preserved. No manifest contained product text, secrets,
provider data, consent, scene, or host context.

Done wrote finalizing before close, validated stable bounded media, then wrote
completion and completed. Recover explicitly finished a partial checkpoint;
bounded positive audio with uncertain duration stayed playable/transcribable/
discardable and never auto-dispatched. Positive-byte active/finalizing content
was never age-deleted; only exact unlocked zero-byte active data older by both
trusted timestamps could enter synchronized discard cleanup.

The AVAudioRecorder candidate required physical-device proof that initialize,
prepare, and real recording preserved pinned identity/protection/metadata. A
failure required a descriptor-backed writer; storage safety could not be
weakened for URL-only convenience. This gate was historical, not migration
acceptance.
