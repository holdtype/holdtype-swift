# Saved Recording Lifecycle

- Node type: leaf
- Contract ID: `holdtype.macos.transcript-history.saved-recording`
- Domain ID: `holdtype.macos.transcript-history`
- Status: Active
- Stability: Released
- Contract revision: `holdtype.macos.transcript-history.saved-recording@1`
- Read when: recovery creation, playable validation, completion identity, or protected-audio retention is in scope.
- Do not read when: only accepted text, provider retry, or window layout is in scope.
- Maximum size: 100 physical lines.

## Creation and validation

- Lifecycle/internal interruption produces an immediate provider-free Saved
  Recording with Play, Transcribe, and Delete—no relaunch or automatic provider call.
- Recoverable provider/network/timeout/rate-limit/response/empty-result failure
  turns the existing row into failed attempt without deleting audio.
- Before visibility or relaunch restore, the supported-audio decoder must prove
  a locally readable playable container. Zero, truncated, malformed, or
  unplayable artifacts never appear or offer Play/Retry/Transcribe Again.
- Detection reports the compact local failure immediately while retaining the
  unusable artifact non-destructively outside recoverable UI.

## Maximum-duration identity

- Maximum-duration identity is durable. Failure and relaunch preserve it;
  explicit Retry success promotes the same row to `Saved and transcribed`
  without deleting audio or creating a normal accepted row.
- Identity is tied to protected audio before provider work. If main index write
  fails after copy, app-owned filename or bounded checkpoint metadata restores
  it rather than treating the attempt as ephemeral.
- Provider work starts only after app-owned recovery audio has a durable dispatch seal.
- If copy or seal fails, provider Retry stays hidden; the row offers Play,
  Delete, and local Retry Save/Repair. Provider Retry appears only after repair;
  repeated repair failure never uploads the emergency original.

## Ownership and retention

- Successful maximum-duration audio remains protected and playable until
  explicit Delete or bounded recovery pruning.
- Unresolved positive-byte attempts are never silently evicted.
- Quitting preserves accepted entries, unfinished recordings, successful
  maximum-duration rows, and compact recovery metadata.
- Cancelled recordings and pre-capture setup failures create no History row.
- If temporary audio cannot be saved, show immediate provider failure without
  fake Retry and skip destructive cache cleanup so recovery remains possible.

## Dependencies

- [Transcript History](../transcript-history.md) — shared recovery invariants.
- [Recording durability](../recording-durability-and-interruption.md) — ownership and destructive authority.
