# Landing Failures And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.website.hosting@1`
- Clauses: `WEBSITE.FAILURE`, `WEBSITE.VERIFY`
- Read when: publish stop conditions, artifact integrity, deployed health, or browser QA is in scope.
- Do not read when: only authoring local copy is in scope.
- Maximum size: 100 physical lines.

- Bounded failure to resolve stable release/appcast/release notes leaves prior
  Pages live. App Platform timeout/sync failure changes no DNS.
- Missing locale/sitemap/marker, remaining source localization marker, or
  missing/non-PNG/non-1200×630 social asset fails before healthy publication.
- Failed technical-host marker stops domain/DNS. Tutorial failure leaves written
  official setup sufficient. No-JS screenshots remain normal original links.
- Release cannot succeed if Pages removes landing or differs from release update metadata.
- Verify both workflows construct complete Pages artifact; App Platform source/
  branch/auto-deploy; publish sync/timeouts/no credentials; exact locale/social/
  metadata/allowlist/appcast/release-note reconstruction.
- Runtime checks root/feed/current notes, Copy, responsive/browser console,
  tutorial pre/post Play, modal pointer/keyboard/dismiss/focus/phone behavior.
