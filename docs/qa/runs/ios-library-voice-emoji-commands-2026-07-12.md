# iOS Voice Emoji Commands QA

Date: 2026-07-12
Milestone: P3.5B native Voice Emoji Commands Library route

## Scope

- Replace the inert Library summary with a native Voice Emoji Commands route on
  iPhone and iPad.
- Preserve the existing global on/off preference, one selected built-in set,
  the six-language app-owned catalog, and all UUID-based custom commands.
- Add searchable built-in browsing, app-owned detail routes, custom Add/Edit,
  row enable toggles, and confirmed full-row deletion.
- Keep raw editor drafts scene-local while applying every durable change through
  the process-owned typed Library transaction boundary.
- Keep the catalog, custom output, spoken phrases, aliases, routes, drafts, and
  persistence completely outside the keyboard extension and App Group.

## Automated Evidence

- Final focused concurrency and shell run
  - Result: 16 passed, 0 failed, 0 skipped on iPhone 16 / iOS 18.1; result
    bundle `/tmp/holdtype-p35b-focused-final8.xcresult`.
- Focused editor, reducer, persistence, route, privacy, and redaction runs
  - Result: 23 editor/reducer tests passed in
    `/tmp/holdtype-p35b-isolation-tests.xcresult`.
  - `IOSLibraryRepositoryTests`: 29 passed, including preservation of readable
    legacy semantic-collision rows.
- Full signed simulator regression for `HoldType-iOS`
  - Result: 1,385 passed, 0 failed, 0 skipped on iPhone 16 / iOS 18.1; result
    bundle `/tmp/holdtype-p35b-full-ios.xcresult`.
- Full macOS regression for `HoldType`
  - Result: 441 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p35b-full-mac.xcresult`.
- Release builds
  - `HoldType-iOS` and `HoldType` both succeeded with code signing disabled;
    build logs are `/tmp/holdtype-p35b-release-ios-final.log` and
    `/tmp/holdtype-p35b-release-mac.log`.
- Release keyboard executable inspection
  - The extension source and link lists still contain only
    `KeyboardViewController.swift` and `KeyboardBridge.swift`.
  - The target has no package dependency or embedded framework. `otool`,
    demangled symbols, strings, and byte-level searches found no Domain,
    Persistence, OpenAI, IOSCore, Library, emoji editor, repository path, or
    representative catalog content in `HoldTypeKeyboard.appex`.
  - `RequestsOpenAccess` remains false.
- `git diff --check`
  - Result: passed.

No verification contacted OpenAI, used a real API key, requested microphone
access, read or wrote Keychain items, touched the clipboard, or enabled keyboard
Full Access.

## Product And Concurrency Contract

- The native list exposes one global replacement toggle, a dedicated Active Set
  selector, a searchable built-in catalog, and custom commands that remain
  visible regardless of the selected built-in language.
- Built-in routes contain only validated app-owned set and command identifiers.
  New and existing custom routes contain only UUIDs.
- Custom drafts retain raw output, primary phrase, and one-alias-per-line text
  until explicit Save. A blank output or primary phrase is invalid; an alias
  cannot silently become the primary phrase.
- Custom/custom primary and alias collisions use the same punctuation, case,
  and diacritic normalization as runtime replacement. Custom/built-in overlap is
  allowed. Readable legacy collisions remain visible and round-trip unchanged.
- Add retains one UUID across failure and retry. Edit and Delete use full-row
  compare-and-swap; row enable uses UUID plus expected Boolean state.
- Clean editors adopt newer durable truth. Dirty editors retain their draft and
  require Reload Latest or separately confirmed Replace Latest. The session
  compares the transaction-returned row with the current process-owner row;
  a newer field publication remains authoritative and cannot be overwritten by
  an older completion. A concurrent enabled-only publication can merge because
  it does not replace draft-owned fields.
- `Changed Elsewhere` updates the editor baseline to current durable truth while
  retaining the local draft. Repeated observation cannot clear that warning or
  bypass Replace Latest while the draft remains dirty.
- Unresolved explicit Save or Delete keeps the active route in place, hides
  local Back where required, and blocks iPhone-tab or iPad-sidebar switching
  with the content-free wait alert. The blocker clears on success or failure.

## Runtime Evidence

- XcodeBuildMCP built, installed, launched, and exercised the app with
  `HOLDTYPE_AUTOMATION=1`; the automation credential boundary stayed active.
- iPhone flow:
  - Active Set changed to Russian and the catalog immediately showed the
    21-command Russian set.
  - A custom command with output, primary phrase, and alias triggered the global
    dirty-navigation guard. Keep Editing retained the exact draft.
  - Save dismissed the new editor and published the row. Its enable toggle used
    a phrase-readable VoiceOver label while its accessibility identifier stayed
    UUID-only.
  - Force stop and relaunch preserved Russian, the custom count, and the row's
    disabled state. Editing then saved in place, and confirmed Delete removed
    only that row.
  - A later global off/on mutation preserved the selected set and all other
    configuration.
- iPad split flow:
  - Library opened the same Voice Emoji Commands route in the regular-width
    sidebar/detail shell. The global toggle, Active Set, catalog, and Add route
    used native grouped-list geometry.
  - A new custom output draft blocked a History sidebar request behind the
    global discard decision. Confirmed discard cleared only the active Library
    route and entered History.
- The approved containing-app reference and current iPhone screenshot were
  inspected in one same-height comparison canvas. Navigation, grouped cards,
  typography hierarchy, spacing, system controls, tab chrome, and safe areas
  remain consistent; no cropped controls or replacement visual system appeared.

## Storage, Privacy, And Accessibility

- A real global-toggle off/on mutation was bracketed by App Group inventory and
  SHA-256 checks. Before, between, and after, the only file was the same
  container metadata plist with hash
  `3c311a71e3ab2b1385d4935d2ee3bc21a575d49e8844155b3d229a21ac4a1035`.
- The canonical `ios-library.json` was present only beneath the containing
  app's private `Library/Application Support/HoldType` directory. No Library
  file appeared in the App Group.
- Captured app and OS logs contained none of `QA-OUTPUT`, `qa command`,
  `qa alias`, or `IPAD-DRAFT-OUTPUT`.
- Draft, session, save request, full-row reference, notice, route, row, view,
  and Library-summary reflection surfaces have empty custom mirrors or redacted
  descriptions. A canary-backed test covers the summary view that retains full
  Library content for rendering.
- Visible output and spoken phrases remain accessible to VoiceOver. Navigation
  identity, identifiers, notices, confirmations, and announcements remain
  content-free except for intentionally visible row labels.

## Review Assessment

Independent architecture, privacy, and UX reviews were repeated after fixes.
They verified legacy-row preservation, transaction/current three-way
reconciliation, retry UUID stability, delete serialization, persistent failure
truth, full navigation blocking, view reflection redaction, selected-set
accessibility, arbitrary-output layout, and unchanged Release keyboard
isolation. No substantial finding remains.

## Assessment

P3.5B passes. HoldType now has a complete native Voice Emoji Commands Library
experience on iPhone and iPad without widening the keyboard or shared-storage
boundary. P3.5C Replacement Rules is the next and final P3 Library checkpoint.
