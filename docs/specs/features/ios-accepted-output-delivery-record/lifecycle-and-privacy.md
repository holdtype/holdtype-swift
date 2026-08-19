# Historical Accepted Delivery Lifecycle And Privacy

- Node type: leaf
- Status: Historical
- Read when: reviewing retired clear/replacement/expiry/privacy invariants.
- Do not read when: defining current Pending, Latest, History, or bridge behavior.
- Maximum size: 100 physical lines.

Acknowledgement contained identities/generation and one honest outcome, no text.
Only an exact current epoch mutated the record; duplicates/stale/cross-delivery
values were no-ops and never triggered insertion.

Clear, discard, cancellation, and replacement first revoked matching bridge
eligibility, transferred unresolved History work, then CASed a content-free
tombstone or atomically replaced old bytes. Confirmed tombstone was the visible
Clear boundary; cleanup accepted no caller payload and could not reveal text or
remove a newer record. New output never destroyed the only durable payload
between commits.

Eligibility ended exactly at immutable expiry. Rollback ambiguity stopped
display, publication, mutation, and insertion while allowing constrained
explicit clear; forward jumps could expire early. Monotonic deadlines could
shorten but not extend wall expiry. Expired bytes became ineligible immediately
and were removed only after revocation and exact revision checks.

The record excluded audio, secrets, prompts, provider payload, host/context,
clipboard, paths, and sensitive logging. Keyboard saw only a short-lived
sanitized projection and never linked app-private persistence/History/provider/
secret owners. Large text remained app-owned; bidirectional text was isolated.
Protection and backup exclusion did not claim defense from privileged or
legitimately unlocked process access.
