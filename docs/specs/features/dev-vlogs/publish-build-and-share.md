# Dev Vlogs Publish, Build, And Share

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-BUILD-1..9`, `DV-SHARE-1..3`, `DV-REVIEW-1..5`
- Read when: Publish scope, reconstruction, recipe, rendering, Export, Reveal, or Share is in scope.
- Do not read when: direct remote publication is proposed.
- Maximum size: 100 physical lines.

- Publish selects newest-first day, then All Applications or one app present;
  shows remaining count/duration/bytes/health. Create Video freshly scans every
  valid remaining clip in scope and orders timestamp then stable ID.
- Save Original-policy recipe with ordered source IDs before user-initiated
  render. Output is new and immutable; never overwrite source/prior export.
- Build uses Apple-native compatible video passthrough only. Any incompatible/
  changed source fails with no output, preserving recipe/sources/outputs—never
  transcode/downscale/reduce nominal FPS.
- Failed/cancelled build preserves source and is retryable from recipe. Media
  work is cancellable/bounded and reuses valid artifacts.
- No selection, exclusion, reorder, trim, timeline, aspect variants, captions,
  cards, transitions, silence trimming, highlights, CLI, or automation API.
- V1 delivery ends at local Export, Reveal in Finder, and macOS Share. Build is
  independent of accounts/publication; only completed exports may feed a future adapter.
