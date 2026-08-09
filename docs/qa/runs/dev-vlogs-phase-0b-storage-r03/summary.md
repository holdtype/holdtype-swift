# Dev Vlogs Phase 0B External Storage R03

Packet: `DV-P0B-STORAGE-R03`

Status: **failed / debug-spike defect**.

Functional results:

- `external_ssd_hfsplus`: **fail**
- `external_hdd_apfs`: **not_available** because the serialized packet stopped
  after the first cell failed; its wrapper was not invoked.

Protected-scope result: **pass / unchanged**.

The exact SSD metadata preflight passed, and its sole accepted-wrapper
invocation completed `build-for-testing`. The hosted focused test then failed
before launch: moving the test invocation into a fresh private Foundation home
also moved Xcode's default build-product lookup away from the already-built
host. There was no focused-test success or wrapper success terminal. The SSD
cell was not retried, and the mandatory stop prevented the HDD cell.

## Spec basis and authority

- Pinned product basis: `docs/specs/features/dev-vlogs.md`,
  `DV-DRAFT-4@2f3266a`; storage clauses are unchanged.
- Governing evidence plan: `docs/dev-vlogs-implementation-plan.md` and
  `docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md`, Phase
  0B `E03`, `E04`, and `E08`.
- Accepted external-storage seam: W02 review R4 at
  `a50026aa53d93c0808ac84259f05759073434fdb`.
- Accepted inert host: W03 and value-free review R1 through
  `7b1ba8deae6099ba7416751a894e0ca3ad1582fb`.
- Accepted private-home cleanup repair: W04-R1 and review at
  `029f8364bb80b58c9f77cb49dbaea05869c989fb`.
- External authority remained limited to one fresh run-owned scratch namespace
  under each of two roots supplied privately. Retained evidence uses only the
  closed cell IDs above.

This was `discover` evidence only. No product, source, test, script, spec,
registry, project, plist, entitlement, camera, audio, provider, TCC, Keychain,
iOS, Release, mount, eject, remount, or pre-existing external-content action
was authorized.

## Protected metadata and guard

One exact identity-tracked `caffeinate -dimsu` guard in one persistent PTY
covered the protected baseline, SSD preflight and invocation, failed-wrapper
cleanup, final metadata-only snapshot, and initial serialization of all seven
evidence files. The same identity passed nine liveness checks before initial
serialization and eleven checks in total, including the final pre-stop check.
It was stopped with `TERM`, reaped exactly, and never replaced.

The before/after protected path set, aggregate count, and every tracked
type/mode/size/mtime/device/inode tuple were unchanged. No protected content
was opened, read, hashed, parsed, attributed, restored, or repaired. The
pre-existing exact HoldType process set was empty and remained unchanged.

## Observer deviations and cleanup

The private evidence observer used a Zsh read-only special variable after the
SSD wrapper returned, so the outer exit status and elapsed duration were not
retained. The wrapper result itself remains an unambiguous functional fail:
build success, focused-test failure, zero success terminals. A second observer
filter initially matched its own process; the stored row proved to be only the
filter itself and was replaced with an exact-name, non-self process check.

The failed wrapper left its fresh private task home present. It was
identity-checked, exclusively quarantined, revalidated after relocation, and
then removed as exact run-owned internal state. The external scratch prefix
was absent, the selected root identity stayed unchanged, and run-owned app,
test, build, wrapper, and helper processes were zero. No external-volume
cleanup was needed because the hosted test never launched.

Physical interruption/remount, genuine read-only media, true bookmark
staleness, low-capacity media, and representative media remain
`not_available`.

Next dependency: `DV-P0B-STORAGE-R03-REVIEW`.
