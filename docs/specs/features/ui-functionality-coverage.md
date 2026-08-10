# UI And Functionality Coverage

## Goal

Keep a durable routing map from HoldType product surfaces and flows to their
active contracts, current source owners, and verification expectations.

This map does not freeze implementation status or backlog state. Agents must
inspect the current checkout and selector output before making those claims.

## Coverage Rules

- Active specs define intended behavior.
- Current HoldType source and tests establish implementation and ownership.
- Current selector output and task headers establish backlog state.
- A historical task, audit, or external source citation is not current product
  authority or proof that behavior is implemented.
- The retired OpenWhispr snapshot must not be recreated for coverage work. Its
  historical role is recorded in `docs/openwhispr-reference-retirement.md`.

## Contract And Ownership Map

| Surface or flow | Governing contract | Current ownership hint | Verification route |
| --- | --- | --- | --- |
| Menu bar app shell | `menu-bar-app-shell.md` | `HoldType/HoldTypeApp.swift`, `HoldType/MenuBarView.swift`, `HoldType/MenuBarPresentation.swift` | macOS build plus bounded menu-bar runtime QA when visible behavior changes |
| Settings surface | `settings-and-secret-storage.md` | `HoldType/SettingsView.swift`, `HoldType/Settings/`, `HoldType/Models/AppSettings.swift` | focused settings/model tests; Computer Use for changed visible controls |
| Permission states | `privacy-and-permissions.md` | `HoldType/Services/PermissionsService.swift`, `HoldType/Services/AppSetupController.swift`, Settings permission views | fake-backed permission tests; bounded runtime QA for visible permission flows |
| Recording lifecycle | `microphone-text-input.md` and `recording-durability-and-interruption.md` | `HoldType/Services/AudioRecorderService.swift`, `HoldType/Services/DictationSessionController*.swift` | fake-backed lifecycle tests plus bounded microphone QA only when platform capture changes |
| OpenAI transcription | `openai-transcription.md` | `HoldType/Services/OpenAI*Service.swift`, `HoldType/Services/OpenAITranscriptionRequestBuilder.swift` | fake URL loading, timeout, and response tests; no live OpenAI calls in automation |
| Text output and paste | `text-output-workflow.md` | `HoldType/Services/TextInsertionService.swift` and dictation controller output owners | fake insertion tests; bounded active-app handoff QA when behavior changes |
| Global hotkey | `global-hotkey.md` | hotkey services, settings models, and dictation controller handoff owners | fake event-stream tests; runtime shortcut smoke when registration changes |
| Floating indicator | `floating-indicator.md` | `HoldType/FloatingIndicatorView.swift`, `HoldType/FloatingIndicatorPanelController.swift` | state-model tests and runtime focus/visibility QA when presentation changes |
| Dictation session controller | microphone, transcription, output, and recovery specs selected through `docs/specs/index.md` | `HoldType/Services/DictationRuntime.swift`, `HoldType/Services/DictationSessionController*.swift` | focused controller tests plus runtime QA for affected user-visible flows |
| Transcript history | `transcript-history.md` | transcript stores, recovery owners, and `HoldType/TranscriptHistoryView.swift` | persistence/controller tests; History UI QA when visible behavior changes |
| Current iOS product | `ios-v1-release.md` plus the feature spec selected for the exact flow | `HoldTypeIOS/`, `HoldTypeKeyboard/`, shared packages, and iOS tests | use the platform lane and evidence required by the active iOS contract |

## Grooming Expectations

Before creating or refining work for a row, the groomer must read its governing
spec, inspect the named current ownership slice, and use fresh selector output.
Update this file only when contract routing, ownership boundaries, or
verification expectations change. Do not write transient task status or a
dated implementation snapshot into this durable map.
