Before inspecting implementation source, read the current project's
`AGENTS.md`, `docs/specs/README.md`, `docs/specs/index.md`, and every active
spec relevant to the task. Read `BACKLOG_DEVELOPMENT.md` only for explicit
backlog work.

State a compact Spec Basis before source inspection:

- authoritative spec paths
- expected user-visible behavior
- invariants and edge cases
- gaps or conflicts
- required spec impact
- whether implementation is authorized

If the requested change affects user-visible behavior, update or create the
spec before the first implementation edit. Only then read `SWIFT.md`, inspect
the source, and implement against the Spec Basis.

For a behavioral bug, derive expected behavior from the specs first and actual
behavior from code, tests, and runtime evidence second. Name the discrepancy
before fixing it.

Planning-only and investigation-only requests must not turn into implementation
without explicit user authorization.

For menu bar, microphone, OpenAI transcription, permissions, external-service,
Keychain, clipboard, auto-paste, or text handoff work, resolve product behavior
before choosing implementation details.

Keep the spec short and product-level.

Do not rely on ad hoc chat memory as the source of truth for feature behavior.
Do not treat current code as product intent when it conflicts with or is not
covered by the active specs.
