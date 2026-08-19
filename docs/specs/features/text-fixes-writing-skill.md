# Text Fixes Built-In Writing Skill

- Node type: leaf
- Contract ID: `holdtype.macos.text-fixes-writing-skill`
- Domain ID: `holdtype.shared.text-fixes`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released
- Contract revision: `holdtype.macos.text-fixes-writing-skill@1`
- Precedence: extends `holdtype.shared.text-fixes@3` only for this option
- Read when: the app-owned Humanize text option for a macOS custom Fix is in scope.
- Do not read when: built-ins, Voice Prompt, iOS, or ordinary custom Fixes are in scope.
- Maximum size: 100 physical lines.

## Product behavior

- Every macOS custom Fix has off-by-default `Humanize text`. Manage Fixes
  explains that bundled writing guidelines go to OpenAI and may be slower.
- Translate, Correct Text, Voice Prompt, iOS Voice, and Keyboard neither expose
  nor use it. Successful custom output remains exact with no post-processing.

## Skill and provider ownership

- HoldType ships a versioned ZIP with exactly one top-level `de-ai-writing`
  folder containing `SKILL.md`, app-owned references, and bounded scripts. It
  never reads/requires `~/.codex`, user skill directories, or another install.
- When enabled, HoldType creates an ephemeral hosted OpenAI container with the
  ZIP as one inline Agent Skill, attaches hosted shell, requires tool use, and
  explicitly directs the model to use `de-ai-writing` for this transformation.
- Provisioning is a separate 20-second stage. Cache the active container and
  recreate it once when a response proves it expired.
- Provisioning/execution failure never falls back to prompt-only processing,
  changes the selected model, or changes source text.
- Only exact model IDs recognized by current OpenAI contracts as Agent-Skill
  capable are allowed; unknown/unsupported models fail before provider work.
- Transformation stays `store: false`, uses app-owned credential, explicit
  cancellation, and the selected profile's transformation timeout.

## Privacy, persistence, and compatibility

- Send the ZIP only when the user runs an enabled custom Fix; container network
  access remains off. Keys never enter ZIP/catalog/logs/diagnostics/body.
- Default logs omit skill contents, prompt/source/result, container ID,
  authorization header, and response body.
- Shared catalog schema v3 stores Boolean `usesBuiltInWritingSkill` for every
  action. v1 defaults profile and option off; v2 preserves profile and sets it
  off; neither rewrites before a valid save.
- Built-ins require false. Invalid/corrupt/future/unsupported data is preserved
  and reported. Separate macOS/iOS stores share schema; iOS behavior is unchanged.

## Verification and delta

Tests cover action preservation, built-in/model validation, Sendable/redaction,
strict v3 and v1/v2 migration, bundled ZIP/payload/hosted shell, exact
prompt/source, reuse/one 404 recreation, timeout/cancellation, editor autosave,
and no live calls. Computer Use covers toggle placement and save/reopen.

`TF-SKILL-DELTA-R1`, authorized 2026-08-12, additively permits this app-bundled
skill; built-ins, Voice Prompt, target safety, iOS Voice, and Keyboard stay protected.
