# Text Fixes

Status: active product contract.

## Goal

Let a person transform text already being edited by choosing a reusable
HoldType Fix. The action applies to the non-empty selection when one exists
and otherwise to the complete compatible field or HoldType Voice Draft.

The same catalog concept is available in the macOS app, iOS Voice, and
HoldType Keyboard while each platform keeps an honest compatibility boundary.

## Scope

- built-in Translate and Fix actions
- user-authored prompt actions
- local catalog editing and persistence
- macOS `Option+J` palette behavior
- selection and complete-field target rules
- iOS Voice and keyboard presentation
- remote processing, privacy, failure, and stale-target behavior

## Non-goals

- automatic rewriting while the user types
- chained or batch actions
- cloud or cross-platform catalog sync
- clipboard fallback for an inaccessible target
- replacing text in secure fields
- importing another product's catalog
- per-action credentials or provider selection
- adding immediate Fixes to dictation History or Usage

## Catalog

- **Fixes** is the feature and catalog name. One catalog item is a **Fix**.
- The first two actions are always:
  1. `Translate`, using the saved HoldType Translation route and model;
  2. `Correct Text`, the built-in typed `Fix` action, forcing the saved Writing
     & Correction model and prompt for this request without changing the
     durable automatic-correction preference.
- Translate and Correct Text are typed actions. They cannot be deleted or
  converted into arbitrary prompts.
- New catalogs also include editable prompt actions for Improve Writing, Make
  Shorter, Summarize, Bullet Points, Change to Casual, and Markdown.
- A custom Fix has one stable identifier, title, supported icon, prompt,
  enabled state, and user-defined position after the two built-ins.
- A title is required and limited to 80 user-perceived characters.
- A custom prompt is required and limited to 8 KiB of UTF-8.
- The icon comes from a finite HoldType-supported SF Symbols set so every
  surface can render the same semantic icon safely.
- Users can add, edit, reorder, enable, disable, and delete custom Fixes.
- On macOS, users reorder custom Fixes by dragging their rows in the Fixes
  editor sidebar. Reordering is unavailable while the sidebar is filtered.
  Translate and Correct Text remain pinned above the draggable custom rows.
- HoldType does not provide a Restore Defaults action for Fixes. Custom Fixes
  remain unchanged unless the user explicitly edits, reorders, or deletes them.
- Catalogs are local and separate on macOS and iOS in the first release.
- Corrupt or unsupported catalog data is preserved and reported. HoldType does
  not overwrite it with defaults while reporting a successful load.
- A catalog written before the built-in `Fix` label was renamed to `Correct
  Text` remains usable. On load, HoldType recognizes only the exact former
  built-in `builtin.fix` payload and presents it as `Correct Text`; it leaves
  custom action titles and prompts unchanged. Any other invalid built-in
  payload remains corrupt catalog data and is reported without being rewritten.
- macOS keeps a local recent-use record containing only an action identifier
  and the time of its most recent successful immediate Fix. It contains no
  source text, result, prompt, target, or provider data.

## Target Selection

- The target is captured when the platform's supported Fixes invocation occurs,
  before the palette or app transition can move focus.
- A non-empty selection is the source and replacement range.
- With no selection:
  - macOS uses the complete value of the same compatible Accessibility text
    element;
  - iOS Voice uses the complete confirmed Draft;
  - HoldType Keyboard reports that a text selection is required.
- A visually blank source is unavailable and starts no provider request.
- The source is limited to 32 KiB of UTF-8 for one Fix request. A larger target
  remains unchanged and shows a concise size-limit failure.
- macOS support means compatible non-secure text controls exposed through
  public Accessibility APIs. Custom-rendered, protected, or incomplete
  controls may be unavailable.
- Keyboard support is selection-only in the first release and uses the
  host-provided selected text. Public keyboard context APIs do not prove a
  complete no-selection field or provide a safe exact replacement primitive.
  A partial or uncertain context is never presented or processed as the
  complete input.

## Processing And Replacement

- Only one immediate Fix may be active on a surface. Further taps are ignored;
  actions are not queued.
- The request freezes the action, exact source, target identity, and target
  revision or fingerprint.
- Custom Fixes use the saved Writing & Correction model with their own prompt.
  They do not inherit transcript-correction length-ratio safety rules.
