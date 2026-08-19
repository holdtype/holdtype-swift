# Multipart Scratch Orphan Maintenance

- Node type: leaf
- Contract ID: `holdtype.shared.openai-transcription.scratch-maintenance`
- Domain ID: `holdtype.shared.openai-transcription`
- Status: Active
- Stability: Accepted
- Contract revision: `holdtype.shared.openai-transcription.scratch-maintenance@1`
- Read when: startup orphan cleanup, scratch filename grammar, age, lock, or work budgets are in scope.
- Do not read when: only live request creation, provider response, or recovery UI is in scope.
- Maximum size: 100 physical lines.

## Startup hook and namespace

- Each normal containing-app process schedules one async non-blocking pass over
  only `<temporary-directory>/holdtype-openai-multipart/`; missing namespace is
  no-op and never created.
- Hook takes/returns no content, filenames, counts, errors, URL, or payload;
  starts no provider/Keychain/audio work; schedules at most once.
- macOS calls it after excluding one-shot Input Monitoring recovery launch; iOS
  containing app calls during initialization; keyboard has no HoldTypeOpenAI link.
- Namespace is opened no-follow and processed only when effective-user-owned
  `0700`; never repaired, recursed, or enumerated outside same descriptor.

## Candidate grammar and safety

- v1 name matches exact ASCII
  `htmp-v1-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}.multipart`
  plus exact two-byte `v1` xattr. Legacy/staging matches exact
  `[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}.multipart`.
- Marked/unmarked legacy use 24-hour rule. Lowercase legacy-like, malformed,
  unmarked v1, wrongly marked, nested, or unrelated entries remain untouched;
  UUID parsing alone is not the grammar.
- Candidate must be no-follow regular effective-user-owned `0600`, one link,
  nonnegative size, and grant non-blocking exclusive lock.
- Immediately before descriptor-relative unlink, repeat descriptor/path identity,
  type, owner, mode, link, size, age, budget and v1 descriptor-xattr checks.
  Symlink, directory, hard link, active file, and raced replacement survive.

## Age and work budgets

- Age uses newer mtime/ctime and one captured wall time at nanosecond precision.
  v1 eligible exactly at one hour; legacy exactly at 24 hours; future untouched.
- One pass inspects at most 256 non-dot entries, removes at most 32 files, and
  charges at most 512 MiB logical final `st_size`; exact boundaries allowed,
  would-exceed candidate stays and ends pass.
- One-second monotonic work budget is checked before each new enumeration/open/
  metadata/lock/attribute/delete syscall. At elapsed ≥1 second none starts;
  descriptor cleanup still runs and one started syscall may finish later.
- Any namespace/entry/attribute/clock/removal error fails closed; launches and
  provider continue. API/logs emit no name/path/size/content. Repeated passes are idempotent.
- An old owner-only file deliberately placed in this private namespace with the
  exact legacy grammar is indistinguishable from a legacy orphan and is not
  claimed as a protected source recording.
- Private-sandbox same-UID final interposition remains outside claimed guarantee.

## Dependencies

- [OpenAI transcription](../openai-transcription.md) — shared scratch privacy.
