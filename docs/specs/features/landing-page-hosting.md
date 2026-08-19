# Landing Page Hosting

- Node type: hybrid
- Contract ID: `holdtype.website.hosting`
- Domain ID: `holdtype.website`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.website.hosting@1`
- Read when: public landing behavior, DigitalOcean deployment, Pages/appcast coexistence, DNS, or website QA is in scope.
- Do not read when: app behavior or localization routing alone is in scope.
- Maximum size: 100 physical lines.

## Goal

Serve `https://holdtype.app/` as a static DigitalOcean App Platform site without
breaking the GitHub Pages Sparkle feed/release notes. `www` redirects to apex;
technical hostname remains noncanonical diagnostic access.

## Children

- [Product page and media](landing-page-hosting/product-page-and-media.md) — hero/copy, download/setup, social image, tutorial facade, screenshot modal, and accessibility.
- [Deployment and update feed](landing-page-hosting/deployment-and-update-feed.md) — DigitalOcean, Pages, appcast/release artifacts, DNS, serialization, and publish commands.
- [Failures and verification](landing-page-hosting/failures-and-verification.md) — atomic stop conditions, health checks, artifact/browser QA, and protected feed.

## Invariants

- DigitalOcean publishes only `website/`; docs/automation/QA are not public.
- Production includes all locales, sitemap, and generated HTML without source
  `data-i18n`; exact shared OG PNG is 1200×630 with complete metadata.
- GitHub Pages remains a complete landing/appcast/release-notes artifact and
  stable feed URL until a separate updater migration.
- Website failures never replace/remove Sparkle feed or report a partial release.

## Dependency

- [Localization](landing-page-localization.md) — locale routes, language behavior, metadata, and RTL.
