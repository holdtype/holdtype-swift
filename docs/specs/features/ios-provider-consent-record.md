# iOS Provider Consent Record

- Node type: hybrid
- Status: Historical strict-schema reference
- Read when: reviewing legacy consent wire/CAS/gate/durability evidence.
- Do not read when: treating disclosure v1/v2 or History capability as current.
- Maximum size: 100 physical lines.

V1.1 retains provider-stage authorization in a standalone versioned record but
current release/disclosure supersedes the old History-aware context.

## Children

- [Record and presentation](ios-provider-consent-record/record-and-presentation.md)
  — strict v1 bytes, disclosure evidence, passive observations.
- [Mutation and authorization](ios-provider-consent-record/mutation-and-authorization.md)
  — epoch/revision CAS, fence, launch/result one-shot gate.
- [Storage and verification](ios-provider-consent-record/storage-and-verification.md)
  — protected durability, canonical root, invariants, acceptance matrix.

## Precedence

- [Current V1.1 release](ios-v1-release.md) governs current disclosure and data paths.
