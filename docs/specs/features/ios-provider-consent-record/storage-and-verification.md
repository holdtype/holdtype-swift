# Historical Consent Storage And Verification

- Node type: leaf
- Status: Historical
- Read when: reviewing consent durability/root/invariant evidence.
- Do not read when: treating legacy evidence as current acceptance.
- Maximum size: 100 physical lines.

Consent reused protected bounded regular-file mechanics but required directory
sync after rename/unlink. Success required exact bytes/absence revalidation plus
barrier; post-change failure was commitUncertain and minted no authorization.
Backup eligible, never cloud/other stores. Production accepted no alternate path;
fresh container securely bootstrapped owner-only no-symlink Application Support
and pinned physical root; failure had no pathless fallback.

Invariants: no provider absent current durable/live authorization; no stale Accept
after Withdrawal/Reset attempt; no epoch/root reuse or TOCTOU; passive read grants
nothing; bad/ambiguous file is no consent; reset exact/fail-closed.

Tests covered strict wire/path/limits/dates/UUID/duplicates/bad preservation/
protection/backup/atomic failure; CAS/withdraw/reaccept/queues/overflow/uncertain/
reset races; all stage launch/result withdrawal/reset/version/root/cancellation/
late cases; old v1→v2 semantics; closed permit/payload canaries/no async work under
fence; secure root bootstrap/substitution/syscall failure; redaction. No real key,
microphone, or OpenAI.
