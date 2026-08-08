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
