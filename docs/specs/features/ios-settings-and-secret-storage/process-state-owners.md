# iOS Process Settings State Owners

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.owners@1`
- Read when: coordinating Settings, Library, credential UI, scenes, or Retry.
- Do not read when: only file schema matters.
- Maximum size: 100 physical lines.

After canonical root, create exactly one Settings and Library owner before scenes/
failed-History. Root failure leaves unavailable, never durable-looking defaults.
Construction is passive. Snapshot states: notLoaded, ready(value), loadFailed,
saveFailed(lastDurable); missing loads defaults without write; bad source has no
substitute. Descriptions/failures redact.

First load/mutation/Retry resolution is one FIFO transaction including I/O.
Mutation-before-load resolves durable then read-modify-save. Publish MainActor
snapshot before releasing lease. Ready only after atomic success using exact
canonical encoded value. Failure discards candidate and preserves durable;
next mutation starts durable, success clears. Expose typed semantic changes,
not stale full replacement. Retry receives exact owners, waits, uses resulting
durable values. Settings/Library are independently durable, not cross-file atomic.
Every scene shares identities.

One credential presentation owner per process wraps narrow closures capturing
the one coordinator. Secure construction failure yields unavailable, never not
configured; root failure prevents all owners. OpenAI detail asks marker/cache
status and first task subscribes to payload-free monotonic-revision events; no
Keychain polling/credential generation in SwiftUI. Explicit refresh resolves,
stores status only.

Owner stores availability/status/closed operation/closed notice only—never draft,
clipboard, key, request, arbitrary error. One operation prevents overlap across
scenes. Events/actions obey revision so stale result cannot overwrite; failures
remain until genuinely resolved, including locked access or replacement.
SwiftUI root holds only owner identities/provider availability, never composition/
coordinator/adapters/service. All wrappers/coordinator/composition redact debug/
reflection and captured secrets.
