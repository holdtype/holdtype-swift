# Phase 0B protected-storage observer W01

Status: implementation evidence only. No observer `--execute` runtime,
external volume, protected-content inspection, Camera, TCC, Keychain,
provider, or media action was performed.

One rejected pre-repair diagnostic test-host route inherited the live user
Home and let Xcode select its default DerivedData/result-metadata location.
The inert route failed closed before constructing a recovery owner. No
protected content was inspected, and no `Recovery.json` stat, open, read,
write, repair, or deletion was performed. Final hosted verification used only
the controller-owned private Home, TMPDIR, explicit DerivedData, and result bundle.

## Implemented boundary

- A complete, duplicate-free `stderr-json-v1` observer configuration selects
  the existing inert storage test host. Partial, malformed, unknown, duplicate,
  external-storage, capture, authorization, or preview combinations fail
  closed before a product owner is constructed.
- The Debug observer emits the fixed-order, value-free V1 schema with one ready
  event, adjacent mutation pairs, a 128-event/512-byte bound, and a terminal
  overflow marker. It exposes exactly the accepted six marker wire values and
  five deletion mappings.
- Debug calls surround the existing recovery directory, audio copy, recovery
  index, marker-write, and exact deletion mutations. The canonical operation
  remains inside its original `do`/`catch`; the exact operation error and
  product ordering are unchanged.
- The C probe follows the canonical target from an identity-checked root with
  `fstatat(..., AT_SYMLINK_NOFOLLOW)` and identity-checked `openat` directory
  traversal. It does not enumerate directories or open/read/hash/parse the
  recovery index.
- The new noninteractive controller is `--execute`-only, starts and proves one
  direct-child caffeinate guard before every other child, uses a private
  identity-pinned task Home and DerivedData, stops after the build comparison,
  and admits the inert hosted test only after an unchanged first window. The
  controller injects and verifies the closed host environment in one
  identity-pinned, task-owned copy of the generated `.xctestrun`; the outer
  build retains its normal signing Home. Its
  parser binds every event to the expected run, returns the exact observed
  owner/mutation/scope/result facts, and feeds the single-result,
  first-applicable classifier. One monotonic 900-second inner deadline and a
  real 930-second outer supervisor bound every stage and cleanup. TMPDIR,
  logs, bin, and the compiled probe are creation-identity pinned; cleanup
  quarantines and revalidates the exact run-root identity before deletion.

## Implementation verification

- Swift structure and parser checks pass; new/modified Debug owners are under
  500 lines and the pre-existing recovery-store line ceiling remains unchanged.
- The controller passes zsh syntax plus help/default/invalid isolation.
- The C probe passes production and synthetic `-Wall -Wextra -Werror` builds.
- A signed Debug build-for-testing and the focused inert-host suites passed
  under a fresh task-owned Home, TMPDIR, and explicit DerivedData. Synthetic
  probe cases covered missing, present, prohibited mode, and symlink targets;
  no external execution occurred.

Release isolation, protected-owner regressions, final path/redaction/residue
audits, and the exact scoped checkpoint are recorded in the W01 terminal
receipt. A later observer runtime remains separately user-authorized and must
write only the accepted eight-file evidence allowlist.
