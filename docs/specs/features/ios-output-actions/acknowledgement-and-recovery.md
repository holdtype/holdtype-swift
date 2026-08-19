# Historical iOS Acknowledgement And Recovery

- Node type: leaf
- Status: Historical
- Read when: tracing retired delivery acknowledgement and recovery rules.
- Do not read when: treating acknowledgement as current V1.1 behavior.
- Maximum size: 100 physical lines.

Acknowledgement was content-free and matched delivery, session, attempt,
transcript, committed publication generation, source document, and one honest
outcome: confirmed or submitted-unverified. The extension-local claim was the
at-most-once barrier; delayed/missing acknowledgement never caused replay, and
stale/cross-generation acknowledgement was a harmless no-op.

The app-private accepted record committed before any bridge projection and
survived relaunch. The keyboard received only a bounded short-lived snapshot.
Pending work remained recoverable when the keyboard was inactive, a target
changed, the bridge was corrupt/expired, Full Access disappeared, or insertion
could not be verified. Copy/Share/dismissal never consumed recovery.

Clear, cancellation, replacement, acknowledgement, and expiry made matching
bridge bytes ineligible and scheduled physical cleanup. No path guessed the
previous host, auto-opened an app, used clipboard as transport/fallback, logged
text/context/secrets, or reported secure-field/host rejection as success.

Visible listening/processing used bounded local polling only while active;
App Group writes did not claim to wake an evicted extension. Failed eligibility
before claim could be retried explicitly; uncertainty after submission could
not. Current handoff and Latest contracts replace this lifecycle.
