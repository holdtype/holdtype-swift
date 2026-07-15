# KBD-FLOW-8 Signed-Device Qualification — 2026-07-15

Status: **In progress.** Signed build, product inspection, and installation
passed. Runtime launch and the physical keyboard/host matrix remain pending
because the connected iPhone was locked.

## Device And Build

- Source checkpoint: `0d1368d` (`Remove legacy keyboard recovery surfaces`)
- Device: Evgeny’s iPhone, iPhone 14 Pro Max (`iPhone15,3`)
- iOS: 26.5.2 (`23F84`)
- UDID: `00008120-001A19991E7BC01E`
- CoreDevice identifier: `DE70161A-3200-5D58-BF1E-DEA8B56FABC2`
- Development team: `PUA6HH22D7`
- Build result: `HoldType-iOS` Debug device build succeeded
- Installation result: app and embedded keyboard installed successfully

The build command selected only the `HoldType-iOS` scheme and physical iPhone
destination. It did not build or test the macOS app.

## Signed Product Inspection

- Containing app bundle: `app.holdtype.HoldType.ios`
- Keyboard bundle: `app.holdtype.HoldType.ios.keyboard`
- Both products are signed by the same development team.
- Both products contain the matching App Group
  `group.app.holdtype.HoldType.shared`.
- The containing app contains the microphone purpose string.
- The keyboard declares `RequestsOpenAccess = true`.
- Embedded-binary validation passed during the signed build.

## Runtime Boundary

CoreDevice installed the app, then rejected the launch because the physical
iPhone was locked:

```text
RequestDenied: Unable to launch app.holdtype.HoldType.ios because the device
was not, or could not be, unlocked.
```

Unlocking the physical phone is not available to Mac automation. No runtime
state, microphone lifecycle, swipe-back behavior, host-field insertion, or
TestFlight result is claimed from this attempt.

## Remaining Matrix

After the phone is unlocked, resume from app launch and run the KBD-FLOW-8
physical matrix in the plan. In particular, do not substitute iPhone Mirroring
for custom-keyboard interaction: Mirroring is only a containing-app inspection
surface and may suppress the onscreen iPhone keyboard.

## Scope Boundary

- No macOS source, test, package, or build was touched.
- The unrelated working-tree change in
  `HoldType.xcodeproj/project.pbxproj` remains excluded.
- KBD-FLOW-8 and the overall goal remain incomplete.
