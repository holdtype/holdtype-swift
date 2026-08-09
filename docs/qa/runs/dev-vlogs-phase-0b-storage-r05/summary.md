# Dev Vlogs Phase 0B External Storage R05

Packet: `DV-P0B-STORAGE-R05`

Status: **failed / protected-domain dependency**.

Functional results:

- `external_ssd_hfsplus`: **pass**
- `external_hdd_apfs`: **not invoked after protected-scope stop**

Packet protected-scope result: **fail / changed**.

One prevalidated noninteractive controller started one directly parented
`caffeinate -dimsu` guard and retained stable controller and guard identity
through the protected baseline, SSD metadata preflight, one SSD wrapper
invocation, and the immediate post-wrapper boundary. The accepted wrapper
returned zero, emitted exactly one pass/complete terminal, built the signed
Debug test product, and launched the focused inert hosted test under private
Foundation HOME/CFFIX and the same identity-pinned DerivedData path. The
focused test passed the bookmark-after-rename, positive useful-capacity,
exclusive-promotion, collision-preservation, exact-destination/no-fallback,
fixture, and cleanup assertions.

The immediate metadata-only comparison after the SSD cell returned `changed`.
The controller therefore stopped before HDD preflight or invocation. The exact
private delta was not inspected, retained, attributed, restored, or repaired.

## Spec basis and authority

- Product basis: `docs/specs/features/dev-vlogs.md`,
  `DV-DRAFT-4@2f3266a`; storage clauses are unchanged.
- Evidence basis: `docs/dev-vlogs-implementation-plan.md` and the Phase 0B
  feasibility protocol, gates `E03`, `E04`, and `E08`.
- Accepted external seam: `a50026aa53d93c0808ac84259f05759073434fdb`.
- Accepted value-free inert host: `7b1ba8deae6099ba7416751a894e0ca3ad1582fb`.
- Accepted private-home cleanup: `029f8364bb80b58c9f77cb49dbaea05869c989fb`.
- Accepted identity-pinned DerivedData repair:
  `b172bfd69de8e4313e523f39386ade28a2eda8aa`.
- Registry authority: `c54c798f1543f03cfcd0d0e87d7b6320a256a22e`.

Authority was limited to one fresh wrapper-owned scratch namespace under each
of two privately supplied roots. Only the SSD authority was exercised. The HDD
authority remained unused. Retained evidence uses only closed destination-
class identifiers.

This was `discover` evidence only. No source, test, script, spec, registry,
project, plist, entitlement, product, TCC, Keychain, capture, media, UI, iOS,
Release, mount, eject, remount, or protected corrective action was authorized
or performed.

## Controller, guard, protected boundary, and cleanup

The controller and guard passed five identity checkpoints from guard start
through the SSD post-wrapper boundary. The controller exited once on the
protected comparison failure and was not restarted. The guard was not
replaced. Final process observation found the controller and guard absent, but
the controller's EXIT evidence finalizer emitted no explicit pre-stop or
parent-wait/reap fact. Exact TERM-and-wait reaping is therefore not claimed.

Before the single controller launch, an initial synthetic self-test exposed a
fact-delimiter defect; only the private controller was repaired and the full
synthetic suite then passed. After runtime, two cleanup-proof command defects
affected only observation: one reused zsh's special path variable and one used
incorrect absolute utility paths without pipeline failure propagation. Fresh
exact non-self checks with pipe-failure enabled established the retained zero-
residue facts. No controller, guard, cell, or protected operation was retried.

The protected observer completed a metadata-only baseline and one identical
post-SSD snapshot. Their path/count and metadata tuples did not compare equal.
No protected file content was opened, read, hashed, parsed, attributed,
restored, or repaired. Retained evidence records only `changed`.

The SSD scratch prefix and wrapper-owned task HOME were absent after the
wrapper terminal. Both external scratch prefixes, wrapper task homes, and
exact run-owned HoldType, test, Xcode build, XCTest, controller, and guard
processes were absent at final cleanup observation. The private controller and
raw evidence root were removed after retained evidence validation. No external
cleanup outside the wrapper-owned SSD scratch occurred.

Physical interruption/remount, genuine read-only media, true bookmark
staleness, low-capacity media, and representative media remain
`not_available`.

Next dependency: `DV-P0B-STORAGE-R05-REVIEW`.
