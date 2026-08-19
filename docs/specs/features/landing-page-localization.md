# Landing Page Localization

- Node type: hybrid
- Contract ID: `holdtype.website.localization`
- Domain ID: `holdtype.website`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.website.localization@1`
- Read when: locale routes, language selection/detection, localized metadata, RTL, or locale publication is in scope.
- Do not read when: app localization or update-feed routing alone is in scope.
- Maximum size: 100 physical lines.

## Goal and routes

Complete static pages support exactly: `en` `/`, `es` `/es/`, `de` `/de/`,
`fr` `/fr/`, `pt-BR` `/pt-br/`, `ja` `/ja/`, `zh-Hans` `/zh-hans/`, `ko`
`/ko/`, `ru` `/ru/`, and `ar` `/ar/`. Root is English canonical/x-default;
there is no `/en/`.

## Children

- [Selection and presentation](landing-page-localization/selection-and-presentation.md) — direct-route precedence, root detection, explicit storage, fallback, RTL, screenshots, and responsive cards.
- [Metadata, publication, and verification](landing-page-localization/metadata-publication-and-verification.md) — semantic parity, canonical/hreflang/sitemap/social metadata, failures, and QA.

## Invariants

- Never use GeoIP/country/location/third-party geolocation. Every route works
  without JavaScript; English is final fallback.
- Translation changes no command, URL, product name, pricing meaning, privacy
  promise, or user-owned API-key boundary and never implies localized app UI.
- Website-only publication cannot regenerate/remove/change appcast or release notes.
