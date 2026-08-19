# Keyboard Request Identity And Delivery

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-handoff.delivery@1`
- Read when: request reconnection, destination proof, claim, or insertion matters.
- Do not read when: only sheet layout or setup copy matters.
- Maximum size: 100 physical lines.

Session names bounded warm lifetime; attempt names one recorder/provider; each
tap creates request. Originating controller freezes provided
`documentIdentifier`; it is immutable. Open URL contains only opaque routing,
never content/secrets; app records only for fresh shared request, not ordinary launch.

Recreated extension regains control only when session/attempt/request match
shared state and last app-consumed handoff. This restores phase/Finish/Cancel and
candidate delivery request, not destination. Returned ID never replaces source.
Eligibility requires active visible controller and exact non-empty current =
source. Hidden can observe, not claim. Missing current retries briefly; missing
source or any mismatch permanently invalidates request/controller—even A→B→A.
Warm attempt freezes current ID anew. Missing current does not hide/disable
capture; two missing IDs never match. Loss is silent; explicit Latest remains.

One accepted result causes at most one auto `insertText`. Keyboard creates opaque
claim; app grants exact claim; controller rechecks on same proxy/ID then invokes.
Recreated controller inherits no grant and must independently claim/prove. Ack
means one invocation, not host rendering; callbacks are diagnostics, not receipts.
Ack retires only attempt and returns unexpired session Ready. Explicit transient
Latest may consume unacknowledged or new grant and retires identically.

Expiry callback reloads canonical slot and clears only its scheduled snapshot;
newer same-attempt Processing/Result/Failed/Unavailable is handled once despite
late notification. App owns private Latest, History, and History-derived Latest;
shared coordination is not transcript storage. Uncertain insertion never auto-
retries; user may consume transient or projection. Cancelled/failed/expired/
superseded never insert; already-started protected provider work remains authoritative.
