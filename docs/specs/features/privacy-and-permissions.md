# Privacy And Permissions

- Node type: hybrid
- Contract ID: `holdtype.macos.privacy-and-permissions`
- Domain ID: `holdtype.shared.privacy-and-permissions`
- Status: Active
- Stability: Accepted
- Release baseline: macOS legacy-released; current iOS contracts retain precedence
- Contract revision: `holdtype.macos.privacy-and-permissions@2`
- Read when: permissions, setup gating, remote-processing disclosure, sensitive persistence, or diagnostic privacy is in scope.
- Do not read when: only provider mechanics or feature presentation is in scope.
- Maximum size: 100 physical lines.

## Goal and scope

Make microphone capture, Accessibility/Input Monitoring, OpenAI processing,
Keychain, transcript/audio persistence, diagnostics, and the optional Dev Vlogs
camera/archive exception explicit. This is product privacy behavior, not legal copy.

## Children

- [Disclosures and retention](privacy-and-permissions/disclosures-and-retention.md) — OpenAI boundaries, local processing, audio/text ownership, Dev Vlogs, and logs.
- [Setup and credential gating](privacy-and-permissions/setup-and-credential-gating.md) — launch/action ordering, deferral, recording readiness, and Keychain cache.
- [Permissions surface](privacy-and-permissions/permissions-surface.md) — genuine TCC rows, launch at login, refresh, and warnings.
- [Accessibility](privacy-and-permissions/accessibility.md) — trust, active-app behavior, stale rows, polling, and recovery.
- [Input Monitoring](privacy-and-permissions/input-monitoring.md) — optionality, registration probes, one-shot requester, and manual fallback.
- [Signing and debug identity](privacy-and-permissions/signing-and-debug-identity.md) — entitlements, bundle identity, stable signing/path, and sandbox boundary.
- [States, failures, and verification](privacy-and-permissions/states-failures-and-verification.md) — state enums, invariants, recovery, data implications, evidence, and unknowns.

## Core invariants

- No capture without explicit user action and permission; no hidden recording
  or recording start while required usable-transcription setup is incomplete.
- Permissions contains only genuine system permissions, never app-owned consent,
  feature toggles, provider disclosure, Keychain, or API-key status.
- No retained audio except explicit recording cache, bounded failed-attempt
  recovery, and the named local Dev Vlogs archive exception.
- No provider other than OpenAI without a product decision and disclosure.
- Default logs and explicit diagnostic exports exclude sensitive user/provider content.

## Dependencies and precedence

- [Recording durability](recording-durability-and-interruption.md), [History](transcript-history.md),
  [Text Fixes](text-fixes.md), and [OpenAI transcription](openai-transcription.md).
- More-specific current iOS release/privacy/settings/handoff contracts win conflicts.
- `DV-PRIVACY-1..3` remains the narrow optional Dev Vlogs exception.
