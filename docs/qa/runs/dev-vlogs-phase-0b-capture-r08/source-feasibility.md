# R08 accepted source basis

- Runtime authority: `f3ae739` on `master`.
- Native-source camera/finalizer/probe/preservation owners remain pinned to
  accepted W02 `f7ff6bf`; lifecycle repairs remain accepted through
  `f141be6`.
- W07-R3 `a90f888` and its independent review accept descriptor/digest
  publication, post-exit one-shot consumption, mismatch retention, bounded
  signals, and the narrow private Debug trust boundary.
- W08 code `d1f5f5f` and accepted summary/review `b418c08` provide a strict,
  closed pre-attempt configuration-stage diagnostic. R08 consumed one valid
  diagnostic at `event_log_path_mismatch`.
- Accepted E07 evidence `719e995` is deterministic and fake-backed only. It is
  not real runtime or shipping audio-lease proof.
- Debug signing verification passed for the same HoldType application identity
  class. The Debug plist contained Camera purpose and Continuity declaration,
  and the signed artifact contained Camera and audio-input entitlements.
  Private signing details are not retained.
- Release, product UI, permission request, storage observer runtime, external
  storage, and product owners were not exercised.
