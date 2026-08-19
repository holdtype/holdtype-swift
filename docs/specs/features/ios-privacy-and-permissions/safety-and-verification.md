# Historical Privacy Safety And Verification

- Node type: leaf
- Status: Historical
- Read when: reviewing legacy privacy invariants/failure coverage.
- Do not read when: inferring current consent or release readiness.
- Maximum size: 100 physical lines.

Protected: no hidden capture/provider; independent permissions/consents; no
passive prompt/read; no sensitive bridge/log/diagnostics; stale heartbeat honest;
provider stages fail closed; local/history actions provider-free where specified.
Revoked mic stopped capture and preserved valid recovery/no auto-upload. Revoked
Full Access stopped writes, ignored stale ack, kept typing/fallback. Host rejection
was platform limitation, written fallback remained if Settings failed, missing
manifest/purpose failed release.

Routes separated mic, keyboard guidance, Full Access, key, provider and historical
Quick Session consent. Consent record was content-free; heartbeat TTL five minutes.
Verification covered mic states/timeouts/revocation/public routes; independent
consent/decline/review/data isolation; old v2 transition and failed Retry; stale
Full Access; built manifests/purpose/privacy reports; forbidden-value redaction.
Legal wording/App Store answers stayed release artifacts.
