# iOS Replacement Rules QA

Date: 2026-07-12
Milestone: P3.5C native Replacement Rules Library route

## Scope

- Replace the inert Library summary with a native Replacement Rules route on
  iPhone and iPad.
- Preserve ordered, UUID-based rules with raw multiline Search and Replacement
  values, duplicate Search values, enabled state, and empty Replacement
  semantics.
- Add native search, Add/Edit, row enable toggles, native and VoiceOver reorder,
  explicit Save, confirmed deletion, and truthful concurrent-change recovery.
- Keep drafts scene-local while applying every durable mutation through the
  process-owned typed Library transaction boundary.
- Keep replacement content, routes, drafts, persistence, and processing outside
  the keyboard extension and App Group.

## Automated Evidence

- Final focused editor, reducer, persistence, route, and exact-input run
  - Result: 43 passed, 0 failed, 0 skipped on iPhone 16 / iOS 18.1; result
    bundle
    `~/Library/Developer/XcodeBuildMCP/workspaces/holdtype-swift-bde3b777455d/result-bundles/test_sim_2026-07-12T16-11-12-657Z_pid65444_154513ab.xcresult`.
- Full signed simulator regression for `HoldType-iOS`
  - Result: 1,401 passed, 0 failed, 0 skipped on iPhone 16 / iOS 18.1; result
    bundle
    `~/Library/Developer/XcodeBuildMCP/workspaces/holdtype-swift-bde3b777455d/result-bundles/test_sim_2026-07-12T16-11-33-023Z_pid65444_33604651.xcresult`.
