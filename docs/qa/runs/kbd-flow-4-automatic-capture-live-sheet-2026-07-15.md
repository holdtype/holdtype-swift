# KBD-FLOW-4 Automatic Capture And Live Sheet QA

Date: 2026-07-15

Result: **Passed for the KBD-FLOW-4 implementation checkpoint.** The current
app and embedded keyboard also pass a signed physical-device build. The later
KBD-FLOW-8 signed keyboard-to-app interaction matrix remains mandatory and is
not replaced by Simulator or compositional evidence in this record.

## Scope

- Start the first keyboard attempt automatically from the accepted, fresh
  handoff intent and its selected action.
- Reuse `IOSKeyboardDictationSessionCoordinator` and the one existing
  keyboard Voice workflow instead of adding a recorder or provider owner.
- Present the existing handoff sheet as Starting before recorder
  acknowledgement and Listening only after the workflow reports real capture.
- Keep the keyboard-originated workflow eligible to continue after the app
  backgrounds.
- Make close, failure, expiry, capture end, terminal completion, and
  supersession dismiss the sheet without changing ordinary Voice behavior.

## Implementation Evidence

- `IOSKeyboardHandoffPresentationOwner` owns only accepted-request identity and
  sheet presentation. It contains no setup, recorder, provider, or persistence
  implementation.
- `IOSKeyboardDictationSessionCoordinator.startHandoff` requires an active app,
  a fresh intent, the granted permission resulting from preflight, and a still-
  current generation before it publishes Ready and starts the shared workflow.
- The sheet begins in Starting before asynchronous arming and moves to
  Listening only from `IOSKeyboardDictationWorkflowProgress.listening`. The
  shared Voice workflow emits that progress only after recorder start succeeds,
  `isActive` is true, and the frozen audio input is revalidated.
- Close awaits the shared workflow's cancellation result before presentation
  disappears. A cancellation during asynchronous preparation invalidates that
  generation so a late continuation cannot start capture after dismissal.
- A newer accepted handoff cancels and retires older work before its own attempt
  starts. A stale intent creates no state, attempt, capture, or sheet.
- Normal app launches construct an inactive presentation owner. Ordinary Voice
  buttons continue through `IOSForegroundVoiceController`; this slice does not
  redirect them through the keyboard handoff.

## Focused Simulator Verification

Simulator: iPhone 16 Pro, iOS 18.6
(`AFB49941-79A4-400A-AA0F-9E962155E485`).

Command:

```sh
xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS \
  -destination 'platform=iOS Simulator,id=AFB49941-79A4-400A-AA0F-9E962155E485' \
  test \
  -only-testing:HoldTypeIOSTests/IOSKeyboardDictationSessionCoordinatorTests \
  -only-testing:HoldTypeIOSTests/IOSForegroundVoiceWorkflowTests \
  -only-testing:HoldTypeIOSTests/IOSForegroundVoiceSceneHostOwnerTests \
  -only-testing:HoldTypeIOSTests/IOSContainingAppShellTests \
  -only-testing:HoldTypeIOSTests/IOSKeyboardHandoffSheetTests \
  -only-testing:HoldTypeIOSTests/IOSKeyboardHandoffLaunchRouterTests
```

Result: **100 tests in 6 suites passed.** The matrix includes:

- one fresh intent starts one matching attempt with the frozen action;
- Starting does not claim Listening;
- real workflow recorder acknowledgement is the only Listening transition;
- capture end and terminal outcomes dismiss the sheet;
- close waits for capture cancellation;
- close during arming rejects the late preparation result;
- failure, expiry, stale intent, and supersession are terminal;
- keyboard and ordinary foreground starts cannot create a second recorder;
- repeated launch routing remains accepted at most once;
- the preflight, sheet, and ordinary Voice workflow suites remain green.

The iOS Simulator Debug product also built successfully before the test pass.

## Signed Physical-Device Build Boundary

Connected device:

- Evgeny’s iPhone, iPhone 14 Pro Max (`iPhone15,3`);
- iOS 26.5.2 (`23F84`);
- UDID `00008120-001A19991E7BC01E`;
- development team `PUA6HH22D7`.

Command:

```sh
xcodebuild -project HoldType.xcodeproj -scheme HoldType-iOS \
  -configuration Debug \
  -destination 'id=00008120-001A19991E7BC01E' \
  DEVELOPMENT_TEAM=PUA6HH22D7 CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates build
```

Result: **BUILD SUCCEEDED** for the current KBD-FLOW-4 sources.

Signed-product inspection confirmed:

- containing app `app.holdtype.HoldType.ios` and extension
  `app.holdtype.HoldType.ios.keyboard` use the same team;
- both signed products contain only the matching App Group
  `group.app.holdtype.HoldType.shared` for this bridge;
- the containing app owns the microphone purpose string;
- the keyboard declares `RequestsOpenAccess = true` and has no recorder owner.

This signed build proves current compilation, embedding, provisioning, and
entitlement compatibility on the connected iPhone. It does not claim that a
full physical keyboard tap, app switch, live capture, swipe-back, and recreated
extension were executed in this checkpoint. That indivisible runtime proof is
kept in KBD-FLOW-8, as required by the repository device-evidence boundary.

## Regression And Hygiene

The macOS baseline command also passed:

```sh
xcodebuild -project HoldType.xcodeproj -scheme HoldType \
  -destination 'platform=macOS' build
```

`git diff --check` passes. No live OpenAI request was used. The run-owned
`caffeinate` guard was bounded to the Simulator/device qualification session.
