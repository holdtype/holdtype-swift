# HoldType Dev Vlogs UI Polish Plan

Status: approved and ready to execute

Date: 2026-08-11

Product contract: [`docs/specs/features/dev-vlogs.md`](specs/features/dev-vlogs.md), revision `DV-ACTIVE-1`

Delivery plan: [`docs/dev-vlogs-implementation-plan.md`](dev-vlogs-implementation-plan.md)

## 1. Outcome

Bring the existing Release-path Dev Vlogs window from a technically functional
setup surface to the visual and interaction quality of the current HoldType
Settings window.

The result must feel like one coherent native macOS product:

- the menu entry has the correct secondary priority;
- the sidebar is stable, compact, and uses native selection behavior;
- Overview communicates feature state and the next useful action immediately;
- Capture, Applications, and Storage read as finished product sections rather
  than loosely stacked technical forms;
- all currently shipped controls and states remain functional;
- no future placeholder section, debug control, or unimplemented feature is
  introduced.

## 2. Approved Design Brief

- Product: the existing HoldType Dev Vlogs setup window.
- Visual source of truth: the current HoldType Settings window and its native
  macOS information hierarchy, spacing, rows, section grouping, system colors,
  and SF Symbols.
- Interaction level: fully interactive; every existing control and visible
  state must continue to work.
- Platform direction: SwiftUI-first native macOS. AppKit is not authorized for
  visible content.
- Desired character: calm, precise, compact, and polished; no marketing hero,
  dashboard chrome, decorative gradients, custom icon family, or oversized
  card wall.
- ImageGen role: design evidence for hierarchy and composition only. Generated
  references do not define product behavior and are not shipped as UI assets.

## 3. Contract Change Envelope

- Change mode: scoped `evolve` for visual hierarchy and menu priority; preserve
  all accepted Phase 1 behavior.
- Authorized domains: Dev Vlogs window presentation, navigation composition,
  section layout, visible labels/help text, action hierarchy, accessibility,
  and placement of the existing `Dev Vlogs…` menu command.
- Authorized clauses: `DV-UI-1` through `DV-UI-8`, Phase 1 setup presentation,
  and the user-approved menu ordering clarification below.
- Menu clarification: the utility group order becomes `Manage Fixes…`,
  `Transcript History`, `Settings…`, `Dev Vlogs…`; Dev Vlogs is the final
  utility entry immediately before the Quit divider.
- Protected behavior: Camera permission and discovery, application-policy
  semantics, destination/bookmark persistence, readiness reduction, feature
  enablement, window singleton behavior, ordinary dictation, Keychain,
  Transcript History, Recording Cache, capture/media, iOS, and Phase 0B.
- Specification delta: only the exact menu-order clarification if the active
  menu contract or its acceptance test requires it. No adjacent semantic
  redesign is permitted.
- Release baseline: current Phase 1 accepted implementation through
  `DV-P1-STORAGE-R1`.

## 4. Scope

### 4.1 Menu hierarchy

- Move `Dev Vlogs…` below Settings in the existing utility group.
- Keep it above the divider that separates utility commands from Quit.
- Preserve labels, opening behavior, shortcuts, disabled states, and the
  compact size of the menu bar surface.
- Update the focused presentation test and the narrow menu contract wording if
  required by the accepted ordering.

### 4.2 Window shell and sidebar

- Preserve the existing separate singleton window and `NavigationSplitView`.
- Match Settings' native sidebar density, row alignment, selection treatment,
  icon scale, title rhythm, and detail-pane margins.
- Use one SF Symbol per section with consistent semantic weight:
  Overview, Capture, Applications, and Storage.
- Keep Overview selected by default and keep navigation state window-scoped.
- Avoid custom card backgrounds inside the sidebar and avoid opaque custom root
  fills that fight native macOS materials.

### 4.3 Shared detail-page language

Create a small, reusable Dev Vlogs presentation vocabulary, not a parallel
design system:

- section header: title plus one concise explanatory sentence;
- grouped settings surface: aligned rows and predictable vertical rhythm;
- status row: icon, human label, short supporting text, and an optional quiet
  recovery action;
- primary action: at most one visually dominant action per decision surface;
- secondary actions: native bordered or link treatment;
- technical identity: secondary text or tooltip, never the main label;
- warning/error: semantic system color paired with text, never color alone;
- empty and unavailable states: explicit, useful, and compact.

