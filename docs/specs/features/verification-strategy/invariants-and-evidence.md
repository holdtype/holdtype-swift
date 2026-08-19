# Verification Invariants And Evidence

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.qa.verification-strategy@1`
- Clauses: `VERIFY.INVARIANT`, `VERIFY.FAILURE`, `VERIFY.MATRIX`
- Read when: enforcing automation boundaries, handling blocked smoke, or reporting evidence.
- Do not read when: a narrower acceptance contract fully specifies verification.
- Maximum size: 100 physical lines.

- Normal automation never calls live OpenAI, needs microphone, uncontrolled
  prompts, or real paste. External waits are bounded and fail the attempt.
- Fakes model failures, not universal success. Failed sessions never overwrite
  prior success. Logs are reviewed/tested to exclude keys, audio, transcript,
  headers, prompts, and full responses.
- If smoke cannot quickly inspect app, record exact blocker and retain unit/
  build evidence. Off-console UI-runner failure permits narrow target evidence.
- If a fake cannot express behavior, add a small seam before broad platform
  logic. Live provider/mic evidence must be explicit, opt-in, bounded. Disable
  investigation debug logging before completion.
- Service boundaries remain small/injectable for recorder, provider,
  permissions, Keychain, clipboard/paste, hotkey, settings, history, logging,
  and clock/timeout.
- Mapping: docs diff check; model/service matching test; UI build + diff +
  Computer Use; provider fake URL/timeout; permission/mic fake state plus
  platform smoke only when changed; text handoff fake plus runtime only for adapter.
- Open questions: opt-in live provider release checklist, unreliable unattended
  UI-test scheme membership, and durable versus per-task real mic/paste evidence.
