# Historical Consent Mutation And Authorization

- Node type: leaf
- Status: Historical
- Read when: reviewing CAS/fence/root authorization safety.
- Do not read when: using it to change current consent behavior.
- Maximum size: 100 physical lines.

Observation carried exact absence or epoch+revision plus process fence. Accept/
withdraw required both current. First decision minted epoch/rev1; each commit +1;
overflow closed; exact current no-op. Withdrawal closed gate/advanced fence before
I/O so old Accept never reopened even on write failure. Success published exact
repository value. Commit uncertainty reloaded exact intended/prior/other and
required directory barrier, never guessed. Confirmed unreadable reset closed gate,
removed only exact observed record, minted new epoch on later acceptance.

Authorization bound epoch/revision/disclosure/file physical revision/fence/
canonical physical root, no payload. Atomic stage gate reread/revalidated root,
registered cancellation, granted launch with no TOCTOU. One-shot result authority
was atomically consumed; withdrawal/reset/version/root/unavailable/duplicate made
late output ineligible. Each transcription/correction/translation and failed Retry
used its own registration. Executor installed cancellation behind closed permit;
loss before launch invoked nothing, after launch cancelled without waiting for late.

Provider outcome crossing gate was payload-minimized Sendable; synchronous
non-suspending consumption returned once, then local persistence occurred outside.
Local failure retained provider-free recovery and never reused/replayed. Mic/key
gates stayed independent; withdrawal never claimed remote deletion.