- Every remote request uses the current app-owned OpenAI credential, any
  platform-level provider authorization that applies, `store: false`, explicit
  cancellation, and a 20-second maximum wait.
- Custom Fix output is used exactly as returned. HoldType does not trim,
  normalize typography, strip Markdown, or rewrite meaningful whitespace.
  Empty or whitespace-only output is invalid.
- Translate and Correct Text retain their existing typed output normalization
  and failure semantics.
- Immediately before replacement, HoldType revalidates the same target,
  document, source range, and source text.
- A changed, missing, unsupported, or stale target rejects the result and
  leaves current text unchanged.
- A successful action replaces only the captured range and creates one logical
  Undo mutation where the host supports it.
- Cancellation, timeout, provider failure, invalid output, persistence failure,
  and stale results leave source text unchanged.
- Successful immediate Fixes do not mutate Latest, Pending, History, Recording
  Cache, or Usage.

## macOS

- `Option+J` is the default global Fixes shortcut. Product UI renders it as
  `⌥J`.
- Fixes reacts only to a confirmed press and release of its configured shortcut.
  A matching letter without every configured modifier is ordinary typing: it
  does not inspect the Accessibility focus, open UI, or start a request.
- The shortcut captures the current external text target before opening UI.
- When no external compatible text target is focused, including a web page or
  other non-text element, Fixes does nothing. It does not open a palette or an
  explanatory dialog.
- When a focused external text control is found but cannot be used (for
  example it is secure, blank, exposes an invalid selection, or exceeds the
  source limit), Fixes does not open a palette and shows the compact Fixes
  dialog described below.
- A compact searchable palette opens centered in the visible area of the
  display containing the active text target.
- The compact centered Fixes dialog has a clear title, fully readable
  explanatory text, and one `OK` button. It closes when the user chooses `OK`,
  presses Escape, clicks outside it, or after four seconds. It has no search,
  Fix rows, keyboard selection, or alert sound. It is shown only for a found
  but unusable text control before a Fix action is chosen. Failures after an
  action has started remain in the palette when retry or stale-target context
  is useful.
- The palette opens with up to five enabled Fix rows. It orders previously
  successful actions by most recent use, then fills remaining places from the
  stable catalog order so a new user has clear examples.
- On open, the first visible Fix is selected, so Return applies the top recent
  or catalog example without requiring an additional arrow-key press.
- Typing filters the catalog and reveals at most five matching Fix rows. Exact
  and prefix matches rank before other title matches; recency then breaks
  ties. The palette is not a scrollable catalog; users refine the query instead
  of paging through all actions.
- A successful replacement updates that Fix's local recent-use record. Failed,
  cancelled, stale, or blocked actions never change the order.
- Arrow keys move selection only among visible matches; Return runs the
  selected Fix; Escape and click-outside dismiss without changing text.
- When Translation Settings resolve a target-language code, the built-in
  `Translate` row reads `Translate to <code>`, using the normalized two-letter
  code. If no target code is configured, it remains `Translate`. This label
  change applies only to the built-in action; custom Fix titles remain exactly
  as the user named them.
- The palette uses compact menu-like rows with one supported icon and one short
  title. It keeps spacing, status, progress, unavailable, failure, and stale
  states compact without showing provider payloads.
- Successful replacement dismisses the palette. A failed request may be
  retried only while the original target snapshot still validates.
- If `Option+J` cannot be registered, HoldType keeps dictation and menu
  controls available and reports the Fixes shortcut as unavailable. It does
  not expose a menu fallback for opening the Fixes palette.
- On macOS, an immediate Fix is available by default when its source is
  compatible, an OpenAI API key is available, and Accessibility trust permits
  active-app text access. It does not require a separate Fixes consent.
- Input Monitoring is required only when the chosen global shortcut invocation
  path needs it. It is not required for a Fixes action invoked through an
  already-available path.
- The menu bar exposes `Manage Fixes…` for catalog management but does not expose
  an actionable `Fixes…` palette command. On macOS, immediate Fixes are invoked
  only with `Option+J`.
