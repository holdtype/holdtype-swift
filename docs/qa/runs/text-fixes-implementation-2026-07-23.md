# Text Fixes Implementation QA

Date: 2026-07-23

Scope: HoldType Text Fixes implementation from shared catalog and provider
through the macOS, iOS Voice, iOS editor, and keyboard-extension surfaces.

Contract:

- `docs/specs/features/text-fixes.md`
- the active platform specs referenced by
  `docs/text-fixes-implementation-plan.md`
- global macOS invocation is `Option+J`

## Result

Implementation and automated qualification passed. Simulator runtime
qualification passed for iOS Voice, the iOS editor, and the actual embedded
HoldType keyboard extension.

Two release-qualification gates remain:

1. the representative macOS live-host matrix;
2. end-to-end selected-text and Full Access behavior in real host apps on a
   signed physical iPhone.

The paired iPhone was visible to Xcode during this run. Device build settings
could not be resolved because the phone was locked and its Developer Disk Image
was not mounted; the available automation surface also could not operate the
physical keyboard extension or grant Full Access. No manual privacy permission
was silently enabled.

## macOS

Verified:

- the full macOS unit suite passed: **551 passed, 0 failed, 0 skipped**;
- the suite includes `Option+J` registration and presentation, target capture,
  exact-range replacement, stale-target behavior, palette interaction,
  catalog editing, typed/custom execution, and menu presentation;
- the macOS app build passed;
- the app and test bundle were signed with the same repo-configured Apple
  Development identity for the test run.

Result bundle:

`~/Library/Developer/Xcode/DerivedData/HoldType-aiagnlkblhltvacjmbtlpyjistgi/Logs/Test/Test-HoldType-2026.07.23_17-57-24-+0200.xcresult`

Not claimed by this run:

- live replacement behavior across TextEdit, Notes, Safari, Chrome, and Xcode;
- secure/custom-control refusal and one-step host Undo across that matrix;
- multi-monitor and screen-edge placement in live external apps.

An already installed HoldType build owned the global shortcut during the live
macOS session, so the run did not treat that session as isolated acceptance
evidence.

## iOS Voice And Editor

The iPhone 17 Pro Simulator on iOS 26.5 was launched with
`HOLDTYPE_AUTOMATION=1` and sanitized Keychain behavior.

Voice checks:

- seeded a Draft and opened the Fixes surface;
- confirmed all eight default actions, with Translate and Fix first;
- ran Improve Writing through the controlled provider;
- confirmed the transformed Draft;
- used Undo and confirmed exact source restoration;
- confirmed the Fixes launcher remains a one-line accessible control.

Editor checks:

- opened Library and confirmed the separate Text Actions section;
- opened Fixes and confirmed built-ins plus custom defaults;
- exercised search, selection, add, and edit presentation;
- production-client coverage confirmed saved catalog changes refresh both
  Voice and keyboard runtime projections.

The focused iOS feature suite passed:

- **160 passed, 0 failed, 0 skipped**;
- Voice selection/whole-Draft replacement, Unicode ranges, stale-result and
  Undo coverage;
- editor model, presentation, production refresh client, and containing-app
  composition;
- keyboard bridge, TTL, privacy, strict decoding, cancellation, metadata,
  production processor/runtime, launch route, panel, and controller coverage.

Result bundle:

`~/Library/Developer/XcodeBuildMCP/workspaces/holdtype-swift-bde3b777455d/result-bundles/test_sim_2026-07-23T15-53-34-867Z_pid72635_433413b6.xcresult`

The iOS Simulator build also passed.

## Embedded Keyboard Extension

A bounded standalone UIKit host and XCUITest were generated for the run and
removed afterward. The test selected HoldType through the system input
switcher, so the evidence covers the actual embedded keyboard extension rather
than a copied SwiftUI preview.

Observed with Full Access off:

- the center Fixes control exists and has a touch target of at least 44 points;
- Fixes opens the tile workspace;
- the workspace shows the exact privacy state
  “Allow Full Access to use Fixes.”;
- Translate, Improve Writing, Fix, and Make Shorter tiles are visible;
- Quick Insert and Fixes are mutually exclusive in both directions;
- no provider or Keychain request was attempted.

The bounded XCUITest passed: **1 passed, 0 failed**.

Result bundle:

`~/Library/Developer/XcodeBuildMCP/workspaces/holdtype-swift-bde3b777455d/result-bundles/test_sim_2026-07-23T15-52-05-119Z_pid72635_b98a0f0a.xcresult`

![HoldType keyboard Fixes workspace with Full Access off](assets/text-fixes-implementation-2026-07-23/ios-keyboard-fixes-no-full-access.png)

## Shared Packages

Focused package suites passed:

| Package | Coverage | Result |
| --- | --- | --- |
| HoldTypeDomain | Text Fix action, catalog, and request contracts | 16 tests in 2 suites passed |
| HoldTypeOpenAI | generic transformation and cancellation | 12 tests in 2 suites passed |
| HoldTypePersistence | catalog persistence and strict decoding | 14 tests in 3 suites passed |
| HoldTypeIOSCore | Voice Text Fix processing | 4 tests in 1 suite passed |

## Privacy And Safety

- live OpenAI credentials were not used;
- runtime UI used controlled provider behavior;
- Keychain access stayed sanitized during automation;
- Full Access remained off in the Simulator keyboard check;
- source text, prompts, and provider output were not added to normal product
  logs;
- unit coverage exercised TTL, cancellation, stale results, strict decoding,
  metadata-only projection, and exactly-once result claims.

## Remaining Release Qualification

Before claiming the complete acceptance matrix:

1. run `Option+J`, selection, whole-field, stale-target, unsupported/secure,
   focus-loss, Undo, and placement checks in the documented macOS hosts;
2. on the paired signed iPhone, enable HoldType deliberately, exercise Full
   Access off/on, transform selected text in single- and multiline hosts, and
   verify partial/nil/no-selection contexts fail closed;
3. exercise timeout, cancellation, extension eviction/recreation, TTL expiry,
   exactly-once claim, and app cold-state behavior on that device;
4. inspect normal and opt-in debug logs from those live matrices for source,
   prompt, output, and credential leakage.
