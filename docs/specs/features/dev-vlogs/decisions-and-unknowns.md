# Dev Vlogs Decisions And Unknowns

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-D01..13`, `DV-EU-1..5`, `DV-BUILD-6`
- Read when: a product fork, storage threshold, preview gate, or scope decision is in scope.
- Do not read when: the selected clause is already resolved by another leaf.
- Maximum size: 100 physical lines.

- D01 Overview/Capture/Applications/Storage/Publish, no Library; D02 selected
  apps default, exclusions secondary; D03 freeze trigger; D04 dictation mic only.
- D05 preserve negotiated source without HoldType quality downgrade/encode or
  quality selector; D06 mirror preview only; D07 measured thresholds or gated.
- D08 no automatic retention/in-app deletion; Finder owns it. D09 all remaining
  selected-scope clips, no editor/reorder. D10 no transcript by clips. D11 app
  commands only. D12 local Export/Reveal/Share. D13 name Dev Vlogs.
- EU1 measured camera preparation budget; EU2 offset/drift; EU3 byte rate and
  finalization overhead; EU4 broader hardware/storage matrix; EU5 supported
  SwiftUI-first preview lifecycle. These are capability residuals, not authority
  to invent values or block independent setup.
- `DV-BUILD-6` is resolved: incompatible passthrough means truthful failed
  Build with no output. No encode fallback is authorized.
