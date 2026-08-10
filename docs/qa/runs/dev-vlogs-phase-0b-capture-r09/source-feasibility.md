# R09 accepted source basis

- Runtime authority: registry checkpoint `d3a5b2d` on `master`.
- Native-source camera/finalizer/probe/preservation owners remain pinned to
  accepted W02 `f7ff6bf`; lifecycle repairs remain accepted through
  `f141be6`.
- W07-R3 `a90f888` and its independent review accept descriptor/digest
  publication, post-exit one-shot consumption, mismatch retention, bounded
  signals, and the narrow private Debug trust boundary.
- W08-R1 `d1f5f5f` remains the accepted script/EventLog/handoff lineage.
  W09-R1 `7342f18` and independent Review-R1 accept symmetric parent
  canonicalization plus no-follow final event-log leaf validation.
- Accepted E07 evidence `719e995` is deterministic and fake-backed only. It is
  not real product dictation, shipping audio-lease, or provider proof.
- Debug build-only and signing verification passed for the same HoldType
  application identity class. The Debug plist contained Camera and Microphone
  purpose declarations plus the Continuity declaration, and the signed
  artifact contained Camera and audio-input entitlements. Private signing
  details are not retained.
- The accepted camera route checks status-only Camera authorization before
  explicit device selection. Its successful capture therefore supports
  `authorized`; no permission request was made.
- Camera probe pass means a playable asset with exactly one video and zero
  audio tracks. Final probe pass means a playable asset with exactly one video
  and one audio track. The camera service owns video input only; one existing
  Debug dictation-audio recorder supplies final audio.
- Release, product UI, permission request, storage observer runtime, external
  storage, and product owners were not exercised.
