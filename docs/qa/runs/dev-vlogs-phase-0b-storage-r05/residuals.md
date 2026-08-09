# Dev Vlogs Phase 0B External Storage R05 Residuals

## Protected-scope stop

The SSD cell completed with a zero wrapper status, one pass/complete wrapper
terminal, successful build, passing focused inert hosted test, and complete
wrapper-owned scratch/task-HOME/process cleanup. The identical metadata-only
protected snapshot taken immediately afterward did not compare equal to the
baseline. The packet therefore failed and the HDD cell was not preflighted or
invoked.

Retained evidence records only `changed`. The private path/count/metadata delta
was not inspected or retained. No protected content was opened, read, hashed,
parsed, attributed, restored, or repaired.

Residual class: `protected-domain dependency`.

## Controller finalization proof

One noninteractive controller and its one direct-child guard passed five exact
identity checkpoints through the SSD post-wrapper boundary. The controller
exited once with the protected-stop status and was not restarted. Final process
observation found both controller and guard absent.

The controller's EXIT evidence finalizer did not emit an explicit pre-stop
identity or parent-wait/reap fact. Guard absence is proven; explicit controller
`TERM` plus `wait` reaping is not. This is retained as an environment/tooling
evidence residual and is not repaired or retried.

Residual class: `environment or signing residual`.

## Observer deviations

The first pre-launch synthetic self-test exposed a private fact-delimiter
defect. The private controller alone was repaired, syntax-checked, and passed
the complete synthetic suite before its one permitted launch. This was not a
runtime or cell attempt.

After the controller had already exited and exact private files had been
removed, one cleanup-proof shell reused zsh's special path variable, preventing
two subsequent utility lookups. A second proof command used incorrect absolute
utility paths and lacked effective pipeline failure propagation, so its
process result was discarded. One fresh exact non-self process check with
pipe-failure enabled then proved zero processes; exact scratch and task-root
absence checks also passed. These observer corrections performed no protected
metadata or external scratch operation and did not retry the controller,
guard, or either cell.

## Functional cells and measurements

The SSD/HFS+ cell is a functional mechanics pass. Capacity, elapsed time, and
fixture byte counts remain `evidence_only`; no threshold or suitability claim
is inferred. All retained fixtures are at most 64 KiB and were removed by the
accepted wrapper.

The HDD/APFS cell has zero wrapper invocations and therefore has no matrix,
measurement, artifact, or event row. It is `not_invoked_protected_stop`, not a
hardware pass or `not_available` result.

Physical interruption/remount, genuine read-only media, true bookmark
staleness, low-capacity media, and representative media remain
`not_available`.

## Cleanup

Both external scratch prefixes and wrapper-owned task homes were absent at
final observation. Exact run-owned HoldType, hosted-test, Xcode build, XCTest,
controller, and guard processes were zero. The private controller and raw
evidence root were exact-cleaned after retained evidence validation. No
external deletion outside the accepted wrapper-owned SSD scratch occurred.

Next dependency: `DV-P0B-STORAGE-R05-REVIEW`.
