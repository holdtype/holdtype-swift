# AGENTS.md

This file adds repository-specific routing and constraints to the inherited
global agent, product-truth, and orchestration rules. It does not restate those
global contracts.

Detailed HoldType behavior lives in `docs/specs/`, selected through
`docs/specs/index.md`.

## Repository Context

`holdtype-swift` is a native macOS menu bar dictation utility. The app records
microphone input, sends audio to OpenAI transcription, and inserts returned
text into the current active app.

The repository contains macOS and in-progress iOS implementation code, tests,
specs, backlog workflows, and automation runbooks.

## Local Document Routing

Read the smallest project-specific file set required by the current action:

- `docs/specs/index.md` is the specification registry. Use it to select the
  exact active product contracts required by the global product-truth gate.
- `SWIFT.md` governs Swift, SwiftUI, AppKit adapter, Xcode project, and test
  changes. For product work, read it after the provisional product-contract
  basis; for behavior-neutral Swift work, read it before opening or editing
  those implementation paths.
- `docs/specs/brownfield-discovery.md` is the current repository map when
  source ownership is unclear.
- `BACKLOG_DEVELOPMENT.md` applies only to explicit backlog work, scheduled
  backlog automation, backlog scripts/runbooks, or backlog-file maintenance.
- `docs/specs/backlog.md` applies only when grooming or selecting product
  areas.
- `docs/agent-tooling.md` applies when choosing Xcode, simulator, device,
  runtime-QA, MCP, or Computer Use tooling.
- `docs/openwhispr_swiftui_codex_tz.md` is fallback source evidence only when
  an initial MVP behavior is not settled by a current contract.
- `docs/openwhispr-reference-retirement.md` records the boundary for the
  removed OpenWhispr snapshot.

Before any iOS Simulator, iPhone Mirroring, or signed physical-device runtime
QA, read and follow `iOS Simulator, Mirroring, And Physical Device QA` in
`docs/agent-tooling.md`.

## Mandatory UI Skill Gate

This gate applies to every interface task: UI design, layout, visual polish,
interaction changes, UI bug investigation, accessibility work, and runtime
visual QA. It applies before inspecting UI implementation code or proposing a
visual solution.

- For macOS UI work, read and use `build-macos-apps:swiftui-patterns`.
- For iOS UI work, read and use `build-ios-apps:swiftui-ui-patterns`. When
  running or debugging the iOS interface, also use
  `build-ios-apps:ios-debugger-agent`; use the other Build iOS Apps skills when
  their specialized surface applies.
- State in the first UI progress update which skill applies and why. Follow the
  selected skill's interaction, state-ownership, component, and verification
  guidance throughout the task.

### Mandatory Computer Use For UI QA

