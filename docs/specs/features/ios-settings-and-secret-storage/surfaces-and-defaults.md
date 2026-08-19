# iOS Settings Surfaces And Defaults

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.settings.surfaces@1`
- Read when: Settings navigation, ownership, or documented defaults matter.
- Do not read when: only persistence encoding or Keychain transaction matters.
- Maximum size: 100 physical lines.

SwiftUI app owns Settings: iPhone stack, iPad sidebar/detail. System Settings is
only microphone/keyboard/default/Full Access via public versioned URLs plus
written fallback, never private `prefs:`. Library content uses list/detail.
Show only working features.

OpenAI is a detail. Root opening does no marker/Keychain work; each detail
appearance refreshes marker-only status and first starts event observation,
never Keychain. Keychain reads only explicit mutation or `Check Saved Key`.
Privacy detail may read consent metadata/public microphone status but never
capture/request permission/read Keychain/contact provider. Consent is separate,
never general settings/Library/App Group/snapshot. Storage & Recovery mutates
dedicated History policy and opens without provider/Keychain/mic/bridge work.

Defaults: `gpt-transcribe`; language Auto; empty custom code/prompt/dictionary;
emoji on with English; no Nearby Text; correction off, model `gpt-5.5`, standard
conservative prompt; cleanup on; no replacements; Translation source same as
transcription, override/target unconfigured, model `gpt-5.4-mini`, standard
prompt; automatic matching-target insertion on; Latest on; cues on; tail Off;
recording max 5 minutes selectable 1–15; no Quick Session; History on; cache off,
enabled default newest 20 with explicit unlimited; Fixes Translate, Fix, Improve
Writing, Make Shorter, Summarize, Bullet Points, Casual, Markdown.

Phase-0 `en-US` metadata is not typing/product language. V1.1 has no alphabetic
layout/dictionaries; transcription language remains app-owned.