- Opening a HoldType-owned editor never captures or changes an external target.
- The Fixes editor is a normal native window titled `Manage Fixes`. Its window
  title remains static while users change the selected Fix. It provides search
  and Add. A selected custom Fix provides title, prompt,
  icon, and enabled state; changes save automatically 500 ms after the most
  recent edit, and any pending change saves before the user selects another
  Fix or closes the editor. The custom Fix row exposes Delete in its context
  menu. The detail pane has no Save or Delete buttons. Users drag custom rows
  to reorder them. A selected built-in Fix shows a lock-marked informational
  block and one navigation-only settings button: Translate opens Translation
  Settings, and Correct Text opens Text Correction Settings. Built-in Fixes
  expose no editable fields, catalog-mutation actions, or other detail
  sections. The editor does not show a separate Order section or move buttons
  in the detail pane.
- The Fixes editor shows one plain, two-line description in the title bar to
  the right of the sidebar divider. It appears for every selection state,
  including when no Fix is selected. The description explains that Fixes
  transform selected text or the complete current text field, and summarizes
  `⌥J`, arrow-key selection, Return, and Escape. It has no background, shadow,
  border, title, icon, management guidance, or privacy note. Within its
  title-bar area, the description is leading-aligned with a small left inset;
  it does not shift the window title, Add button, or sidebar divider.

## iOS Voice

- The former separate one-shot Translate and Correction controls become one
  `Fixes` launcher in the Draft action area.
- The Fixes surface shows Translate and Correct Text first, followed by enabled
  custom actions.
- A non-empty Draft selection is transformed; otherwise the complete confirmed
  Draft is transformed.
- When the launcher is invoked during editing, HoldType captures the visible
  working text and non-empty selection before ending focus. It then commits
  that edit, validates the captured range against the confirmed Draft, and
  reserves the Fix snapshot. Recording, starting, finalizing, processing, or
  another Fix makes immediate Fixes unavailable.
- A result is spliced into the exact reserved range after Draft revision and
  source validation.
- A successful replacement creates one app-level Undo mutation and clears Redo.
- Auto Translate and Auto Correction remain next-dictation modes in the
  separate Auto menu and do not select or run an immediate Fix.
- The iOS containing app exposes a native Fixes editor from Library. Full
  prompts remain app-private.

## iOS Keyboard

- The center of the top rail contains a 44-point Fixes control.
- Activating it replaces the Voice workspace with a scrollable Fixes workspace
  using icon-and-title tiles. A close action restores the current Voice state.
- Quick Insert and Fixes are mutually exclusive. Voice state refreshes update
  underneath without dismissing the open Fixes workspace.
- Fixes remains visible but unavailable while a keyboard dictation request is
  Starting, Listening, or Processing.
- The extension receives only bounded action metadata: identifier, kind,
  title, icon, order, and enabled state. Custom prompts and credentials remain
  app-private.
- One metadata snapshot contains at most 100 actions and at most 64 KiB of
  encoded JSON. Identifier and kind strings are at most 128 UTF-8 bytes each;
  titles retain the catalog's 80-character limit; icon tokens are at most 128
  UTF-8 bytes.
- The extension sends one bounded, expiring immediate-Fix request containing
  request identity, action identity, source text, source kind, document
  identity, and source fingerprint. It never sends surrounding text that is
  outside the chosen source.
- A keyboard Fix requires a non-empty host `documentIdentifier`. Missing
  identity is unavailable; a context fingerprint never substitutes for it.
- An encoded request is limited to 40 KiB, including a source already limited
  to 32 KiB and opaque identifier or fingerprint strings each limited to 128
  UTF-8 bytes.
- The containing app resolves the action and prompt, checks the applicable iOS
  provider authorization and credential, performs the provider request, and
  publishes one bounded result.
- A result is limited to 64 KiB of UTF-8 output and 72 KiB of encoded JSON.
  Closed error codes are limited to 256 UTF-8 bytes. Any count, member, or
  encoded-size overflow fails closed without truncating text.
- Source and result bridge records expire after 60 seconds and are replaced
  atomically. They are transient coordination, not History or a replay queue.
- Before replacement, the active visible controller must still own the exact
  request, document, source selection or complete-field traversal, and source
  fingerprint.
- A result causes at most one replacement invocation. Uncertain replacement is
  never retried automatically.