Prefer existing HoldType Settings components and spacing conventions when they
fit. Extract a shared Dev Vlogs component only when it is used by multiple Dev
Vlogs sections or has an independent state/accessibility responsibility.

### 4.4 Overview

The first five seconds should answer:

1. Is Dev Vlogs on or off?
2. Is setup complete?
3. If not, what single thing should I do next?

Implementation direction:

- a clear feature header with a restrained on/off control;
- one prominent readiness summary using the existing truth states: Off, Setup
  required, Ready, degraded camera, or degraded destination;
- compact setup rows for Camera, Applications, and Storage;
- each incomplete row routes to its existing owning section;
- Ready is calm confirmation, not a celebratory dashboard;
- no metrics, recent clips, build controls, or placeholders before their real
  product owners ship.

### 4.5 Capture

- Present Camera as a finished Settings-like section rather than raw labels and
  controls in a vertical stack.
- Separate authorization status, preferred-camera selection, and device
  availability into clear groups.
- Use the camera's human-readable name as the primary label; stable identity is
  supporting metadata only where genuinely useful.
- Keep the existing explicit request/recovery actions and no-fallback truth.
- Preserve passive refresh behavior and the rule that opening the section does
  not request permission, start preview, or start capture.
- Do not add preview UI in this polish goal.

### 4.6 Applications

- Make the privacy scope understandable before presenting controls.
- Present `Only selected apps` as the recommended focused choice and
  `All apps except excluded apps` as the broader explicit alternative.
- Group the mode control, explanatory copy, list, Add action, and empty state
  so their relationship is obvious.
- Use application name and icon as primary presentation; bundle identifier is
  secondary metadata.
- Keep list rows aligned and compact with a quiet removal action.
- Preserve validation, bundle-ID identity, policy semantics, and the current
  system app picker/import behavior.

### 4.7 Storage

- Lead with the current destination and availability, not with implementation
  details about bookmarks.
- Clearly distinguish the default Movies destination from a custom folder.
- Keep `Use Default`, `Choose Folder…`, and recovery/reselection actions close
  to the destination decision they affect.
- Show unavailable or corrupt states truthfully with one clear recovery path.
- Keep full paths visually subordinate and readable without truncating the
  primary status.
- Do not add capacity thresholds, archive metrics, external-volume probes, or
  storage runtime behavior in this goal.

## 5. ImageGen-Guided Visual Pass

Use `imagegen-ui-redesign` and the built-in `imagegen` workflow after the real
current app has been captured through Computer Use.

One bounded batch contains five meaningful decision surfaces:

1. window shell plus sidebar;
2. Overview readiness and setup summary;
3. Capture setup groups;
4. Applications policy and list;
5. Storage destination and recovery.

For each component:

- capture a tight current screenshot;
- state its user task and product invariants;
- ask ImageGen for a production-ready native macOS composition that matches
  HoldType Settings;
- prohibit invented actions, states, metrics, colors, icons, and future
  functionality;
- inspect the generated reference and extract only useful hierarchy, spacing,
  density, grouping, and action-priority decisions;
- implement those decisions with SwiftUI and SF Symbols;
- capture the implemented component and the complete window in context.

Artifact location:

```text
docs/qa/runs/dev-vlogs-ui-polish/
  components/*-before.png
  references/*.prompt.md
  references/*-reference.png
  components/*-after.png
  final-window.png
  summary.md
```

Generated references are QA/design evidence, not runtime assets.

## 6. Execution Sequence

### Checkpoint 1 — Shipping UI implementation

1. Inspect the current Settings and Dev Vlogs windows through the real app.
2. Capture the five component crops and the Settings reference state.
3. Run one ImageGen batch and select durable layout decisions.
4. Implement menu priority, sidebar polish, shared presentation components,
   and all four currently shipped detail sections.
5. Preserve existing state owners and service behavior.
6. Add or update focused view/model/presentation tests only where behavior or
   testable hierarchy changed.
7. Create one scoped shipping-product checkpoint commit.

This checkpoint must deliver the visible Release-path result. It must not be
replaced by a design document, test harness, or diagnostic-only checkpoint.

### Checkpoint 2 — Proportional verification and visual correction

1. Run structure and focused tests.
2. Build the macOS app.
3. Launch through `script/build_and_run.sh --verify` with a scoped
   `caffeinate` guard and no live Keychain access.
