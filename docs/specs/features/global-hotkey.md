# Global Hotkey

- Node type: hybrid
- Contract ID: `holdtype.macos.global-hotkey`
- Domain ID: `holdtype.macos.global-hotkey`
- Status: Active
- Stability: Released
- Release baseline: legacy-released macOS behavior; explicit historical baseline absent
- Contract revision: `holdtype.macos.global-hotkey@1`
- Read when: macOS-wide shortcut assignment, registration, or action behavior is in scope.
- Do not read when: only menu recording, microphone capture internals, or output processing is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

HoldType starts and stops dictation through a macOS-wide shortcut without
hidden capture or parallel sessions. The domain also owns local assignments for
Dictation, Translation, Fixes, and Paste Last Result.

## Non-goals

- Cloud-synced or policy-managed profiles, multiple named slots, cross-platform
  shortcut architecture, or voice-agent, meeting, notes, and local-model hotkeys.

## Children

- [Dictation and translation](global-hotkey/dictation-and-translation.md) —
  Right Command hold-to-record ownership, key races, and translation intent.
- [Assignments and registration](global-hotkey/assignments-and-registration.md) —
  Settings editor, validation, persistence, collision, and permission status.
- [Fixes and Paste Last Result](global-hotkey/fixes-and-paste-last-result.md) —
  release-triggered text actions, target capture, and safe insertion.

## Shared invariants

- Shortcut actions never create parallel recordings or hidden capture.
- Recording starts only from explicit input with microphone permission.
- Failed shortcut registration never disables manual menu recording.
- HoldType never claims unavailable registration is active.
- Shortcut handling logs no dictated text, audio, API keys, provider payloads,
  Fixes source text, prompts, or results.
- Fixes captures an external target before HoldType takes focus.

## Dependencies

- [Microphone input](microphone-text-input.md) — capture ownership and session serialization.
- [Menu bar shell](menu-bar-app-shell.md) — manual fallback and shortcut hints.
- [Settings and secrets](settings-and-secret-storage.md) — assignment editor and permission status.
- [Text output](text-output-workflow.md) — Last Result insertion recovery.
- [Post-transcription actions](post-transcription-actions.md) — translation intent.
- [Text Fixes](text-fixes.md) — compatible target and palette behavior.

## Verification mapping

- Spec-only changes use `git diff --check`.
- Native work covers hold-mode down/up, repeat suppression, transcribing
  rejection, and registration failure with fakes; runtime smoke is required
  only for actual visible or macOS-registration changes.

## Provenance

- Product brief: `docs/openwhispr_swiftui_codex_tz.md`.
- Prior contract evidence: `microphone-text-input.md`,
  `menu-bar-app-shell.md`, `settings-and-secret-storage.md`, and
  `text-output-workflow.md`.
- Retired historical reference provenance:
  `docs/openwhispr-reference-retirement.md`.
