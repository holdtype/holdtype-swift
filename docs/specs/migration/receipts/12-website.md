# Receipt 12 — Website

- Node type: leaf
- Status: accepted
- Batch ID: `12-website`
- Contract revisions: `holdtype.website.hosting@1`, `holdtype.website.localization@1`
- Read when: reviewing batch 12 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/landing-page-hosting.md`: `3d198ff71a180da57f11147b38f2f1d9a10ad9053df2cf73e8a52a4f6f5e14e9`; `contract`.
- `features/landing-page-localization.md`: `6bb363e6fb3a45e346d0bcfebc069c86fa1e5c3bc7861c88d90af67f1c94916c`; `contract`.

## Semantic disposition

- Active/Accepted website authority remains; app localization and update-feed
  migration remain excluded. Stable paths become hybrids; no Delta exists.

## Created or updated paths

- product/website branch; hosting plus three children; localization plus two
  children; migration root, batch, and receipt.

## Validation

- Links/cycles/reachability/sizes, coverage, hashes, exact routes/assets/URLs,
  JSON routing absence, and whitespace checked before integration.
- Hosting/feed isolation, media/accessibility, copy evidence, deploy/DNS
  failure, locale selection/RTL/parity/metadata, and QA remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 27 documents in 16 batches.
- Next: `13-coverage-discovery` after push.
