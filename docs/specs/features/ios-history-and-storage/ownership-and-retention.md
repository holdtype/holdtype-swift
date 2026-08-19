# Historical History And Audio Ownership

- Node type: leaf
- Status: Historical
- Read when: reviewing retired destination, cache, and cleanup ordering.
- Do not read when: defining current compact History or Recording Cache.
- Maximum size: 100 physical lines.

Every handoff was staged/idempotent: destination record and relative audio
identity committed before prior journal/source removal. Ambiguous unlink retained
physical identity so retry could prove the original absent but never remove a
recreated pathname. A descriptor-bound removal intent on the exact journal
survived process loss and blocked ordinary replacement/removal until resolved.

Accepted output committed before output publication. History-on used structured
pending marker/outbox ownership; failures were local, non-blocking, provider-
free retry. Cache-off then removed Pending ownership; cache-on copied, atomically
published and committed cache metadata before source/journal deletion. Cache
and accepted row lifetimes were independent.

Recoverable failure with History-on transferred one exact row plus retry audio
before retiring Pending. History-off left the visible Pending Retry/Discard
owner. Cancellation preserved explicit recovery; late responses could not
consume it. Non-retryable/empty/cancelled outcomes followed exact acknowledged
cleanup, while bounded non-empty suspect media remained saved recovery.

History rows, failed rows, Pending, Latest/output, retry audio, usage, and
recording cache had separate retention. App Group never held History/audio;
local files were protected and backup-excluded; logs excluded text/paths/audio.
Policy cleanup, Share/Save failure, storage pressure, and orphan reconciliation
could not silently delete the only valid artifact.
