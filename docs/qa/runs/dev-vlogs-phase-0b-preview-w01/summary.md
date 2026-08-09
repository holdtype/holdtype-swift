# Dev Vlogs Phase 0B Preview W01

## Scope

This checkpoint is fake/build evidence for the isolated Debug-only SwiftUI
preview spike. It is not product implementation and does not establish runtime
camera feasibility.

Changed paths:

- `HoldType/HoldTypeApp.swift`
- `HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BPreviewLaunch.swift`
- `HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BPreviewSession.swift`
- `HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BPreviewView.swift`
- `HoldTypeTests/DevVlogsPhase0BPreviewLaunchTests.swift`
- `HoldTypeTests/DevVlogsPhase0BPreviewSessionTests.swift`
- `docs/qa/runs/dev-vlogs-phase-0b-preview-w01/summary.md`

## Fake and build evidence

- Structure checks pass; every changed Swift file remains below 500 lines.
- Thirteen new focused cases pass for fail-closed launch routing, passive idle,
  explicit exact selection, authorization outcomes without a request, typed
  device/frame failures, deterministic frame conversion and latest-only
  publication, ordered exact-once cleanup, late-frame rejection, cancellation,
  and fresh reacquisition.
- The twelve existing Debug launch cases pass unchanged.
- The proportional Phase 0B run passes all thirteen new cases and all seventy-
  three existing Swift Testing cases in the selected Phase 0B suites.
- The Debug app builds successfully.
- Release build settings retain the original Release plist and entitlements
  inputs. A direct Release target build with Xcode signing and linker ad-hoc
  signing disabled succeeds; its app is unsigned, has no Camera usage key, and
  contains neither the preview environment key nor preview symbols.
- Structural scans find no AppKit visible UI, representable, preview layer,
  movie/audio/file output, permission request, capture-format mutation, or
  connection-mirroring mutation in the spike. Preview mirroring occurs only in
  the SwiftUI image transform.
- Diff and protected-path checks pass.

One test-only continuation fake triggered a Swift compiler lifetime-pass loop.
Replacing it with a cancellable deterministic suspension removed the tooling
pathology without changing the exercised lifecycle contract.

## Protected owners and isolation

The existing capture, authorization, finalizer, media-probe, preservation,
storage, scripts, project, plist, entitlement, Settings, menu, dictation,
Release, and iOS owners are unchanged. The early router preserves the existing
normal/capture-harness selection when the preview key is absent. Any present
but invalid or conflicting preview configuration remains inside the
noncapturing preview error composition.

## Runtime boundary and residual matrix

No app UI was launched, no camera or permission API was exercised, no TCC state
was requested or changed, and no Computer Use, screenshot, audio, video, or
media file was produced or retained. XCTest used only its normal test host.

Later controlled runtime evidence must still determine:

- real frame cadence and SwiftUI rendering responsiveness;
- built-in, external, and Continuity Camera orientation behavior;
- visual confirmation of preview-only mirroring;
- camera-indicator and device release after Stop, disappearance, failure, and
  timeout;
- real Stop-to-Start reacquisition without ownership leakage.

Next dependency: `DV-P0B-UI-W01-REVIEW`.
