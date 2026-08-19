# Deferred Failed History Product Model

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing proposed failed-row behavior and failure classification.
- Do not read when: exposing failed History in current V1.1.
- Maximum size: 100 physical lines.

Failed History was app-only/local/durable with five newest recoverable attempts.
A row retained original time, retry count, model/language/duration, intent,
compact reason, and protected audio. Retry was explicit, single-owner, current-
configuration/current-consent/current-credential work; relaunch and lifecycle
performed no provider call.

Retry required enabled matching History generation, valid audio, idle Voice/
provider chain, one reserved cleanup-tombstone slot, current setup/consent, and
an empty accepted-History outbox head. Setup/consent failure routed to its owner
without changing row/count. Standard/Translation intent was preserved;
automatic insertion was forced off and intermediate translation text never
became success.

Only transcription or translation failures could persist. Stable payload-free
categories covered credential, network, timeout, rate limit, provider,
invalid/empty response, and echo rejection. Status codes, localized/raw errors,
unknown cases, prompts, keys, content, and nearby context were never stored.
Correction failures were fail-open; capture/media/request/output-delivery and
unmapped failures stayed with their owning recovery contract.

Delete/Clear/Disable made rows logically unavailable before bounded audio
cleanup; cleanup failure never rolled back that boundary. Retry failure kept
row/audio and advanced count once only when reservation had committed; cancel
or consent loss rejected late output and preserved prior recoverable state.
