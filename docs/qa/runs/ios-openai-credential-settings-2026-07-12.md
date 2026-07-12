# iOS OpenAI Credential Settings QA

Date: 2026-07-12
Milestone: P3.3 native containing-app OpenAI credential editor

## Scope

- Add a native Settings detail for the containing app's single OpenAI API-key
  item without exposing the credential coordinator or Keychain adapter to
  SwiftUI.
- Preserve passive launch and Settings-root behavior: marker-only detail
  presentation, one payload-free status stream, and no Keychain or clipboard
  read before an explicit action.
- Support manual Done/focus-loss commit, explicit Paste and Save, explicit
  Check Saved Key, confirmed removal, exact six-state presentation, partial
  success, and redacted failures.
- Keep one scene-local, memory-only secure draft across transient navigation
  after a failed save. Never place it in the process owner, `SceneStorage`,
  app settings, App Group, diagnostics, or durable navigation.
- Disable all Security item access before production composition construction
  in repository automation and XCTest host processes.

## Automated Evidence

- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,id=B12CCB99-5B3D-49A5-8CF2-7976C570D2EB'
  test -only-testing:HoldTypeIOSTests/IOSOpenAICredentialSettingsStateOwnerTests`
  - Result: 17 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p33-owner-final4.xcresult`.
- Focused composition, shell, and credential-owner run
  - Result: 27 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p33-owner-final6.xcresult`.
- `swift test --package-path Packages/HoldTypeIOSCore --filter
  IOSOpenAICredentialCoordinatorTests`
  - Result: 32 passed in one suite. This includes ordered payload-free status
    updates, sticky failed-reconciliation truth, exact resolution/stream
    identity, and public diagnostic redaction.
- `swift test --package-path Packages/HoldTypePersistence --filter
  OpenAIAPIKeyKeychainStorageTests`
  - Result: 18 passed in one suite. Disabled automation mode fails load,
    save/replace, and remove through a private no-op client and contains no
    `SecItemAdd`, `SecItemUpdate`, `SecItemCopyMatching`, or `SecItemDelete`
    call path.
- Full signed simulator regression for `HoldType-iOS`
  - Result: 1,341 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p33-final2-ios.xcresult`.
- Full macOS regression for `HoldType`
  - Result: 441 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p33-final2-mac.xcresult`.
- Sequential Release builds for `HoldType-iOS` on the generic iOS Simulator
  and `HoldType` on macOS
  - Result: passed.
- `otool -L`, `nm -gU`, and `strings` on the Release simulator keyboard
  executable
  - Result: only system frameworks are linked. No Domain, Persistence,
    IOSCore, OpenAI, Keychain, containing-app composition, credential-owner,
    Settings-owner, or Library-owner dependency, symbol, or string entered the
    extension.
- `git diff --check`
  - Result: passed.

No final verification command contacted OpenAI or used a real API key.

## Ownership And Secret Boundary

- Composition creates exactly one credential coordinator and exactly one
  credential presentation owner. All production client closures capture that
  coordinator identity. SwiftUI receives only the exact Settings, Library,
  and credential presentation owners plus payload-free provider availability.
- The presentation owner stores only a closed operation, notice/failure, and
  `IOSOpenAICredentialStatusUpdate`. It does not retain API-key candidates,
  clipboard values, resolved credentials, generations, arbitrary `Error`
  values, provider requests, or Keychain adapters.
- The API-key draft is a redacted value in one shell scene's ephemeral
  `@State`. The editor receives a `Binding`, so Back or a top-level destination
  change cannot discard the only retry copy after an asynchronous failure.
  Successful save or removal clears it. Dump, description, reflection, and
  nested editor-view reflection tests contain no sentinel secret.
- One focus-session token makes Done plus the resulting focus loss a single
  manual commit. Paste and Remove suppress focus-loss commit before changing
  focus. Typing alone performs no credential operation.
- Each OpenAI detail appearance reads only the non-secret marker. The
  clipboard closure is invoked only by the explicit Paste action. Explicit
  Settings refresh is the only detail action that resolves Keychain truth.

## Status Ordering And Failure Truth

- The coordinator status stream contains only status plus a monotonically
  increasing process-local revision. It has no credential, key identity, or
  generation and uses latest-value buffering.
- Save, remove, explicit resolution, voice preflight, and provider rejection
  publish process truth. An older passive/action snapshot cannot overwrite a
  newer observed revision, including when the event arrives while a UI action
  is suspended.
- A failed marker reconciliation remains a supplementary process-local issue
  across passive reads, fresh subscriptions, and provider rejection. Only a
  later successful reconciliation or credential mutation proves recovery and
  clears it. Explicit resolution returns and streams one exact revisioned
  update rather than allowing the UI client to reconstruct a weaker status.
- A failed explicit Keychain check remains visible even when an older runtime
  credential still makes the primary state `available in this process`.
  Locked or unreadable Keychain failures are not cleared by a cache-only voice
  event; a new explicit Settings action is required to establish new Keychain
  truth.
- Same-status events preserve still-relevant failed replacement errors.
  Contradictory provider/status failures clear only when a newer payload-free
  state actually makes them obsolete.

## Runtime And Visual Evidence

- XcodeBuildMCP built, installed, and launched the screen with repository
  automation enabled. The final run used the disabled Keychain client before
  coordinator construction. A deliberately non-secret candidate failed
  locally, remained masked after Back and re-entry, and kept the visible fixed
  Keychain failure without reading or changing an existing item.
- A pre-fix simulator probe exposed that the iOS production graph had not yet
  honored the automation environment. That gap was corrected before this
  checkpoint; the final run above and the package tests cover the corrected
  boundary.
- iPhone normal and dark appearances, iPhone accessibility-large Dynamic Type,
  and iPad split presentation were inspected. Native grouped sections,
  scrolling, wrapped labels, destructive confirmation, disabled/busy states,
  and tab/sidebar navigation remained usable. The simulator was returned to
  medium text size and light appearance.
- VoiceOver-facing controls have stable identifiers. Notices and failures post
  announcements, the secure field is privacy-sensitive, and the saved-key mask
  exposes presence rather than bullet count as its accessibility value.
- The selected Product Design `Guided Utility` direction remains the visual
  reference: system typography, grouped hierarchy, SF Symbols, semantic
  colors, and no invented logo or decorative asset.

## Review Assessment

Successive read-only security reviews found and drove fixes for duplicate
Done/focus commit, stale status ordering, whole-composition access, busy-event
loss, same-status failure clearing, explicit-refresh cache ambiguity, and
failed-navigation draft loss. Final architecture, security/privacy, and
UX/accessibility reviews were repeated against the corrected diff before the
checkpoint commit; no unresolved P1/P2 finding is accepted into the next P3
slice.

## Assessment

P3.3 passes. The containing app now has a native, truthful, recoverable OpenAI
credential editor with app-only Keychain ownership, conservative status
semantics, scene-local secret handling, automation-safe Security isolation,
and unchanged keyboard-extension boundaries. The next P3 checkpoint can add
the remaining P4-owned non-secret Settings editors without reopening this
credential contract.
