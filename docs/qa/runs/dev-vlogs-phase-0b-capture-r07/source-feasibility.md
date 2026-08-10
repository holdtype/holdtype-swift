# R07 accepted source basis

- Current runtime commit: `67349ec` on `master`.
- Native-source camera/finalizer/probe/preservation owners remain pinned to
  accepted W02 `f7ff6bf`; lifecycle repairs remain accepted through
  `f141be6`.
- The current event and launch diagnostic owners are the protected W07 source
  blobs, and the current hardware script is exactly the accepted W07-R3 blob
  from `a90f888`.
- W07-R3 independent review accepts descriptor/digest publication,
  post-exit one-shot consumption, mismatch retention, bounded signals, and the
  narrow private Debug trust boundary. R07 did not receive a validated
  snapshot, so it makes no handoff-success claim.
- Accepted E07 evidence `719e995` is deterministic and fake-backed only. It is
  not real runtime or shipping audio-lease proof.
- Debug signing verification passed for the same HoldType application identity;
  the Debug plist contained Camera purpose and Continuity declaration, and the
  signed artifact contained Camera and audio-input entitlements. Private
  signing identity details are not retained.
- Release, product UI, permission request, observer runtime, external storage,
  and product owners were not exercised.
