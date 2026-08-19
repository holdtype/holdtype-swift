# iOS Usage Repository And Wire Format

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.ios.transcription-usage-estimate@1`
- Clauses: `IOS-USAGE.REPOSITORY`, `IOS-USAGE.WIRE`
- Read when: canonical owner, storage protection, strict JSON, or v1 schema is in scope.
- Do not read when: only aggregation or chart UI is in scope.
- Maximum size: 100 physical lines.

- Composition root owns exactly one process-wide repository actor/read-writer
  and one client shared by Voice, failed-History Retry, and presentation; no
  production convenience initializer creates another canonical-file actor.
- File: app-private Application Support `HoldType/ios-transcription-usage.json`,
  Complete Data Protection, excluded from backup, maximum 4 MiB.
- Before semantic decode, require strict UTF-8 JSON, no BOM, and no duplicate
  object members anywhere. Member identity uses decoded Swift String equality,
  including escaped/literal and canonical-equivalent collisions, without case/
  compatibility normalization.
- Limits: 64 nested containers; 1,024 members/object; 262,144 document members;
  65,536 elements/array; 524,288 values; decoded key 4,096 bytes; number token 256 bytes.
- Over 4 MiB is `sourceTooLarge` before structure. Malformed/duplicate/limit is
  `malformedData`; full structural pass precedes schema/field failure and
  preserves exact source. `load` and `record` share it.
- V1 root is exactly `schemaVersion` + `events`. Every row has seven fields:
  canonical uppercase-hyphen UUID; UTC millisecond ISO-8601
  `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`; canonical model; duration; price/minute; cost;
  pricing source. Three pricing fields are all null for unknown or all present.
