# Dev Vlogs Phase 0B External Storage R01

Packet: `DV-P0B-STORAGE-R01`

Status: **failed / review required**.

Functional storage results:

- `storage_r01_ssd_hfsplus`: **pass**
- `storage_r01_hdd_apfs`: **pass**

The packet-level failure is a protected-scope discrepancy, not a failure of
the external storage mechanics. A stat-only before/after check found unchanged
protected-owner counts and path sets, but one existing TranscriptionRecovery
metadata artifact and its owning directory received a new modification time
during the second cell. The artifact was not opened, restored, or otherwise
inspected, and this evidence does not attribute the change to a cause.

## Spec basis and authority

- Pinned product basis: `docs/specs/features/dev-vlogs.md`,
  `DV-DRAFT-4@2f3266a`; storage clauses are unchanged.
- Governing evidence plan: `docs/dev-vlogs-implementation-plan.md` and
  `docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md`.
- Accepted external-storage seam: wrapper review R4 at
  `a50026aa53d93c0808ac84259f05759073434fdb`.
- Current wrapper Git blob matched the reviewed blob
  `b8439fa07f8d524f7d3ae85e96b665aa5486181b` before runtime.
- User authority was limited to fresh run-owned scratch beneath two exact
  roots supplied privately to the worker. Retained evidence identifies them
  only as `external_ssd_hfsplus` and `external_hdd_apfs`.

Expected behavior was exact-destination operation with no fallback, positive
useful-capacity observation, ordinary bookmark resolution after a run-owned
rename, exclusive/no-replace promotion, collision preservation, and exact
marker/identity cleanup. Numeric capacity remains evidence-only. No product,
source, spec, registry, project, plist, entitlement, media, camera, audio,
provider, TCC, Keychain, iOS, release, mount, eject, remount, or user-content
operation was authorized.

## Runtime evidence

Both roots independently passed immediate bounded metadata preflight as an
exact canonical, non-symlink, local physical external writable volume with the
expected class and filesystem. The accepted wrapper was invoked exactly once
per cell, serially, with explicit opt-in and its closed class/filesystem/case
arguments.

For each cell:

- `build-for-testing` passed under the wrapper's 600-second bound;
- `test-without-building` passed the focused
  `DevVlogsExternalStorageRuntimeTests` suite under the 180-second bound;
- useful capacity was observed as positive;
- a 26-byte controlled fixture was written only in fresh run-owned scratch;
- its bookmark resolved to the renamed run-owned folder;
- `RENAME_EXCL` promotion succeeded without replacement;
- the collision case preserved both the existing final and candidate bytes;
- the wrapper emitted one `result=pass cleanup=complete` terminal;
- the exact wrapper prefix was absent after the cell.

The SSD/HFS+ invocation exited `0` in 14.483 seconds. The HDD/APFS invocation
exited `0` in 6.379 seconds. These durations and the preflight capacity values
are evidence-only observations and establish no product threshold or storage
suitability policy.

The retained JSONL orders actions by the accepted wrapper and test control
flow. Because no separate redacted per-action clock was exposed, every line in
a cell uses that cell's retained Xcode test-observer terminal timestamp and
labels that timestamp basis explicitly; it is not raw event chronology.

## Protected scope and cleanup

Protected counts remained unchanged: Recording Cache 11 to 11, HoldType
Application Support 57 to 57, ActiveRecordings 1 to 1,
TranscriptionRecovery 54 to 54, default Dev Vlogs 0 to 0, and the History
preferences owner 1 to 1. No new protected path was observed. The stricter
metadata fingerprint changed only for the existing TranscriptionRecovery owner
described above, so the packet is deliberately returned for independent
review rather than reported clean.

Both external scratch prefixes are absent. Final run-owned counts are zero for
HoldType, `xcodebuild`, `xctest`, and `caffeinate`. No pre-existing HoldType
process existed at baseline, and none was left running.

Two related idle-guard deviations are retained:

1. The intended outer session guard exited with its launching tool shell before
   the first cell. The accepted wrapper's own identity-tracked guard still
   covered the complete SSD invocation and cleaned normally.
2. A persistent replacement guard was started before the HDD cell and stopped
   exactly afterward, so no single outer guard spanned both cells. The accepted
   wrapper's own guard also covered the complete HDD invocation.

No functional cell was retried. One read-only preflight formatting mistake and
one read-only no-match process-counter mistake stopped before any wrapper or
external write and were corrected without repeating a functional cell.

Next dependency: `DV-P0B-STORAGE-R01-REVIEW`.