- Full macOS regression for `HoldType`
  - Result: 441 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p35c-full-mac-final2.xcresult` and log
    `/tmp/holdtype-p35c-full-mac-final2.log`.
- Release builds
  - The final iOS Release build succeeded at
    `/tmp/holdtype-release-ios-isolation-ultimate-20260712`; its log is
    `/tmp/holdtype-release-ios-isolation-ultimate-20260712.log`.
  - The macOS Release build succeeded at
    `/tmp/holdtype-release-macos-final-20260712`; its log is
    `/tmp/holdtype-release-macos-final-20260712.log`.
- Release keyboard executable inspection
  - The extension compile and link inputs still contain only
    `KeyboardViewController.swift`, `KeyboardBridge.swift`, and their two object
    files. The extension contains no package dependency or embedded framework.
  - `otool`, symbols, strings, and byte-level searches found no Domain,
    Persistence, IOSCore, Library, Replacement Rules, exact-input, Dictionary,
    Voice Emoji Commands, or representative QA canary content in the extension.
  - The standalone and containing-app-embedded extension executables are
    identical with SHA-256
    `a50246a4641889c84746ee12fa550f2636abd8992d06b156667a5547ce8f5282`.
  - `RequestsOpenAccess` remains false.
- `git diff --check`
  - Result: passed.

No verification contacted OpenAI, used a real API key, requested microphone
access, read or wrote Keychain items, touched the clipboard, or enabled keyboard
Full Access.

## Product And Concurrency Contract

- The native list exposes exact status priority: an empty or whitespace-only
  Search is Inactive, otherwise a disabled rule is Off, otherwise it is Active.
  The Library summary reports `0 rules` or `N rules · M active`.
- Search is ephemeral, trimmed, and case-insensitive over the raw Search and
  Replacement fields. Reordering is unavailable while filtering so the visible
  subset cannot publish an ambiguous durable order.
- A new rule requires a non-whitespace Search, receives one retry-stable UUID,
  and is appended enabled. Existing legacy rules with an empty Search remain
  visible, editable, reorderable, and inactive. Duplicate Search values are
  valid and execute in durable order.
- Empty Replacement removes matching text. A whitespace-only Replacement is a
  distinct exact value. Multiline content, leading and trailing whitespace, and
  the final UIKit text value are persisted without HoldType normalization.
- Per-field smart quotes, smart dashes, autocorrection, spellchecking, inline
  prediction, math completion, and Writing Tools are disabled. System-wide
  keyboard shortcuts that UIKit does not expose per field remain OS-owned; the
  app stores their resulting string unchanged.
- Add retains one UUID across failure and retry. Edit and Delete use full-row
  compare-and-swap; row enable merges only the expected Boolean state. Reorder
  publishes the complete expected and desired UUID arrays while preserving the
  latest raw row fields.
- Clean editors adopt newer durable truth. Dirty editors retain their draft and
  require Reload Latest or separately confirmed Replace Latest. A concurrent
  enabled-only publication can merge because it does not replace draft-owned
  fields. A deleted rule cannot be recreated through the stale edit route.
- Optimistic reorder stores UUIDs only and rolls back to canonical owner truth
  on failure. Add UUID collision fails closed rather than exposing edit-only
  recovery actions for a row that was never created.
- Unresolved explicit Save or Delete blocks destination replacement. The
  containing app resigns active text input before showing a blocking decision so
  the complete prompt remains reachable above software and custom keyboards.

## Runtime Evidence

- XcodeBuildMCP built, installed, launched, and exercised the app with
  `HOLDTYPE_AUTOMATION=1`; the automation credential boundary stayed active.
- iPhone flow:
  - Add preserved an empty Replacement as the documented remove-text action.
    A dirty History-tab request showed the global guard; Keep Editing retained
    the draft, and explicit Save dismissed only the new editor.
  - Duplicate Search values were accepted. Editing an existing rule saved in
    place. A whitespace-only Search remained visible as Inactive, and disabling
    a valid row showed Off without duplicating status semantics.
  - Search over Replacement filtered the list and hid Edit/reorder. Native Edit
    mode exposed two reorder controls for two rows and exited safely when an
    externally published deletion made reorder unavailable.
  - Force stop and relaunch preserved the exact two-rule order and enabled
    states. Maximum Dynamic Type in dark appearance kept all rows, statuses, and
    actions reachable by scrolling; the simulator was restored afterward.
  - Straight quotes, double dashes, leading spaces, an actual newline, and the
    final UIKit text value round-tripped through the exact multiline editor.
- iPad split flow:
  - Replacement Rules used the same native grouped route in the regular-width
    sidebar/detail shell.
  - A dirty new-rule draft blocked a History sidebar request. The software or
    custom keyboard resigned before the confirmation appeared, leaving the full
    prompt and both decisions visible; confirmed discard entered History.
- Accessibility inspection of the two-row iPhone list found UUID-only row
  identifiers and focusable row actions: the first row exposed `Move Down` and
  `Delete Rule`; the second exposed `Move Up` and `Delete Rule`. The system HID
  bridge cannot synthesize a continuous native reorder drag, so runtime drag
  evidence is represented by these accessibility actions plus reducer and
  persistence tests rather than a simulator-only physical-drag claim.
- The approved containing-app reference and current iPhone screenshot were
  inspected together at matching height. Grouped-list geometry, typography,
  system controls, navigation chrome, spacing, safe areas, and the semantic
  Active accent remain consistent; no cropped or replacement visual system was
  introduced. Final iPhone evidence is
  `/tmp/holdtype-p35c-final-iphone.png`.

## Storage, Privacy, And Accessibility

- After all runtime mutations and confirmed deletion of both QA rows, the App
  Group still contained only its metadata plist with unchanged SHA-256
  `3c311a71e3ab2b1385d4935d2ee3bc21a575d49e8844155b3d229a21ac4a1035`.
- The canonical `ios-library.json` was present only beneath the containing
  app's private `Library/Application Support/HoldType` directory. No Library
  file appeared in the App Group.
- Product-process logs contained none of `QA5`, `QA-A11Y-TWO`,
  `P35C-SEARCH-ONE`, `P35C-REPLACE-TWO`, or `P35C-IPAD-DIRTY`.
- Draft, session, save request, pending-order, notice, route, row, view, and
  Library-summary reflection surfaces have empty custom mirrors or redacted
  descriptions. Persisted content appears only where the user intentionally
  views or edits it.
- Exact-input controls follow Dynamic Type, report disabled state, resign focus
  when disabled, and preserve native selection and VoiceOver editing behavior.

## Review Assessment

Independent product-contract, architecture, privacy, accessibility, and visual
reviews were repeated after fixes. They verified add-collision failure,
three-way completion reconciliation, enabled-only merge, external deletion,
edit-mode teardown, focusable VoiceOver reorder actions, disabled exact-input
behavior, raw-text preservation, and unchanged Release keyboard isolation. No
substantial finding remains.

## Assessment

P3.5C passes. HoldType now has complete native Dictionary, Voice Emoji Commands,
and Replacement Rules Library experiences on iPhone and iPad without widening
the keyboard or shared-storage boundary. P3 is complete; P4 app-only foreground
voice is the next checkpoint.
