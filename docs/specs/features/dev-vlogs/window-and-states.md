# Dev Vlogs Window And Product States

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.macos.dev-vlogs@DV-ACTIVE-6`
- Clauses: `DV-UI-1..9`, `DV-PRODUCT-1..2`
- Read when: Dev Vlogs menu/window/navigation/presentation or lifecycle state is in scope.
- Do not read when: only media storage mechanics is in scope.
- Maximum size: 100 physical lines.

- Product name is Dev Vlogs; V1 commands are app-only. Debug menu includes
  `Dev Vlogs…`; public Release omits it during development.
- Item opens separate SwiftUI `HoldType: Dev Vlogs`, never Settings. Stable
  sidebar order: Overview, Capture, Applications, Storage, Publish; Overview default.
- Window owns enable/setup/health/destination/app rules/day summary/storage/
  local artifact preparation. No Permissions section, Library destination,
  remote accounts/uploads/public actions. Menu popover stays compact.
- Publish uses grouped Settings-quality Source Day, scope summary/status,
  Finder, Refresh, Create Video, progress, and result. No pre-build policy block;
  Original only. Actions appear only when state owner enables them.
- Attempt: not eligible/preparing/capturing/finalizing/ready/incomplete/failed/
  explicitly deleted. Build: draft/building/ready/failed/cancelled.
- Deterministic states cover no recordings, empty/populated day, invalid/missing
  source, building/cancelled/failed/completed. Visible content is SwiftUI.
