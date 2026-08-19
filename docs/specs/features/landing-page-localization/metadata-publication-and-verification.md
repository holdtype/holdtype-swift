# Locale Metadata, Publication, And Verification

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.website.localization@1`
- Clauses: `LOCALE.METADATA`, `LOCALE.PUBLISH`, `LOCALE.VERIFY`
- Read when: translation completeness, SEO/social metadata, sitemap, locale failure, or QA is in scope.
- Do not read when: only root language detection is in scope.
- Maximum size: 100 physical lines.

- Meaning-changing copy updates every locale semantically; matching keys alone
  are insufficient. Pricing examples say messages/dictations without length,
  speed, or typical-size claims.
- Each page has correct BCP 47 `lang`; Arabic also RTL; self canonical,
  reciprocal all-ten `hreflang`, and root x-default. Localize title/description/
  social/accessibility metadata. Sitemap contains every canonical locale.
- Same absolute 1200×630 PNG and large-card metadata across routes; artwork remains English.
- Explicit locale choice is the only persisted state and contains no personal/location data.
- Incomplete translation/metadata or any locale build/publish failure blocks
  replacement and preserves current site/feed.
- Static checks exact routes/keys/metadata/canonicals/hreflang/sitemap/RTL/social.
  Browser QA direct precedence, root routing, regional matching, persistence,
  query/fragment, keyboard selector, storage fallback. No-JS QA covers content/
  download/setup/links; visual QA German/CJK/Arabic/screenshots; Pages checks
  appcast and all referenced notes remain exact.
