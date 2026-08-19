# Historical iOS History Policy And Presentation

- Node type: leaf
- Status: Historical
- Read when: tracing the retired accepted/failed History product model.
- Do not read when: defining current V1.1 text-only History.
- Maximum size: 100 physical lines.

Legacy History was local/default-on with at most 20 accepted and five failed
rows. Its strict app-private policy record owned enabled state and a monotonic
generation. Clear/disable/re-enable committed a new generation before bounded
cleanup; old rows disappeared immediately and could not resurrect. Recording
Cache was separate, off by default, last-10 by default when enabled, with an
explicit unlimited option. Nothing synced to cloud.

Rows were newest-first. Accepted rows exposed text/time/model/language/duration
and explicit Copy/Share/Delete/conditional Play. Failed rows exposed compact
reason/stage/retry count and explicit Retry/settings. Retry re-resolved current
settings, Library, consent, credentials, and intent; it never auto-inserted,
auto-uploaded on relaunch, or reused stored secrets/provider payload/context.

One process-owned service/state owner produced a generation-consistent snapshot
for all scenes. Loading, empty, disabled, ready, pending recovery, unreadable,
and mutation-failed were distinct; corrupt/unavailable state never appeared
empty. Views never opened repositories or received paths/capabilities.

History Play/Retry were excluded during active voice/Pending work; only one
playback/retry ran, new recording stopped playback, and destructive actions on
the active item were disabled. Provider-free browse/Copy/Share/Delete/Clear/
toggle stayed independent of OpenAI consent. P5H activation/disclosure/UI train
was non-release-qualified and is not current.
