# Microphone Devices and Permission

- Node type: leaf
- Contract ID: `holdtype.macos.microphone-input.devices`
- Domain ID: `holdtype.macos.microphone-input`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.microphone-input.devices@1`
- Read when: capture start, input selection, microphone permission, or disconnect behavior is in scope.
- Do not read when: only stopping, finalization, recovery, or output is in scope.
- Maximum size: 100 physical lines.

## Start authority and input selection

- Capture begins only after an explicit user start and after required
  microphone permission is available.
- Skipping a setup permission prompt may dismiss it for the current app run,
  but is not consent and never permits recording while permission is missing.
- A temporary local audio file may be prepared only after permission is allowed.
- Start and stop are available from the menu; the global hotkey may start and
  stop after its own feature is implemented.
- The default input is the current macOS system-default device.
- Settings may pin one available microphone. Each attempt resolves it by stable
  macOS device identity and never silently substitutes the system default or a
  newly connected headset.
- If a pinned device is unavailable at start, HoldType stays out of recording,
  explains that it is disconnected, and lets the user choose another device or
  return to System Default.
- Active capture has an unmistakable recording state and can be stopped by the user.

## Failure policy

- Denied permission explains that microphone access is required and provides a
  retry path after permission changes.
- No available microphone fails before any false recording state.
- A pinned-device disconnect during capture is a platform interruption under
  [recording durability](../recording-durability-and-interruption.md). HoldType
  preserves a qualifying non-empty partial as a provider-free Saved Recording
  and never continues the attempt from another microphone.
- A platform lifecycle or audio event that prevents capture stops visibly and
  preserves a positive-byte partial as provider-free Saved Recording.
  Lifecycle notification alone is not destructive authority.

## Invariants

- Repeated starts do not create parallel recordings.
- Device and permission failures do not create audio, History, provider,
  Retry, Dismiss, or output work unless a qualifying artifact already exists.
- Device identifiers and raw audio paths do not enter default product logs.

## Dependencies

- [Microphone input](../microphone-text-input.md) — shared domain boundary.
- [Privacy and permissions](../privacy-and-permissions.md) — consent and recovery.
- [Recording durability](../recording-durability-and-interruption.md) — disconnect preservation.
