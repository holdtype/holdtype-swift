# Phase 0B protected-storage observer W01

Status: implementation evidence only. No observer `--execute` runtime,
external volume, protected-content inspection, Camera, TCC, Keychain,
provider, or media action was performed.

Excluded diagnostic and verification routes exposed the live user Home or
default Xcode result-metadata location.
No protected content was inspected by the worker or reviewer,
but host metadata access was not proven absent. Final qualifying verification
used only the controller-owned private Home, TMPDIR, explicit DerivedData, and
result bundle.

One failed R7 build-only diagnostic exposed an ephemeral task-owned `/tmp`
token in internal tool output because redaction covered only its
`/private/tmp` alias. No protected or user path entered durable evidence, and
the exact task root was removed.

One excluded R8 19-cell verification used the wrong task-owned private-root
prefix and failed only the closed route-name check. The exact canonical
private-root rerun passed; neither invocation performed external or protected
runtime action.

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
  quarantines and revalidates the exact run-root identity before deletion. A
  hosted event line becomes durable only after the complete expected-run,
  closed-schema stream validates; malformed and pre-hosted outcomes retain an
  empty event file. Each evidence file is created exclusively relative to its
  pinned directory descriptor, written to completion through that file
  descriptor, and pinned from `fstat` before close. Success requires the exact
  eight regular mode-0600 closed-schema files with no extras. The durable path
  keeps the closed `evidence_write_failed`/`incomplete_retained` tree while a
  separately identity-pinned success tree is built and validated. The complete
  pending tree moves to a tracked quarantine while the canonical name is
  absent. Displaced-tree cleanup is one descriptor-
  relative identity-verifying helper operation under the private mode-0700
  run-root trust boundary; it does not traverse or rewrite a replacement. If
  that boundary detects replacement or fails after a partial cleanup, the
  separately created and pinned failure-safe tree becomes authoritative at the
  absent canonical name; the implicated partial quarantine remains auditable.
  Only after cleanup has no residual does one descriptor-relative,
  identity-bound `renameatx_np(..., RENAME_EXCL)` publish the already complete
  success tree into the proven-absent canonical name. A late collision cannot
  overwrite or nest the staged tree and remains an explicitly classified
  residual. There is no fallible operation after a successful publication.
  A pre-publication helper timeout or nonzero result leaves pending or absent
  authority, retains the complete staged tree, and suppresses public success.
  Replacements and siblings remain untouched.
- A single terminal state machine reaps the supervisor, resolves exact root
  cleanup while the guard remains proven, reaps the guard, then attempts the
  closed eight-file evidence write. Cleanup or
  evidence uncertainty or any retained evidence-commit residual overrides
  success before public success output. This boundary does not claim resistance
  to a malicious same-UID actor outside the accepted private-root trust model.

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
