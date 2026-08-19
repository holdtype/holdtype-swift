# iOS Settings And Secret Storage

- Node type: hybrid
- Status: Active
- Authority: current where consistent with V1.1 release
- Contract: `holdtype.ios.settings@1`
- Read when: iOS configuration, Library, secrets, persistence, or setup truth matters.
- Do not read when: legacy Quick Session/typing/storage expansion is requested.
- Maximum size: 100 physical lines.

Provide native iPhone/iPad configuration while the containing app canonically
owns settings, user content, and OpenAI key. Scope includes defaults,
validation, persistence/migration, app-only credential state, minimal keyboard
snapshot, private Fixes catalog, setup truth, and navigation.

No Settings.bundle, accounts/subscriptions/analytics/cloud/team policy,
provider marketplace/local/self-hosted models, unimplemented modes, macOS-only
preferences, or inert future controls.

## Children

- [Surfaces and defaults](ios-settings-and-secret-storage/surfaces-and-defaults.md)
  — app navigation, system boundaries, current configuration.
- [API-key storage](ios-settings-and-secret-storage/api-key-storage.md) — exact
  Keychain identity, commits, coordinator, cache, preflight, and redaction.
- [Credential status](ios-settings-and-secret-storage/credential-status.md) —
  six-state truth, three-state UI, marker transaction reconciliation.
- [Protected files and JSON](ios-settings-and-secret-storage/protected-files-and-json.md)
  — file identity, limits, atomic publication, strict structural gate.
- [General settings record](ios-settings-and-secret-storage/general-settings-record.md)
  — v1 schema, defaults, failures, and protection.
- [Library record](ios-settings-and-secret-storage/library-record.md) — v1
  schema, normalization, validation, ordering, and ownership.
- [Process state owners](ios-settings-and-secret-storage/process-state-owners.md)
  — Settings/Library FIFO and credential presentation.
- [Credential marker](ios-settings-and-secret-storage/credential-marker.md) —
  private v1 payload and failure contract.
- [Validation and general editors](ios-settings-and-secret-storage/general-editors.md)
  — field rules, latest-wins autosave, recovery, and Recording controls.
- [Library and Fixes editors](ios-settings-and-secret-storage/library-and-fixes.md)
  — typed mutations, CAS, drafts, navigation, metadata projection, catalog.
- [Truth, failures, and verification](ios-settings-and-secret-storage/truth-and-verification.md)
  — readiness, migrations, invariants, edge cases, and evidence.

## Dependencies

- [V1.1 release](ios-v1-release.md) — current scope and precedence.
- [Guided recovery](ios-settings-guided-recovery.md) — exact field routing.
