# Deferred Accepted History Policy Cutover

- Node type: leaf
- Status: Historical; Deferred
- Read when: reviewing retired Clear/Disable/Enable generation semantics.
- Do not read when: exposing those controls in current V1.1.
- Maximum size: 100 physical lines.

Clear always durably advanced revision/generation and preserved enabled state.
Disable/Enable advanced only on change; re-enable never restored old rows. The
confirmed policy commit was the logical boundary: reads immediately filtered to
the current enabled generation or empty-disabled state. Pre-confirmation failure
could not clean up or optimistically update UI.

Commit uncertainty allowed only identical continuation of the same command.
CAS supersession required fresh policy without replay. After a confirmed
boundary, later repository conflict/cleanup failure was pendingLocalRecovery,
not command failure; retry used the same generation and never advanced again.

Cleanup reported payload-free complete or pendingLocalRecovery. One bounded
pass pruned only stale accepted rows, processed at most one canonical outbox
head, and cancelled only exact unresolved stale delivery markers. Terminal
markers remained terminal; corrupt/future/unavailable/newer state stayed
preserved. Sealed expiry handed off to ordinary delivery removal without time
resampling.

Cutover never removed/changed Latest, delivery/publication, bridge, provider
work, Pending recovery, Recording Cache, Usage, settings, or credentials. Failed
rows/retry audio had to join the same cutover before UI, toggle, Clear, or first-
use disclosure could ship. No automatic legacy/macOS/bridge/external import was
authorized.
