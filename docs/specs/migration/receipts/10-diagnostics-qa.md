# Receipt 10 — Diagnostics And QA

- Node type: leaf
- Status: accepted
- Batch ID: `10-diagnostics-qa`
- Contract revisions: `holdtype.macos.diagnostics-and-crash-reports@1`, `holdtype.qa.platform-testing@1`, `holdtype.qa.verification-strategy@1`
- Read when: reviewing batch 10 provenance, validation, or resume state.
- Do not read when: selecting or processing an unrelated active batch.
- Maximum size: 100 physical lines.

## Provenance and disposition

- `features/diagnostics-and-crash-reports.md`: `75b42da5fa99af8f357c73051ef50259ea3aa806f388179394cc26962ce71a64`; `contract`.
- `features/platform-testing-strategy.md`: `af5c2547ccf6b5e2ee75b5e021319c63208c45e927c1711b0adcc16455fd1693`; `contract`.
- `features/verification-strategy.md`: `852ea0234f14e9d4a469b9a5d7da9dabe0e997340f479fd8d13032c2f0f94b96`; `contract`.

## Semantic disposition

- Active/Accepted QA and legacy-released macOS diagnostics authority remain.
- Stable inbound paths become bounded hybrids; no semantic Delta exists.

## Created or updated paths

- product/macOS/QA branches; diagnostics plus two children; platform testing
  plus three children; verification plus three children; migration state.

## Validation

- Links, cycles, reachability, sizes, coverage, hashes, numeric retention,
  JSON absence, and whitespace are checked before integration.
- Privacy/redaction, fake/live boundary, runtime decision, iOS isolation,
  publication boundary, blockers, and evidence mappings remain represented.

## Residuals and next batch

- Residual corpus after acceptance: 31 documents in 18 batches.
- Next: `11-distribution` after push.
