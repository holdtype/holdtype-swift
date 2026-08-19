# iOS Settings Truth, Failures, And Verification

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.truth@1`
- Read when: readiness, migrations, failure policy, or acceptance evidence matters.
- Do not read when: only one editor's normal behavior matters.
- Maximum size: 100 physical lines.

Key readiness is separate from mic/keyboard. Never claim keyboard enabled/default;
use setup route/instructions/practice. Full Access is recently verified or not
currently verified, based only on short extension heartbeat—not preference or
past practice. Never call saved preference active before consumer.

Every persisted schema versions/migrates deterministically. Corrupt/unsupported
shows local error/no editable substitute; defaults become durable only for missing
file and load failure never overwrites. Shared type extraction preserves macOS
defaults/keys. iOS never imports macOS Keychain/absolute paths/platform settings.

Keys never enter non-Keychain stores/logs/source; settings changes never capture/
provider; no passive Keychain; no network without disclosure/consent; no cloud/
account/telemetry. Settings read failure leaves unrelated History/diagnostics.
Write failure restores durable truth with explicitly unsaved local draft.
Corrupt Library preserved/not projected. Credential loss after capture preserves
Pending/no unauthenticated request. Bridge publication failure preserves canonical
settings, keyboard last snapshot/fallback, marks stale, and cannot increase authorization.

Verify every default/validation/load-save/migration/corrupt/rollback; exact/+1
limits, nonregular, protection/ownership/backup, partial I/O, identity race,
cleanup/postcommit outcome; Keychain identity/attributes/lock/no-passive reads,
paste/commit/old-key preservation; marker crash/reconciliation; FIFO/cancellation/
stale rejection/cache/refresh/unreadable preservation; redaction; iPhone/iPad and
gated-control absence. Signed device proves effective protection.

K1 still confirms release values of `PrimaryLanguage`, `IsASCIICapable`,
`RequestsOpenAccess`, `hasDictationKey`; none defines transcription languages.