For every macOS or iOS task that changes a visible interface or interaction,
agents must use the [@Computer](plugin://computer-use@openai-bundled) plugin
for the runtime QA pass whenever it is available in the session. The agent
must inspect the actual app, perform the changed action by clicking or keyboard
interaction, and inspect the resulting screen. Do not replace this with
AppleScript, `osascript`, JXA, CGEvent synthesis, or an unattended
screenshot-only check.

An alternative verification path is allowed only when
[@Computer](plugin://computer-use@openai-bundled) is unavailable or cannot
perform the specific interaction after a bounded attempt. Record the concrete
limitation and use the narrowest non-AppleScript fallback.

## Local Apple UI Exceptions

### Narrow Fixes Popup Exception

The user approved one narrow exception on 2026-08-05 for the macOS Fixes
palette and its unavailable-feedback dialog: their presentation shell may use
an AppKit `NSPanel` only to preserve non-activating interaction with a captured
external text target and global click-outside dismissal. Every visible popup
view, its controls, layout, state, and feedback content must remain SwiftUI.
This exception does not permit AppKit in Manage Fixes, editor content, or any
other visible product surface.

### Existing Native Dialog Maintenance

Working AppKit alerts, sheets, and confirmation dialogs, including Quit, may
receive targeted maintenance fixes that preserve their existing focus,
modality, and termination behavior. This maintenance rule does not authorize a
new AppKit surface or a substantial redesign. New or substantially redesigned
visible interfaces must follow the inherited SwiftUI boundary.

## Direct Chat Work Versus Backlog Work

Ordinary user requests in a live chat are direct tasks. Do not create backlog
tasks or run the selector unless one of these conditions applies:

- the user explicitly asks to use, create, select, decompose, groom, archive,
  or execute backlog tasks;
- a scheduled automation or installed runbook identifies the run as backlog
  work;
- the request maintains backlog files, scripts, or runbooks;
- the user and agent explicitly agree to make a long effort restartable
  through committed backlog tasks.

If a direct task needs later follow-up, report it in chat. Create durable
backlog entries only with user approval or when the active automation requires
them.

## Landing And Marketing Fast Lane

Landing-page and marketing work is a narrow, low-context workflow for copy,
static HTML/CSS, social metadata, images, campaign assets, and asset
organization under `website/`, `marketing/`, and `docs/marketing/`.

- Read only this file plus the exact landing or marketing files required.
- Do not load Swift architecture, feature specs, app tests, backlog bodies, or
  unrelated history.
- Do not run Xcode builds, Swift/package tests, the full website suite, app
  runtime checks, deployment dry-runs, or repeated preflights unless the user
  asks for that verification.
- Use a quick artifact check when useful, such as image dimensions, metadata,
  or `git diff --check`.
- When the user says to publish, make the requested change, create the scoped
  checkpoint commit on `master`, and push it. If a safe direct `master` push is
  impossible, follow the Master-Only Git Policy and ask the user.

## Backlog Development

`BACKLOG_DEVELOPMENT.md` is the project workflow for explicit backlog work,
scheduled backlog automations, grooming, and user-requested restartable queues.
Read it before opening detailed task bodies.

Agents may shallow-scan backlog headers during selection but must not read a
non-selected task body. Prefer compact selector output:

```sh
python3 scripts/backlog_next.py --compact-json
```

Use `python3 scripts/backlog_next.py --json` only when compact output lacks the
diagnostics required for the current decision. Sequential automation uses the
canonical checkout, not chat memory, as task-state authority.

## Master-Only Git Policy

Agents must work only on the repository's existing `master` branch. Never
create or switch to another branch, create a branch-backed worktree, push a
non-`master` ref, force-push `master`, or rewrite its history.

Commit and push task changes directly on `master`, staging only task-owned
paths. A dirty, ahead, behind, or diverged `master` is not permission to create
an alternate branch. If a safe direct commit or fast-forward push cannot be
completed, stop and ask the user how to proceed.

## Dirty Git State Is Never A Blocker

Dirty state is normal in this repository. Inspect relevant diffs, preserve
existing changes, work against current contents, and use path-limited staging
and commits such as `git add <owned paths>` and `git commit --only <owned
paths>`.

Do not revert, reset, clean, stash, or include unrelated changes unless the
user explicitly requests that exact Git operation. Do not add or follow a
project workflow that treats dirty Git state as a stop condition.

## Checkpoint Commits

Every task-solving chat that changes repository files must create a checkpoint
commit before the final response. Stage and commit only paths owned by the
current task. Leave unrelated changes untouched and mention them in the final
response.

Automation runs and bounded worker iterations follow the same rule: finish
required status updates and verification, then create a scoped checkpoint
commit before reporting completion or handing off.

## Local Engineering Boundary

- `docs/specs/` contains HoldType product contracts.
- `SWIFT.md` contains Swift and Apple-platform engineering rules.
- `BACKLOG_DEVELOPMENT.md` contains queue mechanics.
- tests and QA artifacts contain verification evidence.
- `AGENTS.md` contains only repository routing and local agent constraints.

All Swift implementation must follow `SWIFT.md`. A necessary exception must be
small, isolated, and explained in review or the final response.

## Verification

For macOS UI tests, Computer Use, or automated runtime QA, follow
`docs/qa/macos/AGENTS.run.md` and these repository-wide additions:

- start a scoped `caffeinate` guard before the first UI action and stop it when
  the UI session finishes;
- launch HoldType with live Keychain access disabled, normally through
  `script/build_and_run.sh --verify`;
- never enter the macOS login keychain password or click `Always Allow` during
  automation;
- close and verify exit of every run-owned HoldType process before the final
  response without terminating an instance the run did not launch;
- do not use `script/build_and_run.sh --live-debug` for automation unless the
  user explicitly requests a live OpenAI debug session.

iOS runtime evidence must keep Simulator, iPhone Mirroring, and signed physical
device lanes separate as defined in `docs/agent-tooling.md`.

For Swift behavior changes, the baseline verification is:

```sh
xcodebuild -project HoldType.xcodeproj -scheme HoldType -destination 'platform=macOS' build
git diff --check
```

Run the matching test command when tests or test-covered behavior change. For
docs/spec-only changes, `git diff --check` is normally sufficient unless an
edited executable command should be exercised.

## Retired OpenWhispr Reference

Do not restore or require a `references/` checkout for normal development,
grooming, investigation, or verification. Historical backlog citations to the
removed snapshot preserve provenance only; they are not executable reading
instructions or current product authority.
