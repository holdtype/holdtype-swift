# Dev Vlogs Phase 0B External Storage R02 Residuals

## Protected-scope failure

Both available external mechanics cells passed, but packet scope is
`fail_protected_domain_dependency`.

The metadata-only protected baseline/final comparison retained an unchanged
count and path set. One protected recovery metadata file changed modification
time and inode without changing file type, mode, or size; its owning directory
changed modification time without changing type, mode, size, device, or inode.
No protected file content was opened, read, hashed, or parsed. No attribution,
restore, rewrite, cleanup, or repair was attempted. Exact private paths,
filenames, inodes, and mtimes were returned only to `/root` and are absent from
committed evidence.

Residual class: `protected-domain dependency`.

## Conditions not available

- physical unplug or disconnect during capture/finalization;
- mount, eject, remount, or true bookmark-stale behavior;
- genuine read-only external media;
- real low-capacity external media;
- representative camera, audio, or video artifacts;
- playable-media validation;
- capacity warning or hard-stop thresholds.

These conditions remain `not_available`. All capacity and duration values are
`evidence_only`; they do not imply a threshold, suitability decision, or
product policy.

## Runtime note

Before the protected baseline or any volume preflight, one long interactive
function-definition paste was corrupted by PTY bracketed-paste handling and
produced parser errors only. It was interrupted before execution, the same
outer guard identity was reverified, and the helper was then sourced from one
private run-owned temporary file. No cell was retried.

## Cleanup

The one persistent outer guard was stopped and reaped after evidence facts were
captured. Both wrapper-owned scratch prefixes are absent. Final run-owned
HoldType, `xcodebuild`, `xctest`, wrapper, and `caffeinate` process counts are
zero. The pre-existing HoldType process set remained unchanged.
