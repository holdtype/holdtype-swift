# iOS Containing-App State Owners QA

Date: 2026-07-12
Milestone: P3.1 composition-owned Settings and Library state

## Scope

- Construct exactly one app-private Settings state owner and one Library state
  owner after the canonical storage root resolves.
- Share those exact owner identities across every containing-app scene and with
  failed-History Retry.
- Keep construction passive and expose explicit load, default, read/decode
  failure, save failure, canonical commit, and rollback behavior before any P3
  editor is shown.
- Serialize the complete load or read-modify-save transaction across repository
  suspension and publish observable state before the FIFO lease is released.
- Preserve the containing-app-only public boundary, redacted diagnostics, the
  keyboard extension binary boundary, and all macOS behavior.

## Automated Evidence

- `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test
  --package-path Packages/HoldTypePersistence --no-parallel --quiet
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 911 tests in 48 suites.
- `swift build --package-path Packages/HoldTypePersistence -c release
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed.
- `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=1 swift test
  --package-path Packages/HoldTypeIOSCore --no-parallel --quiet
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 51 tests in 5 suites.
- `swift build --package-path Packages/HoldTypeIOSCore -c release
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed.
- Focused composition, state-owner, and failed-History integration tests
  - Result: 16 passed in 3 suites; result bundle
    `/tmp/holdtype-p31-focused8.xcresult`.
  - The independently requested first-commit/second-commit handshake regression
    passed again after its final deterministic fixture revision; result bundle
    `/tmp/holdtype-p31-publication2.xcresult`.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS -destination
  'platform=iOS Simulator,name=iPhone 16,OS=18.6' test`
  - Result: 1,314 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p31-final2-ios.xcresult`.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: 441 passed, 0 failed, 0 skipped; result bundle
    `/tmp/holdtype-p31-final-mac.xcresult`.
- Release Xcode builds for `HoldType-iOS` on the generic iOS Simulator and
  `HoldType` on macOS
  - Result: passed.
- Direct ordinary-public symbol graph extraction for `HoldTypePersistence` and
  `HoldTypeIOSCore`
  - Result: passed. `IOSLibraryRepository.save` publicly returns its exact
    canonical committed runtime value. The state owners remain app-target
    internal. The failed-History surface still has no ordinary public
    constructor, Settings/Library loaders, Retry factory, provider, or scratch
    capability.
- `otool -L`, `nm -gU`, and `strings` on the simulator keyboard executable and
  debug dylib
  - Result: no Domain, Persistence, IOSCore, OpenAI, Settings, Library,
    state-owner, failed-History, or Keychain dependency, symbol, or string
    entered the extension.
- `git diff --check`
  - Result: passed.

No verification command contacted OpenAI, loaded a live API key, or used a live
credential provider.

## Verified State Contract

- Composition constructs both owners only after the canonical Application
  Support root resolves and before the failed-History service. Root failure
  leaves both unavailable. Credential failure does not discard them.
- Construction creates no Settings or Library file, performs no repository
  load or save, reads no Keychain item, and contacts no provider.
- Each `@MainActor @Observable` owner exposes only `notLoaded`, `ready(value)`,
  `loadFailed`, or `saveFailed(lastDurableValue)`. A missing file resolves to
  complete defaults without writing; corrupt or unreadable input never becomes
  optimistic defaults.
- One explicit FIFO gate covers the complete load, semantic mutation, canonical
  save, and provider snapshot. Cancellation before lease acquisition performs
  no I/O. Once acquired, a local commit finishes truthfully even if its caller
  is cancelled.
- The observable snapshot is delivered on `MainActor` while the transaction
  still owns its lease. A deterministic two-semaphore test blocks MainActor
  after the first suspended commit resumes and proves that the queued second
  commit cannot start before publication.
- A candidate is never published before save succeeds. Library save returns the
  exact normalized value encoded during that same commit; the regression
  fixture proves the raw custom-command candidate differs from the committed
  value. Failed saves discard the candidate and retain the last durable value.
- Scene code receives semantic read-modify-save closures rather than a stale
  whole-value replacement API.

## Verified Retry And Ownership Graph

- Two separately constructed scenes retain the exact same Settings and Library
  owner references from the process composition.
- The failed-History service resolves Settings and Library through closures
  bound to those same owners. It no longer constructs repositories from a root
  URL.
- The Retry integration fixture deliberately leaves stale Settings and Library
  bytes on disk while the in-memory owners contain newer values. The provider
  receives only the owner-current model, language, and dictionary, proving a
  regression to duplicate root-based repositories would fail.
- Retry waits behind an in-flight owner mutation. It sees the newly durable
  value after success and the previous durable value after failure. A Settings
  or Library load failure stops before credential resolution or provider work.

## Privacy And Isolation

- Settings, Library, state snapshots, state-owner errors, and owner objects use
  redacted description, debug description, and reflection surfaces. Test
  canaries prove prompts and Library content are absent.
- Runtime values remain app-private, non-Codable values; redaction does not
  replace values needed by containing-app editors or provider composition.
- No Settings or Library content, secret, History record, or state-owner object
  enters App Group or the keyboard target.

## Independent Review Fixes

Independent concurrency, contract/privacy, and test/spec reviews found and
verified fixes for:

- observable state initially being published after FIFO lease release, which
  could let an older MainActor continuation visually overwrite newer state;
- the first canonical Library test normalizing its candidate before the fake
  commit and therefore not proving that the commit return was authoritative;
- the first Retry integration fixture writing owner-current values to the same
  disk files, which did not exclude a duplicate repository regression;
- an obsolete spec paragraph that still described failed-History as the owner
  of Settings and Library repositories;
- a timing-only publication regression test, replaced with explicit first-
  commit-resumed and second-commit-started handshakes.

The repeated final concurrency and contract reviews reported no remaining P1
or P2 finding.

## Physical-Device Gates

Simulator evidence cannot establish effective Complete Data Protection while a
signed device is locked. Signed multi-scene restoration and eventual editor
behavior on physical iPhone and iPad remain P3 device/UI gates; this checkpoint
does not claim those later surfaces are complete.

## Verdict

P3.1 passed. The containing app now has one truthful, composition-owned,
observable Settings transaction boundary and one Library transaction boundary,
shared with every scene and failed-History Retry. The next P3 checkpoint is the
native iPhone/iPad shell and navigation, followed by editors built directly on
these owners.
