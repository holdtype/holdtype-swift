# Verification Strategy

- Node type: hybrid
- Contract ID: `holdtype.qa.verification-strategy`
- Domain ID: `holdtype.qa`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.qa.verification-strategy@1`
- Read when: choosing fake seams, automated/manual boundaries, timeout behavior, or publication verification separation.
- Do not read when: product intent or a platform command alone is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Prove MVP dictation deterministically without live OpenAI, real microphone,
uncontrolled permission prompts, real paste targets, or unbounded waits in
normal automation. Unit/fake-backed logic precedes bounded platform evidence.

## Children

- [Development and publication](verification-strategy/development-and-publication.md) — test evidence versus publish action and distributable integrity.
- [Core service seams](verification-strategy/core-service-seams.md) — session, recorder, permissions, provider, credential, output, hotkey, and UI boundaries.
- [Invariants and evidence](verification-strategy/invariants-and-evidence.md) — no-live rules, timeouts, failures, task mapping, logs, and unknowns.

## Dependency

- `platform-testing-strategy.md` consumes these seams and owns per-platform selection.

Verification artifacts do not replace product contracts and this document does
not require implementing test infrastructure or exhaustive UI coverage.
