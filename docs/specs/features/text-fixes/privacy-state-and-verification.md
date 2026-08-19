# Text Fixes Privacy, State, And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.shared.text-fixes@3`
- Clauses: `TF.PRIVACY`, `TF.STATE`, `TF.FAILURE`, `TF.VERIFY`
- Read when: Fixes consent, persistence, logging, failure, or acceptance is in scope.
- Do not read when: only catalog presentation is in scope.
- Maximum size: 100 physical lines.

## Privacy and state

- macOS has no separate Fixes consent/acceptance; compatible Fixes are enabled
  when API key and Accessibility prerequisites exist.
- iOS disclosure v4 says a user-invoked Fix sends only chosen source and
  instruction to OpenAI. Acceptance v3 or older requires review before the
  next provider request. Keyboard copy explains transient App Group mediation.
- API keys never enter catalog, App Group, extension, logs, or diagnostics;
  full prompts remain app-private/macOS-local. Default logs contain only action
  IDs and closed outcomes, never content, context, key, or provider body.
- Voice Prompt audio/transcript is attempt-only except bounded failed recording
  ownership. Source is excluded from audio request and enters only transformation.
- Source/results are removed on acknowledgement, cancellation, terminal failure,
  or expiry. No remote request precedes applicable authorization and credential.
- macOS stores versioned catalog and shortcut status; Voice Prompt content and
  target remain transient. iOS stores app-private catalog and replaceable App
  Group metadata/request/result records with opaque IDs, revision, expiry, and no log.

## Failure and verification

- Missing permission, platform authorization, credential, Full Access, or
  Translation route yields actionable blocking and no request; macOS is never
  blocked by app-owned Fixes consent.
- Provider/timeout/cancellation/invalid-output/save failures preserve source.
  Catalog load failure leaves normal text surfaces usable. Bridge failure does
  not change canonical catalog. Restart never replays an old result.
- Tests cover defaults/schema migration/CRUD/ordering/corruption/bounds/redaction;
  exact provider projection/routing/output/timeout/cancellation/late response;
  macOS AX/palette/Undo/hosts; Voice Prompt two stages and protected sinks;
  iOS Unicode/range/Undo; and keyboard metadata, identity, expiry, exactly-once,
  Full Access, restricted hosts, and leakage—all with fakes.
- Simulator proves presentation/integration. Signed physical iPhone evidence is
  required for host traversal, focus, Full Access, background processing, and replacement.
