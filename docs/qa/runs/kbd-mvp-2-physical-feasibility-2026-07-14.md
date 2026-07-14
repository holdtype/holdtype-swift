# KBD-MVP-2 Physical Background-Session Feasibility QA

Date: 2026-07-14

Decision: **Failed — stop**

Task: prove the bounded app-owned keyboard dictation session on a signed
physical iPhone. This is a feasibility gate, not a Simulator qualification.

## Device And Build Boundary

- Repository branch: `master`
- Commit under evaluation: `d5b2c0a` (`Complete KBD-MVP-1 settings action`)
- KBD-MVP-1: committed; `master` matched `origin/master` before this spike
- Physical device: unavailable
- iPhone model and identifier: unavailable
- iOS version: unavailable
- Trust, Developer Mode, and development availability: not testable because no
  physical iPhone was discovered
- Signing: app and extension targets are configured for automatic signing, but
  no signed physical-device installation was possible and the effective team,
  profiles, and installed entitlements were not validated
- Bundle identifiers: `app.holdtype.HoldType.ios` and
  `app.holdtype.HoldType.ios.keyboard`
- Source App Group declaration: both targets declare
  `group.app.holdtype.HoldType.shared`; physical signed-container access was not
  validated
- Full Access declaration at the stopped baseline: `RequestsOpenAccess` remains
  `false`; it was not changed without a qualifying device

## Precondition Check

| Step | Expected | Actual |
| --- | --- | --- |
| Confirm KBD-MVP-1 | A committed KBD-MVP-1 checkpoint on `master` | Passed: HEAD was `d5b2c0a`, and the plan marked KBD-MVP-1 completed |
| Discover a physical iPhone | One connected, trusted iPhone available to CoreDevice/Xcode for development | Failed: `xcrun devicectl list devices` returned `No devices found` |
| Cross-check device inventory | At least one available non-Simulator iOS device | Failed: `xcrun xcdevice list` contained only Simulator iOS devices and the host Mac |
| Validate signed app and extension | Matching development signing and App Group entitlements on installed products | Not run: no physical iPhone was available for build, install, or entitlement inspection |

Exact missing precondition: connect a physical iPhone, unlock it, trust this Mac,
enable Developer Mode when required, and make it available to Xcode for
development signing. The containing app and embedded keyboard extension must
then install with matching development signing and the shared App Group.

## Required Device Matrix

| Device step | Expected result | Actual result |
| --- | --- | --- |
| Start Keyboard Dictation Session in HoldType | A bounded, explicitly started app-owned session becomes available | Not run — physical-device precondition failed |
| Open Notes and select HoldType Keyboard with Full Access | The real extension can write one bounded current command | Not run — physical-device precondition failed |
| Start from the keyboard | The containing app owns real microphone capture in the background; `Listening…` appears only after capture acknowledgement | Not run — physical-device precondition failed |
| Finish from the keyboard | Real capture stops before a deterministic non-provider result is published | Not run — physical-device precondition failed |
| Receive and insert the result | The same live extension request calls `UITextDocumentProxy.insertText` exactly once in Notes | Not run — physical-device precondition failed |
| Cancel from the keyboard | Capture stops and no text is inserted | Not run — physical-device precondition failed |
| Stop or expire the session | The keyboard shows `Open HoldType` | Not run — physical-device precondition failed |
| Disable Full Access | Punctuation, Space, Delete, Return, and Globe remain functional | Not run — physical-device precondition failed |

Computer Use and device-mirroring interaction were not attempted because no
physical iPhone existed to control or observe. Simulator interaction was not
used as replacement evidence.

## Privacy And Energy Observations

- No microphone permission was requested and no microphone capture occurred.
- No audio, host text, provider payload, API key, command record, or
  state/result record was created or logged.
- OpenAI and every live-provider path remained unused.
- No background audio mode, silent-audio keepalive, idle recording, polling
  loop, retry queue, or additional persistence family was added.
- Device background lifetime, microphone indicator agreement, Stop/expiry
  release, and battery impact could not be observed without a physical iPhone.
- No production implementation was started, so there was no incomplete spike
  code to remove.

## Gate Result

KBD-MVP-2 is **Failed — stop** because the required connected, trusted,
development-signable physical iPhone was absent. KBD-MVP-3 must not start from
this result. A later run must begin again at the physical-device precondition;
this failure cannot be converted into a pass with Simulator or source-only
evidence.
