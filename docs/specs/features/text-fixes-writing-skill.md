# Text Fixes Built-In Writing Skill

Status: active product contract addendum.
Contract revision: 1.

This addendum governs only the optional app-owned writing skill for macOS
custom Fixes. It extends `text-fixes.md` and wins only where that contract's
catalog schema, custom-Fix editor, or custom transformation route does not yet
describe this option. Every other Text Fixes clause remains protected.

## Product Behavior

- Each macOS custom Fix has an off-by-default `Humanize text` preference.
- The Manage Fixes SwiftUI editor presents it as an opt-in control with concise
  copy explaining that HoldType sends its bundled writing guidelines to OpenAI
  and that processing may take longer.
- Translate, Correct Text, Voice Prompt, iOS Voice, and HoldType Keyboard do not
  expose or use this preference.
- Existing custom Fix output remains exact: HoldType does not trim, normalize,
  or otherwise post-process a successful result.

## Skill Ownership And Provider Route

- The skill is a versioned ZIP resource shipped inside HoldType. HoldType never
  reads or requires `~/.codex`, a user-owned skill directory, or another local
  installation.
- The ZIP contains exactly one top-level `de-ai-writing` folder with its
  `SKILL.md`, app-owned references, and bounded scripts.
- When the preference is enabled, HoldType creates an ephemeral OpenAI hosted
  container with the ZIP as one inline Agent Skill. The Responses request
  attaches that container as a hosted shell environment, requires tool use,
  and explicitly instructs the model to use `de-ai-writing` for the current
  custom transformation.
- Skill provisioning is a separate provider stage with a 20-second maximum.
  HoldType caches the active container identifier for later enabled Fixes and
  recreates the container once after a transformation response proves the
  cached identifier has expired.
- Provisioning or skill execution failure never falls back to prompt-only
  processing and never changes the saved model or source text.
- The option is available only for exact model identifiers HoldType recognizes
  from current OpenAI model contracts as supporting Agent Skills. Unknown or
  unsupported models fail before provider work with an actionable error.
- The transformation remains `store: false`, uses the current app-owned OpenAI
  credential, has explicit cancellation, and keeps the selected processing
  profile's transformation timeout.

## Privacy And Network Boundary

- The bundled ZIP is sent to OpenAI only after the person runs a custom Fix
  whose `Humanize text` preference is enabled.
- HoldType does not enable container network access for this skill.
- API keys never enter the ZIP, catalog, logs, diagnostics, or provider body.
- Default logs contain no skill contents, prompt, source, result, container
  identifier, authorization header, or provider response body.

## Persistence And Compatibility

- The shared local Fixes catalog schema advances to v3 and stores one Boolean
  `usesBuiltInWritingSkill` value for every action.
- Schema v1 loads with `Use Writing & Correction Settings` and the preference
  off. Schema v2 preserves its processing profile and also loads with the
  preference off. Older files are not rewritten until the next valid save.
- The two built-in action rows require the preference to be false. Invalid,
  corrupt, future, or unsupported catalog data remains preserved and reported.
- The schema remains shared by the separate macOS and iOS catalog stores. iOS
  does not expose the preference and its existing user-visible behavior stays
  unchanged.

## Verification Mapping

- Domain tests cover custom-action preservation, built-in rejection, model
  compatibility, request validation, Sendable boundaries, and redaction.
- Persistence tests cover canonical v3 round trips, strict Boolean decoding,
  v1/v2 migration with the preference off, corruption preservation, and
  separate macOS/iOS stores.
- Provider tests cover bundled ZIP loading, exact inline-container payload,
  required hosted-shell projection, exact prompt/source projection, container
  reuse, one recreation after 404, timeout, cancellation, and no live calls.
- macOS executor and editor tests cover off-by-default behavior, saved toggle
  projection, unsupported-model failure before provider work, and autosave.
- macOS Computer Use QA covers visible editor placement, toggle interaction,
  save/reopen persistence, and unchanged built-in detail presentation.

## Contract Delta — Revision 1

- Change ID: `TF-SKILL-DELTA-R1`.
- Change mode: Evolve.
- Authorized by: explicit user approval of the researched implementation plan
  on 2026-08-12.
- Previous behavior: custom Fixes sent their saved prompt and source directly
  to the selected model and could not attach an Agent Skill.
- New behavior: each macOS custom Fix may opt into the app-bundled
  `de-ai-writing` Agent Skill without any user-local skill installation.
- Compatibility: additive macOS behavior; schema v1 and v2 migrate with the
  preference off. Built-ins, Voice Prompt, target safety, iOS Voice, and
  HoldType Keyboard remain protected.
- Evidence basis: official OpenAI Agent Skills and hosted Shell documentation
  reviewed on 2026-08-12, plus current Domain, Persistence, OpenAI
  transformation, execution, editor, and fake-backed test owners.
