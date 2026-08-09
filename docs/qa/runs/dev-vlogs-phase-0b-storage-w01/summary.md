# Dev Vlogs Phase 0B Storage W01

Status: complete; internal test-root feasibility verified.

Pinned product basis: `DV-DRAFT-3@ed108fa`.

## Scope

This run is test-only feasibility evidence for `DV-P0B-E03`, the storage inputs
to `DV-P0B-E06`, and run-owned cleanup mechanics from `DV-P0B-E08`.

The harness uses only a newly created internal temporary root shaped as
`HoldType-DevVlogs-Phase0B/<run-id>`. It does not inspect or mutate an external
volume, the default Dev Vlogs destination, Recording Cache, ActiveRecordings,
TranscriptionRecovery, Transcript History, UserDefaults, shipping source,
entitlements, the Xcode project, remote storage, or user media.

## Evidence implemented

- ordinary unsandboxed bookmark creation and resolution with no security scope,
  UI, or mounting option;
- run-owned UUID marker validation, captured temporary-directory/prefix/run-root
  device-and-inode identity, exact-prefix enforcement, no-follow component
  validation, symlink rejection, and marker-gated cleanup;
- injected destination and useful-capacity classification, including unavailable,
  nonlocal, read-only, unknown capacity, below reserve, exact reserve, and
  sufficient capacity;
- a caller-supplied reserve only; this run chooses no warning or hard-stop
  product threshold;
- actual exclusive local file creation, synchronous write plus `fsync`, and
  same-volume `renamex_np(..., RENAME_EXCL)` promotion after capability evidence;
- collision evidence that preserves both the existing final and candidate
  fragment byte-for-byte;
- truthful Ready, Incomplete, Failed, and cleanup-pending helpers;
- compact evidence encoding that omits bookmarks, paths, volume identities,
  device labels, user content, and verbose platform errors.

## Evidence limits

- The controlled byte fixtures are not representative media and were not media
  probed. This run therefore makes no playable or Ready media claim. The Ready
  helper is exercised only with an injected `playable` validation result.
- No external SSD/HDD, real read-only destination, physical disconnect,
  remount, external bookmark recovery, or external filesystem was exercised.
- Resource capacity and writability values are preflight hints. Actual create,
  write, sync, and exclusive-promotion results remain authoritative.
- Numeric capacity thresholds remain evidence-derived inputs for Phase 0C.

## Verification receipt

- `DevVlogsStorageFeasibilityTests`: 19 focused cases passed on the internal
  macOS test destination. The ordinary bookmark followed a run-owned folder
  rename and its stale flag was returned and carried into the redacted report.
  This run did not establish a true stale result or stale-bookmark refresh.
- Internal temporary storage reported local, writable, useful-capacity hints.
  Synchronous exclusive create/write completed inside the marker-owned root.
- The current APFS temporary volume reported exclusive-rename support.
  `renamex_np(..., RENAME_EXCL)` promoted on the same volume, and its collision
  case preserved the existing final and candidate fragment unchanged.
- Marker match/mismatch/missing, exact prefix and captured directory identity,
  below-root symlink rejection, redirected-prefix rejection with redirected
  content and unrelated neighboring run survival, cleanup isolation,
  out-of-root rejection, injected destination/capacity states, interruption
  classification, and evidence redaction passed.
- `python3 scripts/check_swift_structure.py`: passed.
- Bounded macOS Debug build: passed.
- Repository diff hygiene and exact three-path staged audit: passed before the
  checkpoint commit.

No app, UI, camera, microphone, provider, Keychain, external volume, mount,
unmount, eject, physical disconnect, representative media, or user archive was
used. This receipt is not hardware, external-filesystem, or playable-media
evidence.

## W03 Debug test-host isolation repair

Pinned repair basis: `DV-DRAFT-4@2f3266a`; Phase 0B `E03`, `E04`, and `E08`;
accepted `STORAGE-W02-REVIEW-R4`; rejected `STORAGE-R01-REVIEW`.

The Debug app entry now evaluates a closed storage test-host route before the
accepted preview, capture/authorization harness, and normal HoldType lifecycle.
Any storage-host or external-storage runtime variable selects that inert route.
Only the exact complete automation, Keychain-skip, host-enable, root-class,
filesystem-class, case, and lowercase UUID configuration succeeds. Missing,
empty, malformed, or conflicting values remain inside the inert composition
and expose a typed test-only failure; they cannot fall through to another app
composition.

The inert SwiftUI app owns only a non-visible empty Settings scene. Structural
and behavioral tests prove that route selection constructs no normal app
delegate, `DictationRuntime`, recovery owner, product scene/menu/window,
capture/authorization/preview owner, or storage action. The accepted external
wrapper now supplies the exact automation, Keychain-skip, and storage-host
variables only on its bounded `xcodebuild test-without-building` path. The
production wrapper function and its help/default/invalid paths are exercised
without external I/O; closed environment values and an exact-root token remain
absent from non-execute output.

Verification used a task-owned sanitized HOME and temporary/DerivedData roots.
Focused storage-host and wrapper suites, existing launch/preview/auth/capture
routes, and the relevant fake-backed Phase 0B preview/media/handoff suites
passed. Signed Debug build-only and unsigned Release build-only passed; the
Release app contains no storage-host key, symbol, or test bundle. No app was
launched, no external volume was accessed, and no protected recovery artifact
was inspected or changed. This is test-host isolation evidence only and does
not rerun or reclassify any external-storage runtime cell.
