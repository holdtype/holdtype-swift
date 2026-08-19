# Keyboard Utilities And Fixes

- Node type: leaf
- Status: Active
- Contract: `holdtype.ios.keyboard-experience.utilities@1`
- Read when: Quick Insert, editing controls, Latest/History, or Fixes workspace matters.
- Do not read when: only Voice phase or transport matters.
- Maximum size: 100 physical lines.

Quick Insert leading unit uses smile in Voice/close in workspace, one-tap direct
toggle, no chooser/title. Punctuation is `. , ? ! : ; — …`; bundled Unicode
emoji are `🙂 😂 ❤️ 👍 🙏 🔥 ✅ ✨ 😊 😍 🤔 👏 💯 🎉 🚀 👀`, not Apple/user Library.
Each target ≥44, exactly one local insertion, then close to underlying Voice.
Rows may horizontal-scroll; compact landscape may combine emoji rows.

It works/opens through every phase without provider/network/mic/Full Access,
temporarily covers but never changes dictation/recovery; refresh does not close.
Space tap inserts; long-press/drag moves cursor without space. Delete tap/repeat
accelerates boundedly. Return follows public traits and width grows/shrinks,
single-line. Globe uses system API. Local controls plus available restricted
Latest remain useful without setup.

`Latest` explicitly inserts first accepted-History row while it exists, no
independent expiry; it is not private Latest and cannot expose/clear it. History
opens canonical app destination; no rows/previews/actions enter extension, and
launch remains platform/App Review gated.

Fixes is one-tap, mutually exclusive with Quick Insert. Native icon/title tiles:
Translate, Fix, then enabled custom durable order; one/two scrolling rows, ≥44,
truncate visual title only. Never render source/field/prompt/result. Use host non-
empty selection; complete-field only after signed host gate. Nil/partial/oversize/
secure/phone/changed/uncertain starts nothing. App consent/key/routes/private
prompts apply via Full Access transient bridge. Chosen tile shows bounded progress;
ignore more taps; failure/stale leaves host unchanged/workspace open. Active Voice
keeps Fixes visible but disabled and never interrupted. Refresh does not dismiss.
