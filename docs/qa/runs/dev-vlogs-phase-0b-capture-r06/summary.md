# Dev Vlogs Phase 0B Continuity Capture R06

Packet: `DV-P0B-CAPTURE-R06`

Result: **fail** (`video_preservation_failed`).

## Scope and authority

This was one discover/evidence-only 10-second internal-temporary-destination
Continuity Camera cell under `DV-DRAFT-4@2f3266a` and Phase 0B
`E02/E04/E06/E08`. Current runtime authority was `2ca4dfd`; the accepted
native-source owner was `f7ff6bf`, lifecycle repairs were accepted through
`f141be6`, and the hardware script tail matched
`b489ec6cbde5f690e312b87e1ef677e3aa04f95d27db66dc7f6c46560c92a3f5`.
No product, source, project, UI, external-storage, provider, or Keychain change
was authorized or made. No `requestAccess`, System Settings action, TCC reset,
or direct TCC database operation occurred.

## Runtime result

- Fresh bundled Apple-native enumeration reported one Continuity Camera and
  one connected, non-suspended eligible Continuity Camera. Its exact identity
  was selected in memory and was not retained. No fallback was permitted.
- Hardware mode was invoked exactly once. Camera permission request variables
  and provider variables were explicitly absent. No permission request,
  prompt interaction, System Settings action, or retry occurred.
- Camera authorization was `authorized`, established by closed-route
  reachability: the accepted hardware owner checks authorization before device
  discovery and cannot reach capture, probe, finalization, or preservation in
  another authorization state.
- Capture started and advanced through the camera-only playable-media probe,
  passthrough-only finalization, and the finalized playable-media probe.
  Therefore the camera-only asset had one playable video track and no audio
  track, and the finalized asset had one playable video track and one playable
  audio track.
- The accepted single dictation-audio owner was used once; the camera session
  remained video-only. No second microphone owner was introduced.
- The `stored_sample_exact_v1` preservation comparator failed. The closed
  terminal category was `video_preservation_failed`; no Ready clip was
  produced. This is a functional failure, not an evidence-only measurement.

The redacted event watcher did not discover the run-owned event file before
the accepted script removed its raw root. Consequently realized dimensions,
cadence, codecs, transforms, sample counts, byte counts, timestamps, and
timings were not recoverable. They are recorded as unavailable/evidence-only,
not reconstructed from the transient media. The retained JSONL is normalized
from the single invocation, the exact operator terminal, and accepted closed
stage ordering; it is not a copy of the lost raw event stream.

## Cleanup

The accepted nonpermission hardware cleanup removed all run-owned raw audio,
camera video, finalized media, and temporary roots. The run-owned app,
enumerator, watcher, script, and capture processes exited. The pre-existing
HoldType process was preserved. Recording Cache ownership, ActiveRecordings,
TranscriptionRecovery, and the default Dev Vlogs destination retained their
baseline file counts. No external or remote storage was used. The scoped idle
guard was stopped and verified after evidence validation.

## Deviations

Before the one actual enumeration, three wrapper preflights stopped without
enumerating or capturing: one canonical temporary-root spelling mismatch, one
empty expanded signing-setting check, and one bounded development-signing
operation that did not complete without Keychain interaction. Their exact
roots/processes were removed. The successful enumerator used a bounded bundled
Apple-native helper with an ad-hoc signature; the separately verified signed
Debug HoldType app and hardware invocation were unchanged. A prior read-only
preflight command also retried after shadowing a zsh special variable. None of
these prelaunch attempts started camera enumeration or capture.

The material evidence deviation was the watcher path miss. No capture retry
was made.

## Residual

Primary residual class: `debug-spike defect`. The hardware cell failed the
exact encoded-video preservation comparator. The watcher loss is a second
debug-spike evidence defect and prevents diagnosis of the realized sample
mismatch from this run. Quantitative measurements remain
`evidence_only`/unavailable, and marker-based sync or drift was not attempted.

Next dependency: `DV-P0B-CAPTURE-R06-REVIEW`.
