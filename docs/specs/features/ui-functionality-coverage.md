# UI And Functionality Coverage

- Node type: leaf
- Status: Current resource
- Read when: mapping a selected surface to contract, likely owner, and verification route.
- Do not read when: deciding behavior, implementation status, or backlog state.
- Maximum size: 100 physical lines.

Active specs define intent; current source/tests establish ownership and
implementation; fresh selector output establishes backlog state. Historical
tasks/audits/external citations do none of these. Never recreate retired OpenWhispr.

| Surface | Contract | Ownership hint | Verification route |
| --- | --- | --- | --- |
| Menu shell | `menu-bar-app-shell.md` | app/menu presentation | build + bounded menu runtime QA |
| Settings | `settings-and-secret-storage.md` | Settings views/models | focused tests; Computer Use for visible change |
| Permissions | `privacy-and-permissions.md` | permission/setup services/views | fake states; bounded visible runtime QA |
| Recording | microphone + durability | recorder/session controllers | fake lifecycle; platform capture only when changed |
| Transcription | `openai-transcription.md` | OpenAI services/builder | fake URL/timeout/response; no live automation |
| Output | `text-output-workflow.md` | insertion/session output | fake insertion; bounded active-app QA |
| Hotkey | `global-hotkey.md` | hotkey/settings/session | fake events; runtime registration smoke |
| Indicator | `floating-indicator.md` | indicator view/panel | state tests; focus/visibility QA |
| Session | selected recording/provider/output/recovery specs | runtime/session controllers | focused controller + affected visible flow |
| History | `transcript-history.md` | stores/controllers/History view | persistence/controller; visible History QA |
| Current iOS | `ios-v1-release.md` + exact feature | iOS/keyboard/shared/tests | active iOS platform lane and contract evidence |

Before grooming a row, read its contract, inspect the named current slice, and
use fresh selector output. Update this durable map only for routing/ownership/
verification changes, never transient task or dated implementation status.
