# iOS V1.1 Navigation And Settings

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.v1-release.navigation@1`
- Read when: governing containing-app destinations, launch, or Settings presentation.
- Do not read when: only keyboard UI or persistence details matter.
- Maximum size: 100 physical lines.

## Navigation

The app exposes exactly five useful destinations, ordered `Voice`, `Rules`,
`History`, `Usage`, `Settings`. Voice owns record/Pending/composed Draft while
Latest remains accepted state. Rules opens Dictionary, Emoji Commands,
Replacements, and Fixes. History is successful accepted text. Usage follows
its iOS usage contract. Settings owns provider, language/writing, recording,
privacy, and setup.

Diagnostics & Support is a visually secondary Development route at Settings'
bottom, never another tab or keyboard route. Usage is app-only, not duplicated
in Settings. No destination ships as a placeholder: hide unfinished History
during implementation, but restore it before V1.1 completion.

Voice is first on cold launch/new scene. A backgrounded existing scene keeps
its destination. Voice never previews History.

## Settings content

- Prioritize current state and next action; normally at most one short sentence
  before optional detail. Use product language, never internal state/schema terms.
- OpenAI shows one key field and one human status: not connected, connected, or
  needs attention. The six-state model stays internal; a saved-key mask lives
  inside the replacement field.
- Normal saved key has no check action/banner. Show `Try Again` only when saved
  state cannot be confirmed or unlock is required.
- Privacy & Permissions prioritizes microphone/OpenAI status, not passive
  History/cache policy. Keep concise disclosure detail when provider review is due.
- Model IDs/provider instructions are `Advanced` on the matching editor and do
  not displace language, writing, translation, or recording controls.
- Every valid General Settings change auto-saves: no normal Save/Cancel and no
  navigation block. Invalid/failed input stays visibly unapplied while runtime
  uses the last durable value.
- Default provider instructions are not ordinary editable content; experts may
  add optional instructions or restore standard behavior.
