# Historical iOS Accepted Output And App Actions

- Node type: leaf
- Status: Historical
- Read when: tracing pre-V1.1 output normalization or explicit app actions.
- Do not read when: defining current Voice Draft, Latest, or History behavior.
- Maximum size: 100 physical lines.

Only trimmed non-empty final normal/corrected text, or successful translated
text, became one accepted output for its session/transcript identity. Provider
duplicates could not create another output; raw responses, prompts, audio,
keys, host text, pre-correction text, and failed translation were excluded.

The runtime adapter received exactly one validated transcript plus captured
preferences. Automatic-insertion preference was intent, never eligibility or
authorization; Keep Latest was intent, never durability proof. The request was
transient, non-Codable, and carried no identity, recovery, acknowledgement, or
platform result.

Copy and Share were explicit and did not acknowledge/consume insertion. Use in
Practice changed only HoldType-owned draft text. Clear Latest required confirmed
revocation and History-work disposition; uncertainty retained recovery. History,
Latest, Copy, Share, insertion, and retention were independent. Empty output,
cancelled Share, or failed Copy left prior accepted state unchanged.

Legacy defaults enabled target-matched automatic insertion and Latest retention,
but neither bypassed safety gates. Translation setup failures routed to the
owning setting before output work. Current V1.1 contracts supersede these
defaults and app-action arrangements.
