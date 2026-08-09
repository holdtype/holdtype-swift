# Dev Vlogs Phase 0B External Storage R02

Packet: `DV-P0B-STORAGE-R02`

Status: **failed / protected-domain dependency**.

Functional storage results:

- `external_ssd_hfsplus`: **pass**
- `external_hdd_apfs`: **pass**

Both bounded external-storage mechanics cells passed through the accepted
wrapper and value-free inert Debug test host. Packet scope failed because the
metadata-only protected before/after comparison changed. The protected count
and path set stayed unchanged, as did the affected objects' type, mode, and
size, but one protected recovery metadata file changed modification time and
inode and its owning directory changed modification time. No protected file
content was opened, read, hashed, parsed, restored, or repaired. The exact
private delta was returned only to `/root` and is not retained here.

## Spec basis and authority

- Pinned product basis: `docs/specs/features/dev-vlogs.md`,
  `DV-DRAFT-4@2f3266a`; storage clauses are unchanged.
- Governing evidence plan: `docs/dev-vlogs-implementation-plan.md` and
  `docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md`, Phase
  0B `E03`, `E04`, and `E08`.
- Accepted external-storage wrapper chain: review R4 at
  `a50026aa53d93c0808ac84259f05759073434fdb`.
- Accepted inert-host route: W03 at
  `89127ccfa211b29d588bc09525ad17cabd7ffba8` and value-free repair/review R1
  at `7b1ba8deae6099ba7416751a894e0ca3ad1582fb`.
- User authority was limited to fresh run-owned scratch beneath two exact
  roots supplied privately to the worker. Retained evidence uses only the
  closed IDs `external_ssd_hfsplus` and `external_hdd_apfs`.

Expected behavior was exact-destination operation with no fallback, positive
useful-capacity observation, ordinary bookmark resolution after a run-owned
rename, exclusive/no-replace promotion, collision preservation, a fixture
below the 64 KiB cap, and exact marker/identity cleanup. Numeric capacity and
duration remain evidence-only. No product, source, test, script, spec,
registry, project, plist, entitlement, media, camera, audio, provider, TCC,
Keychain, iOS, Release, mount, eject, remount, or pre-existing user-content
operation was authorized.

## Runtime evidence

Both roots independently passed immediate bounded metadata preflight as an
exact canonical, non-symlink, local physical external writable volume with the
expected media class and filesystem. The accepted wrapper was invoked exactly
once per cell, serially, with explicit execute/root/class/filesystem/case
arguments and an 840-second outer bound. Its complete sanitized environment
selected the inert storage host before normal `HoldTypeApp` composition.

For each cell:

- `build-for-testing` and focused `test-without-building` passed under the
  wrapper's finite bounds;
- useful capacity was observed as positive;
- a 26-byte controlled fixture was written only in fresh run-owned scratch;
- its bookmark resolved to the renamed run-owned folder;
- `RENAME_EXCL` promotion succeeded without replacement;
- the collision case preserved both the existing final and candidate bytes;
- the wrapper emitted exactly one `result=pass cleanup=complete` terminal;
- the exact wrapper prefix and run-owned processes were absent afterward.

The SSD/HFS+ invocation exited `0` in 24.290 seconds. The HDD/APFS invocation
exited `0` in 4.885 seconds. Durations and preflight capacity values are
evidence-only observations and establish no threshold or suitability policy.

## Guard, protected scope, and cleanup

One identity-tracked `caffeinate -dimsu` process in one persistent PTY covered
the protected baseline, SSD preflight/run/cleanup, HDD preflight/run/cleanup,
final protected snapshot, and retained evidence-fact capture. The same identity
passed nine liveness checks: immediately after start, after recovery from a
pre-runtime shell parser error, before each root preflight, after each wrapper
cleanup, before the final protected snapshot, before evidence capture, and
immediately before stop. It was then stopped with `TERM` and reaped. It was
never replaced.

The protected comparison returned `changed`, so packet scope is `fail` with
residual class `protected-domain dependency`. No attribution or corrective
action was attempted. Both external scratch prefixes are absent; run-owned
HoldType, `xcodebuild`, `xctest`, wrapper, and guard processes are zero; and the
pre-existing HoldType process set remained unchanged.

Physical unplug/remount, genuine read-only media, true bookmark staleness,
low-capacity media, and representative media remain `not_available`.

Next dependency: `DV-P0B-STORAGE-R02-REVIEW`.
