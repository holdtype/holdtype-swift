# Deferred Keyboard Settings Schema And Privacy

- Node type: leaf
- Status: Historical; Deferred
- Read when: tracing the proposed static keyboard snapshot schema.
- Do not read when: using it as current extension settings authority.
- Maximum size: 100 physical lines.

The app alone wrote one immutable atomically replaced App Group file; extension
was read-only even with Full Access. It was separate from sessions, commands,
acknowledgements, results, and event/wake behavior, and publication never proved
that the extension consumed a revision.

The proposed schema held version, monotonic writer revision, generation time,
and only approved optional layout/locale, capitalization, autocorrection,
predictions, double-space period, haptics, automatic-insertion preference,
translation-action preference, and translation-readiness values. Absent fields
used bundled fallback; all app-dependent action fields failed closed to false.
Static values did not expire and never authorized provider work/insertion alone.

It excluded secrets/Keychain, audio/paths/Pending, transcripts/results, prompts/
models/responses/errors, keystrokes/touches/context/host, document/session/acks,
History/usage/retention/consent/diagnostics, dictionary/emoji/replacements, and
complete settings/Library. Required Globe, space-cursor, and safety invariants
were not mutable fields.

Personal lexicon publication remained forbidden. Any future version needed an
explicit normalized schema, limits, disclosure, deletion, refresh, and redaction;
learned host content, prompts, frequency, and surrounding text stayed forbidden.
