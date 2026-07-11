# iOS History Policy Cutover QA

Date: 2026-07-11
Milestone: P2 C3 accepted-History policy cutover and stale-generation cleanup

## Scope

- Make containing-app-only Clear, Disable, and Enable commands durable before
  any cleanup is authorized.
- Treat the confirmed policy as the logical-success boundary and return only a
  payload-free `complete` or `pendingLocalRecovery` cleanup disposition.
- Retain an exact uncertain command before that boundary; only the same command
  may resume confirmation, and a definitive CAS failure authorizes no cleanup.
- Prune only invalidated accepted rows, process at most one canonical outbox
  head per call through the completed C2 worker, and reconcile the standalone
  delivery conservatively.
- Preserve exact local phases across visible and invisible uncertainty without
  advancing the policy generation again on cleanup retry or relaunch recovery.
- Keep policy, generation, rows, receipts, delivery authority, and cleanup
  state app-private and absent from App Group and the keyboard extension.

Failed History rows and retry-only audio do not yet participate in this
cutover. The shipping History toggle, Clear History action, and first-use
disclosure remain deferred until that next durability slice is complete.

## Automated Evidence

- `swift test --package-path Packages/HoldTypePersistence -Xswiftc
  -strict-concurrency=complete -Xswiftc -warnings-as-errors`
  - Result: passed, 597 tests in 27 suites.
- `xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination
  'platform=macOS' test`
  - Result: passed for the full macOS test suite.
- HoldType-iOS simulator tests through XcodeBuildMCP
  - Result: 960 tests passed, 0 failed, 0 skipped on iPhone 16 Pro simulator
    `AFB49941-79A4-400A-AA0F-9E962155E485`.
- HoldType-iOS simulator build through XcodeBuildMCP
  - Result: succeeded and produced the containing app with its keyboard
    extension.
- `swift package --package-path Packages/HoldTypePersistence
  dump-symbol-graph --minimum-access-level public`
  - Result: the C3 public addition contains only
    `IOSHistoryPolicyCleanupDisposition` and `clearHistoryPolicy()`,
    `setHistoryEnabled(_:)`, and `recoverHistoryPolicyCleanup()`. Commands,
    generations, receipts, stores, retained phases, rows, and cleanup internals
    are not public.
- `otool -L` and `nm -gU` on the simulator keyboard executable and debug dylib
  - Result: clean. The keyboard retains its existing controller/bridge-only
    isolation and contains no Domain, Persistence, OpenAI, IOSCore,
    accepted-History, policy-cutover, row, receipt, or cleanup linkage or
    symbols.
- Owned-document `git diff --check` plus a trailing-whitespace scan of this new
  QA record
  - Result: passed.

## Verified Contract And Edge Cases

- Clear always advances revision and generation once while preserving the
  enabled value. A state-changing toggle advances both once; a repeated toggle
  value is a durably confirmed no-op.
- A policy commit-uncertain result retains the exact command and performs zero
  cleanup. A different command fails closed. Definitive pre-boundary CAS or
  overflow clears transient command state without deleting History data.
- Once the policy is confirmed, cleanup failure is `pendingLocalRecovery`, not
  command failure. The policy is never rolled back, and matching command or
  provider-free cleanup retries do not create another generation.
- Accepted-row cleanup preserves every current-generation row. Outbox cleanup
  reuses the strict C2 state machine, handles only one canonical head per call,
  and never bulk-deletes or skips a blocked head.
- A stale unresolved standalone delivery marker may be cancelled only with the
  exact newer-policy receipt. Current-generation and terminal markers remain
  untouched; future-generation, rollback-ambiguous, corrupt, unavailable, or
  superseded state is preserved and remains pending.
- Exact expiry is handed to ordinary accepted-History recovery through a
  store-minted sealed observation. Recovery starts at confirmation of that
  observation, does not resample expiry, and therefore still removes the exact
  delivery after wall-clock rollback. Foreign-store observations and retained
  confirmation/removal work with mismatched observation lineage fail before
  delivery mutation.
- Root-shared cutover state excludes capture, acceptance, pending replacement,
  and ordinary outbox entry points. Matching post-boundary retries may resume
  only cutover-owned worker or standalone-cancellation uncertainty; unexpected
  retained work remains pending.
- A repository conflict before the logical boundary remains a typed error and
  authorizes no cleanup. For a user command already past the durable boundary,
  it preserves the cutover and returns pending; provider-free recovery keeps
  its typed repository-conflict contract. `complete` clears retained state only
  after a final stable repository proof.
- Public disposition, command, work, phase, observation, authorization, and
  recovery diagnostics are redacted and expose no History payload through
  description, debug reflection, or the keyboard boundary.

## Independent Review Fixes

Independent state-machine, API/security, and coverage review tightened four
areas before the final gate:

- cleanup state is retained across the durable boundary and cleared only after
  the final repository-stability check;
- same-command retry resumes the exact retained C2 worker or standalone cancel
  transition instead of being stranded by a generic delivery-work interlock;
- expiry handoff retains a store-minted observation and exact
  observation-to-removal lineage rather than a caller-reconstructible
  expectation or a new clock sample;
- generic recovery never resumes an uncommitted user command, while the public
  surface remains limited to payload-free command and cleanup results.

The final package, macOS, iOS simulator, symbol-graph, and keyboard-isolation
evidence above includes these corrections.

## Gate Decision

P2 C3 accepted-History policy cutover and stale-generation cleanup: passed for
package and simulator code verification.

The next durability slice is bounded failed History plus retry-audio ownership
under the same policy generation and cleanup path. The independent Recording
Cache and directional App Group bridge remain later work.

This is not physical-device evidence. Effective Complete Data Protection while
locked, force-quit/process eviction, signed App Group behavior, keyboard
enablement/Full Access, and actual insertion remain their named physical gates.
