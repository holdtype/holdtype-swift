# iOS Brand Stage Keyboard QA

Date: 2026-07-13; restricted-access correction verified 2026-07-14

Scope: production Brand Stage composition, concise status contract, Latest-only
shared cache, and containing-app History route.

## Result

The keyboard matches the approved Option 2 hierarchy in iPhone and iPad Light
and Dark appearances. It contains only controls and state: no transcript,
History row, card, preview, or QWERTY layout is rendered inside the extension.

The centered label is intentionally limited to:

- `Ready` when the local keyboard controls are usable;
- `Open failed` briefly after an unsuccessful History request.

It does not show action narration such as `Latest ready`, `Inserted`, or
`Opening History`. Latest availability is represented by the Latest button.

## Visual Evidence

Approved source:

![Approved Option 2 reference](../../../output/imagegen/ios-keyboard-redesign/approved-option-2-reference.png)

| Device | Light | Dark |
| --- | --- | --- |
| iPhone 16, iOS 18.6 | [Screenshot](assets/ios-brand-stage-keyboard-2026-07-13/iphone-light.png) | [Screenshot](assets/ios-brand-stage-keyboard-2026-07-13/iphone-dark.png) |
| iPad Pro 11-inch, iOS 26.0 | [Screenshot](assets/ios-brand-stage-keyboard-2026-07-13/ipad-light.png) | [Screenshot](assets/ios-brand-stage-keyboard-2026-07-13/ipad-dark.png) |

The four captures verify geometry and theme adaptation. They predate the
2026-07-14 restricted-access correction and must not be used as current status
copy evidence. They verify:

- equal History and Latest geometry;
- a centered transparent HoldType mark with no square background;
- one-line compact status text;
- distinct keyboard and host-app surfaces;
- unchanged hierarchy and geometry between appearances;
- bounded iPad content width instead of stretched controls.

## History Route Evidence

The containing app registers the strict `holdtype://history` route. Opening it
with `simctl openurl` selected the real History destination:

![Containing app History route](assets/ios-brand-stage-keyboard-2026-07-13/history-route.png)

This proves app-side route registration and navigation only. A real History tap
from the keyboard called public `NSExtensionContext.open`; iOS 18.6 Simulator
returned `false`, and the keyboard displayed the required compact failure:

![Keyboard History launch failure](assets/ios-brand-stage-keyboard-2026-07-13/history-launch-failed.png)

No private responder-chain or `UIApplication` workaround is present. Direct
keyboard-to-app launch therefore remains a signed-device and review gate rather
than a release claim. [Apple App Review Guideline 4.4.1](https://developer.apple.com/app-store/review/guidelines/)
also says keyboard extensions must not launch apps other than Settings.

## Shared Cache Boundary

- The snapshot contains schema/revision metadata and at most one Latest item.
- Production publication is enabled. The containing app is the only writer and
  the keyboard is read-only.
- `RequestsOpenAccess` is false. Apple documents read-only access to the
  containing app's shared containers in the restricted keyboard sandbox, so
  Latest is not gated by `hasFullAccess` and HoldType requests no Full Access.
- An already-expired Latest result is omitted instead of copying its text into
  App Group storage.
- App startup atomically replaces legacy schema 1/2 payloads with an empty
  schema 3 snapshot.
- History, recent-result arrays, settings, prompts, audio, provider payloads,
  and credentials never enter this snapshot.

## Automated Evidence

- Full `HoldType-iOS` iPhone Simulator test run: 1,006 passed, 0 failed,
  0 skipped.
- Focused bridge, publisher, command-surface, plist, and composition run on
  iPhone 17 / iOS 26.5: 30 passed, 0 failed.
- `HoldType-iOS` generic Simulator Release build: passed.
- `HoldType` macOS build: passed.
- `git diff --check`: passed.

All automated launches used the sanitized UI-test environment. No live
Keychain prompt, microphone capture, or OpenAI request was used.

## Remaining Gate

A signed physical iPhone still must verify matching App Group signing,
restricted-mode Latest reading and insertion, host-app fallbacks, and process
eviction. Compact-landscape and accessibility-setting captures also remain.

The public History-launch result remains a separate technical observation and
review gate. Apple documents `NSExtensionContext.open` support on iOS for Today
and iMessage, not custom keyboards, and Guideline 4.4.1 forbids keyboard
extensions from launching apps other than Settings. A simulator or device
success therefore cannot qualify History or voice handoff as App-Review-safe.
