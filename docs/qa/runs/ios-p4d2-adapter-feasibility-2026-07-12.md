# iOS P4D-2 Adapter Feasibility Review

Date: 2026-07-12
Milestone: P4D-2 implementation routing and recorder identity gate

## Decision

P4D-2 can implement the descriptor-bound capture source and all fake-backed
iOS platform seams now. `AVAudioRecorder` remains a fail-closed candidate, not
a release-approved recorder, until a short physical-device recording proves it
preserves the exact Persistence-created inode, xattrs, protection, owner, mode,
link count, and path agreement.

If that proof fails, HoldType keeps the frozen storage contract and replaces
the URL-only recorder with a descriptor-backed AudioToolbox/AVAudioEngine
writer. The product does not trade crash recovery or protected-source identity
for implementation convenience.

## Apple API Findings

- Apple documents `prepareToRecord()` as creating and overwriting its target,
  but `AVAudioRecorder` exposes a URL initializer and no descriptor initializer.
  The documentation does not promise inode or application-xattr preservation:
  [prepareToRecord](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/preparetorecord%28%29),
  [URL initializer](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/init%28url%3Asettings%3A%29-5whyq).
- iOS 17 app-level permission uses `AVAudioApplication`; a missing microphone
  purpose string terminates an app that requests access:
  [AVAudioApplication](https://developer.apple.com/documentation/avfaudio/avaudioapplication),
  [request permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29).
- Recorder completion cannot rely only on its delegate during interruption, and
  recorder time may reset after stop:
  [recorder delegate](https://developer.apple.com/documentation/avfaudio/avaudiorecorderdelegate/audiorecorderdidfinishrecording%28_%3Asuccessfully%3A%29),
  [interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions),
  [currentTime](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/currenttime).
- Route notifications require current-route reinspection, while media reset
  requires rebuilding objects without automatic restart:
  [route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes),
  [media lost](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswerelostnotification),
  [media reset](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification).
- Complete Data Protection may make bytes temporarily unavailable while the
  device is locked; background execution does not weaken that policy:
  [FileProtectionType](https://developer.apple.com/documentation/foundation/fileprotectiontype),
  [background execution](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time).

## Implementation Routing

1. P4D-2A: Persistence capture-source namespace, lease, phases, media
   validation, relaunch classification, exact cleanup, and descriptor-bound
   Pending transfer.
2. P4D-2B: app-target microphone permission, foreground audio session,
   notification adapter, feedback, bounded background assertion, and recorder
   candidate behind injected seams.
3. P4D-2C: physical-device identity probe before and after
   initialization/prepare/record/stop, plus real permission, route,
   interruption, lock, cue, and microphone-indicator evidence.

P4D-2 adds the microphone purpose string only to the containing app. It adds no
Speech permission, microphone entitlement, audio background mode, App Group
schema, keyboard dependency, Voice UI, or production scene composition.

## Current Environment

The current Xcode device inventory contains the local Mac and iOS Simulators,
but no connected iPhone or iPad. Therefore P4D-2C cannot produce qualifying
physical evidence in this run. This does not block P4D-2A, P4D-2B, Simulator
tests, Release builds, keyboard-isolation checks, or later UI work; it remains
an explicit release gate rather than an inferred pass.
