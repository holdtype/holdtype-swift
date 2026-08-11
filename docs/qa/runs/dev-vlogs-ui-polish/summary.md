# Dev Vlogs UI polish QA

Run date: 2026-08-11

## Runtime lane

- Runtime QA: required
- Tool: Computer Use (`@oai/sky`) against a temporary, uniquely identified copy
  of the freshly built sanitized app
- Launch policy: `HOLDTYPE_AUTOMATION=1` and
  `HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip`
- Starting state: Dev Vlogs Off, no camera choice, no selected application, and
  the proposed default destination

## Scenarios

### Window and sections

- Actions: opened the real Dev Vlogs window; selected Overview, Capture,
  Applications, and Storage; enabled setup; used Overview's Camera row; zoomed
  and restored the window.
- Expected: Settings-quality native hierarchy, truthful Setup state, all four
  setup sections interactive, no clipping at normal or zoomed size.
- Observed: all four sections were reachable; the enable toggle changed Off to
  Setup required; Overview's Camera row navigated to Capture; controls enabled
  without opening a permission prompt; zoom preserved the complete hierarchy.
- Result: PASS
- Evidence: `components/01-shell-sidebar-before.png` through
  `components/05-storage-before.png`, and `final/dev-vlogs-final.png`

### Protected capture and permission behavior

- Actions: inspected Capture without invoking Request Camera Access; inspected
  Applications and Storage without opening their pickers.
- Expected: no passive permission request, preview, camera capture, microphone
  capture, or external-folder write.
- Observed: no prompt, preview, capture, or picker appeared. Capture explicitly
  states that opening the page never starts preview or capture.
- Result: PASS

### Menu and reopen residual

- Actions: attempted to target the status item through Computer Use after
  isolating the QA bundle identity; closed the Dev Vlogs window and attempted a
  bounded reacquisition after relaunch.
- Expected: inspect the runtime utility order and close/reopen route.
- Observed: Computer Use reached the real app windows but could not address the
  `MenuBarExtra` window while other installed copies shared the production
  bundle identity; after the explicit final close, reacquisition timed out.
- Result: BLOCKED for these two runtime substeps
- Narrow fallback: the exact utility order is covered by
  `MenuBarPresentationTests`, and the separate stable Dev Vlogs scene/open route
  is covered by `DevVlogsSceneTests` plus the successful runtime window opening.

## Visual comparison

Five tight first-pass crops and five ImageGen references were reviewed. The
implemented SwiftUI already carried the durable hierarchy, spacing, grouping,
action priority, and semantic styling supported by the references. No product
correction pass was warranted. The `final/*-after.png` files intentionally match
the accepted first-pass crops.

Light appearance was inspected at runtime. The implementation uses semantic
system colors and native grouped Form/List controls; a separate Dark appearance
runtime pass was not completed inside the bounded lane.

The Storage evidence contains a sanitized path bar. No private path, credential,
user content, camera image, or captured media is retained.

## Verification

- `python3 scripts/check_swift_structure.py`: PASS
- Focused MenuBarPresentation and Dev Vlogs Scene/Readiness/CameraSetup/
  Applications/Storage tests: PASS
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' build`: PASS
- `git diff --check`: PASS
