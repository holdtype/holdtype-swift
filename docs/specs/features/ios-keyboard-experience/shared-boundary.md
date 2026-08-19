# Keyboard Shared Boundary And Failures

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-experience.shared@1`
- Read when: App Group state, recording privacy, or fallback behavior matters.
- Do not read when: only layout matters.
- Maximum size: 100 physical lines.

Dictation needs `RequestsOpenAccess=true`; extension never contacts OpenAI or
sends host keystrokes. Extension atomically replaces one bounded current command;
app one state/result; each has one writer/request/expiry/no log. Signaling may
wake an already-running session, never treats files as general background launch.
Claim/ack share projections and add no outbox/queue/lease/system.

Shared state may contain Translation-valid boolean, bounded Fix metadata, one
expiring Fix pair; never language/route/model/key/prompt/dictionary/canonical
History/audio/provider/durable host. Fix contains chosen source plus opaque
action/request/document identity only—not keystream/context/history/replay.
Separate app-written Latest projects first accepted History row.

App alone requests microphone and records/buffers/uploads after Start through
Finish/Cancel/timeout/interruption/failure. Idle session retains/uploads nothing;
system indicator/state match real ownership. Consent precedes each remote; key
stays Keychain. Fix sends only selected or qualified complete field under
disclosure; ordinary keys local. Accepted output follows existing stores/cache.

Expiry, termination, access removal, denial, interruption, timeout, offline, or
provider failure ends current request without fake progress. Never auto-retry or
insert old result; stale expires and cannot enter later field. Secure/phone/host
opt-out uses system behavior. Local editing/Globe remain whenever presented.
