# Platform Testing Strategy

- Node type: hybrid
- Contract ID: `holdtype.qa.platform-testing`
- Domain ID: `holdtype.qa`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.qa.platform-testing@1`
- Read when: selecting build, test, simulator, runtime, Computer Use, or physical-device evidence.
- Do not read when: only a product behavior contract is being selected.
- Maximum size: 100 physical lines.

## Goal

Prove changed behavior at the smallest useful layer, then add bounded platform
smoke when the change reaches a running surface. macOS is shipped; iOS V1.1 and
Brand Stage keyboard are selected lanes only when touched. Normal tests use
deterministic fakes, never live OpenAI, real microphone, or system prompts.

## Children

- [macOS and runtime evidence](platform-testing-strategy/macos-and-runtime-evidence.md) — unit/build layers, visible-surface smoke, Computer Use decision, and blockers.
- [iOS and keyboard evidence](platform-testing-strategy/ios-and-keyboard-evidence.md) — simulator/test isolation, shared surfaces, Brand Stage bundle proof, and device-only gates.
- [Task evidence matrix](platform-testing-strategy/task-evidence-matrix.md) — required evidence by task type and bounded fallback rules.

## Dependencies

- [Verification strategy](verification-strategy.md) — service seams and fake/manual boundaries.
- Operational commands/fallbacks remain in `docs/agent-tooling.md`.
