# iOS Voice Storage And Verification

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.voice-state.storage@1`
- Read when: storage/privacy/cutover or acceptance evidence matters.
- Do not read when: only presentation behavior matters.
- Maximum size: 100 physical lines.

One app-private atomic record, serialized by one actor, owns metadata. Pending
and successful limit-ended audio are protected/backup-excluded; latter is
independent and newest-five. Latest/Pending remain app-private. Only the single
release-authorized accepted-History projection enters App Group: first item,
no independent expiry, no additional text/Pending/canonical History. Logs redact
text, paths, IDs, prompts, provider payloads, credentials, and audio.

V1.1 uses a new namespace and neither migrates nor auto-deletes unshipped legacy
Pending/delivery/History/outbox/generation/receipt/tombstone/retry-audio files.
Runtime ignores them; Simulator/internal installs may be explicitly reset.

Focused tests prove capture→Pending→provider→Latest→History→cleanup order;
History on/off/failure; failure/Retry/Discard; checkpoint and unknown-outcome
replay blocks; stage-specific resume; output-ready without provider setup;
limit Finish/playback/tolerance and Done/watchdog race; protected retry success,
publish/prune/unlink/metadata failures and relaunch cleanup; extension mismatch
not proving publication; all relaunch boundaries with zero automatic provider;
idempotent History, Latest replacement/invalidation, one-Pending admission,
uncertain-state preservation, and atomic-write preservation.

Signed-device proof remains required for Data Protection/process eviction.