- Full Access is required for the app-mediated Fixes bridge. With Full Access
  off, local editing and Quick Insert remain available and Fixes explains the
  requirement without fabricating processing.
- Secure fields, phone pads, host opt-out, partial context, oversized targets,
  and unprovable complete fields fail closed.

## Privacy And Data

- macOS has no `Allow OpenAI Text Fixes` control, versioned local Fixes
  acceptance, or other app-owned consent gate. A compatible immediate Fix is
  enabled by default when its OpenAI API key and Accessibility prerequisites
  are available.
- iOS disclosure contract version `4` explains that a user-invoked Fix sends
  only its selected source plus the chosen instruction to OpenAI. An acceptance
  of version `3` or older requires review before the first later provider
  request, including Voice, Retry, or Fix.
- The keyboard consent copy explains that a user-invoked Fix sends only its
  chosen source through transient App Group coordination to the containing app.
- API keys never enter the catalog, App Group, keyboard extension, logs, or
  diagnostics.
- Full custom prompts remain in app-private or macOS-local catalog storage.
- Source text and results are current-request-only. They are removed on
  acknowledgement, cancellation, terminal failure, or expiry.
- Default product logs contain action identifiers and closed outcome
  categories only. They contain no source, result, prompt, field context, API
  key, or provider body.
- No action performs a remote request until its applicable platform-level
  provider authorization and credential are available. On macOS, the Fixes
  feature has no separate provider-consent requirement.

## Invariants

- Immediate Fixes never overwrite text outside the captured target.
- A stale or uncertain target is never replaced.
- A keyboard Fix never runs without a non-empty host selection.
- A Fix request never starts recording or changes an active dictation request.
- The keyboard extension never reads Keychain or contacts OpenAI.
- External operations have explicit bounded timeouts and real cancellation.
- Normal automated tests use fakes and never contact live OpenAI.

## Failure Policy

- Missing required permission, applicable platform-level provider
  authorization, credential, Full Access, or Translation route produces a
  concise actionable blocked state and no provider request. On macOS, a Fixes
  action must not be blocked by an app-owned consent state.
- Provider, timeout, cancellation, invalid-output, and local-save failures
  preserve the source.
- If a catalog cannot be loaded, existing text surfaces remain usable and
  Fixes shows a local unavailable state.
- If an iOS bridge write or read fails, canonical app-private catalog data
  remains unchanged.
- Process or extension restart never replays or applies an old Fix result.

## Route / State / Data Implications

- macOS persists one versioned local Fixes catalog and shortcut registration
  status.
- iOS persists one versioned app-private Fixes catalog.
- iOS publishes one replaceable metadata snapshot plus one replaceable
  immediate-request/result record family to the existing App Group boundary.
- The keyboard bridge has one extension writer for requests and one containing
  app writer for results, with opaque IDs, revision, expiry, and no append-only
  log.
- The iOS app processes keyboard Fixes through the existing bounded app-owned
  handoff runtime; it does not share its Keychain item or provider client.

## Verification Mapping

- Domain and persistence tests cover initial defaults, CRUD, ordering,
  validation, corruption, migration, byte bounds, and redaction.
- Provider tests cover exact prompt/source projection, typed action routing,
  exact custom output, timeout, cancellation, empty output, late response, and
  no live calls.
- macOS tests and runtime QA cover shortcut registration, AX selection and
  complete-field capture, stale targets, palette interaction, replacement,
  Undo, multiple monitors, secure fields, and representative host apps.
- iOS Voice tests cover Unicode selections, complete Draft, stale edits,
  single-action ownership, exact range splice, and Undo.
- Keyboard tests cover metadata projection, selected text, complete-field
  traversal gate, document changes, Full Access, expiry, exactly-once
  replacement, extension recreation, secure/restricted hosts, and no leakage.
- Simulator proves presentation and extension integration. A signed physical
  iPhone is required for host-field traversal, focus continuity, Full Access,
  background app processing, and real replacement qualification.

## Release Gate

Keyboard Fixes may ship for selected text after the signed-device path proves
target continuity and app-mediated processing. The first release does not run
a keyboard Fix without a selection. A later complete-field path requires a new
spec change backed by public-API proof of complete traversal and exact
replacement; it does not block macOS or iOS Voice.