4. Use Computer Use to open the menu, confirm final utility placement, open Dev
   Vlogs, navigate every section, exercise existing safe controls/states, resize
   the window, and check close/reopen persistence.
5. Capture the five after-components and the complete final window.
6. Compare implementation against Settings and the selected ImageGen
   references for hierarchy, spacing, clipping, alignment, action priority,
   and native macOS behavior.
7. Allow one focused visual correction pass, then rerun the affected checks.
8. Perform one proportional independent review of the integrated UI wave.

## 7. Verification Matrix

### Automated

- `python3 scripts/check_swift_structure.py`
- focused Dev Vlogs scene, settings, camera, applications, storage, readiness,
  menu presentation, and menu action tests;
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination 'platform=macOS' build`
- `git diff --check`

### Computer Use scenarios

- Menu: `Dev Vlogs…` is last in the utility block and remains above Quit.
- Open: the separate window appears and Overview is selected.
- Overview Off: hierarchy is clear and no permission prompt appears.
- Overview Setup/Ready/degraded: the state and next action are truthful.
- Capture: permission, selection, remembered-unavailable, and recovery states
  are readable; passive navigation causes no permission request or capture.
- Applications: both policy modes, empty/populated list, Add, and Remove remain
  understandable and functional.
- Storage: default/custom/unavailable/corrupt presentation and recovery actions
  remain understandable and functional without live external-volume testing.
- Resize: supported window size shows no clipped labels, overlapping actions,
  unstable sidebar, or unreadable paths.
- Close/reopen: selection/persisted product settings behave according to their
  existing owners.

### Accessibility and visual quality

- every icon has a meaningful label or accompanies visible text;
- status is not conveyed by color alone;
- keyboard focus order remains logical;
- controls have useful accessibility names and help where needed;
- Light/Dark appearance follows system semantic colors;
- text does not clip at the supported minimum window size;
- primary action hierarchy is unambiguous;
- no raw identifier or path outranks the human-readable state.

## 8. Economic Limits and Stop Conditions

Planning target: 60% shipping implementation, 25% verification/review/QA, and
15% discovery/design-tooling/coordination.

- Expected total effort: 3–4 hours.
- One implementation owner at a time; no parallel UI implementations.
- One ImageGen batch of five components.
- At most one targeted ImageGen rerender per component.
- At most one post-implementation visual correction pass before review.
- Computer Use startup/targeting diagnosis is capped at 10 minutes. If it
  remains blocked, record the exact failure and use the narrowest permitted
  fallback; do not build new UI automation infrastructure.
- No new Debug harness, Phase 0B work, telemetry, observer, or test framework.
- One implementation review and one focused repair/re-review are the normal
  maximum. A second repair cycle requires a delivery-and-cost reassessment and
  explicit user approval unless a demonstrated privacy, data-loss, security,
  irreversible-action, or released-compatibility risk is unsafe.
- If a visual issue is subjective and non-blocking after the accepted pass,
  record it as a residual instead of extending the task indefinitely.

## 9. Acceptance Criteria

The goal is complete only when all of the following are true:

- the Release menu places Dev Vlogs at its approved lower priority;
- the sidebar and all four currently shipped sections visibly match the
  quality, density, and native interaction language of HoldType Settings;
- the UI no longer reads as technical scaffolding;
- every existing Phase 1 setup control and truth state remains functional;
- no preview, capture, library, build, metric, threshold, or future placeholder
  has been invented;
- focused tests, structure gate, macOS build, and diff hygiene pass;
- Computer Use has exercised the real changed flow, or a precise bounded
  runtime blocker remains explicit and the goal is not falsely marked visually
  accepted;
- before/reference/after evidence covers all five components and the complete
  window;
- proportional review accepts the integrated shipping UI wave;
- all changes are preserved in scoped commits on `master`.

## 10. Explicit Non-Goals

- one-clip capture or media finalization;
- camera preview implementation;
- external-storage runtime qualification or capacity thresholds;
- Library, Builds, Permissions, or Publishing sections before their usable
  workflows ship;
- dictation, transcription, correction, translation, output, History, Recording
  Cache, Keychain, diagnostics, updates, iOS, or marketing changes;
- a new design system, custom icon family, third-party UI dependency, AppKit
  visible surface, or reusable debug infrastructure.
