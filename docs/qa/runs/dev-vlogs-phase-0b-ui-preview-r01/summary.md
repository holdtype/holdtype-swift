# Dev Vlogs Phase 0B UI Preview R01

- Packet: `DV-P0B-UI-R01`
- Status: done
- Functional result: `not_available`
- Outcome: the isolated preview launched, remained idle until an explicit
  camera selection and Start, then returned the typed state
  `authorizationRequired`. HoldType reported Camera access as
  `not_determined` and did not request it.
- Product basis: `DV-DRAFT-4@2f3266a`
- Runtime product commit: `00e847594863a27bb641c85617f3e918b0fa0ba1`
- Accepted preview ancestor: `085fa26dc7040d91b9427a292aa62a9dbe0035c8`
- Device availability: one `external` camera; its label and unique identifier
  were not retained.

## Specified expectation

The isolated Debug-only SwiftUI preview must remain noncapturing until the user
selects one exact camera and presses Start. It must request no permission, write
no media, show changing live frames when Camera is already authorized, mirror
only the display, release Camera before terminal Stop, and support one
Stop-to-Start reacquisition.

## Observed evidence

Computer Use inspected the initial `Idle — camera released` state with the
placeholder visible and Start disabled. The sole enumerated camera was selected
through the SwiftUI Picker, enabling Start. One Start click returned `Camera
access is not determined; preview will not request it.` The placeholder
remained visible, Stop remained disabled, and no frame or capture state was
observed.

The app-scoped typed state is authoritative. A separate read-only enumeration
helper was used only to pass the exact device identity ephemerally to the
accepted isolated route; it did not request permission, and no device label or
identifier was retained.

## Result limits

- Explicit selection: pass.
- No passive capture: pass for the observed launch and selection path.
- First Start and changing frames: not available because app-scoped Camera
  authorization was `not_determined`.
- Display-only mirroring: not exercised; structural W01 evidence remains the
  only basis.
- Camera indicator: not observed because capture never started.
- Stop release and Stop-to-Start reacquisition: not exercised.
- UI responsiveness: the Picker and Start action responded with a closed typed
  state.
- Screenshot: not retained because the UI exposed a private device label and
  no safe live frame was available.
- Source capture, stored orientation, recording, permission request, product
  UI, and W07 cleanup were not tested.

## Discrepancy classification

`environment or signing residual`: the freshly built isolated app identity
reported Camera authorization as `not_determined`, so the required external
condition for E05 live-frame evidence was unavailable. No TCC or System
Settings action was authorized or taken.

## Cleanup

The preview window was closed through Computer Use. The remaining exact
run-owned app identity exited after one bounded TERM. The scoped caffeinate and
Computer Use session exited. The one pre-existing HoldType identity was
preserved, no new HoldType process remained, and no run-owned non-build media
or screenshot existed.

Recording Cache, ActiveRecordings, TranscriptionRecovery, and the default Dev
Vlogs destination retained their baseline file counts and sizes. The shared
preferences plist changed size and digest while the pre-existing HoldType
process remained active, so this run does not attribute that differential or
claim a byte-identical History owner. The isolated route contains no product
History owner, but the runtime evidence alone cannot separate concurrent
pre-existing activity.

Next dependency: `DV-P0B-UI-R01-REVIEW`.
