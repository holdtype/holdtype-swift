# iOS V1.1 Guardrails And Activation Decision

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.guardrails@1`
- Read when: evaluating architecture growth or the keyboard activation model.
- Do not read when: only UI copy or navigation matters.
- Maximum size: 100 physical lines.

## Complexity

- New abstractions serve current V1.1 behavior or a required gate.
- Add no failed-History, outbox, policy-generation, receipt, lease, or capability family.
- Build no QWERTY/locale/prediction/autocorrection engine under command surface.
- Prefer one owner and one record per product concept. Keyboard dictation adds
  at most one current command and one current state/result; never reopen retired persistence.
- Tests protect invariants/failure boundaries, not every micro-state.
- Each checkpoint reports production/test line movement; simplification growth
  requires concrete visible justification.

## Verification mapping

- Scope: `docs/ios-v1-scope-reset-audit.md`.
- Development/deletion order: `docs/ios-v1-development-plan.md`.
- Keyboard MVP: `docs/ios-keyboard-dictation-mvp-plan.md`.
- Historical physical evidence under `docs/qa/runs/` does not pass device gate.

## Selected activation

Use app-owned keyboard handoff, never extension microphone access. Microphone
opens HoldType when session creation is needed and insertion requires the same
request, delivery claim, and host. Never fake Listening or record idle speech.
Signed-device feasibility is a stop gate; failure does not authorize private
APIs, indefinite background tricks, another persistence system, or QWERTY detour.
