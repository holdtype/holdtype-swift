# Dev Vlogs Phase 0B External Storage R04

Packet: `DV-P0B-STORAGE-R04`

Status: **failed / environment residual**.

Functional results:

- `external_ssd_hfsplus`: **not invoked**
- `external_hdd_apfs`: **not invoked**

Packet protected-scope result: **not proven**.

The accepted wrapper, canonical storage test, value-free inert host, private
Foundation home, and identity-pinned shared DerivedData provenance all passed
the pre-runtime gate. One persistent-session `caffeinate -dimsu` guard was
started and its exact identity passed the immediate-start and pre-baseline
checks. The persistent shell then closed after corrupting the private observer's
baseline command. The protected baseline was not completed, the guard's parent
identity changed when it became orphaned, and the mandatory stop condition
fired. The guard was not replaced.

No volume preflight, wrapper invocation, external scratch creation, Xcode
build/test, hosted test launch, or protected final snapshot occurred. Prior
accepted mechanics evidence is not restated as R04 runtime proof.

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
- Registry authority: `6bf645044c48d23dcd40e86e4a60eb91c94a9393`.

Authority remained limited to a new wrapper-owned scratch namespace under each
of two privately supplied roots. Neither authority was exercised. Retained
evidence uses only closed destination-class identifiers.

This was `discover` evidence only. No source, test, script, spec, registry,
project, plist, entitlement, product, TCC, Keychain, capture, media, UI, iOS,
Release, mount, eject, remount, or protected corrective action was authorized
or performed.

## Guard, protected boundary, and cleanup

The guard was exact-identity verified twice before the baseline command. The
persistent shell failure changed the guard's parent identity, so continuity
cannot be claimed. The recorded run-owned guard was still alive; it was
verified by its recorded process identity and start time, stopped with `TERM`,
and confirmed absent. It could not be reaped by the closed parent shell and was
never replaced.

The protected observer never completed or retained a baseline and no final
snapshot was taken. No protected content was opened, read, hashed, parsed,
attributed, restored, or repaired. Protected metadata is therefore
`not_proven`, not `unchanged`.

Both external scratch prefixes remained absent. Wrapper-owned task homes and
exact HoldType, test, Xcode build, and XCTest processes were zero. The private
empty observer root and helper were removed. No external-volume deletion was
needed or performed.

Physical interruption/remount, genuine read-only media, true bookmark
staleness, low-capacity media, and representative media remain
`not_available`.

Next dependency: `DV-P0B-STORAGE-R04-REVIEW`.
