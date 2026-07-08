---
id: VT-169
status: done
priority: P0
lane: project-config
dependencies:
allowed_paths:
  - AGENTS.md
  - BACKLOG_DEVELOPMENT.md
  - README.md
  - SWIFT.md
  - Shared/**
  - VibeType.xcodeproj/**
  - VibeType/**
  - VibeTypeIOS/**
  - VibeTypeIOSTests/**
  - VibeTypeTests/**
  - VibeTypeUITests/**
  - backlog/**
  - docs/**
  - prompts/**
  - scripts/**
verification:
  - xcodebuild -list -project VibeType.xcodeproj
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test
  - xcodebuild -project VibeType.xcodeproj -scheme VibeType-iOS -destination 'generic/platform=iOS Simulator' build-for-testing
  - git diff --check
---

# VT-169 - VibeType Naming Normalization

Status: done
Priority: P0
Lane: project-config
Dependencies: none
Expected outputs: Xcode/module/source naming migration, docs/tooling updates, verification results
Verification: `xcodebuild -list -project VibeType.xcodeproj`; `xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`; `xcodebuild -project VibeType.xcodeproj -scheme VibeType-iOS -destination 'generic/platform=iOS Simulator' build-for-testing`; `git diff --check`

## Scope

Normalize project-facing names to the brand spelling `VibeType`:

- Xcode project, targets, schemes, products, and Swift module names.
- Source, iOS, and test folder names.
- Swift test imports and generated file headers.
- Forward-looking documentation, runbooks, and active backlog references.

Keep intentional machine identifiers stable unless a future migration
explicitly changes their persistence or external identity contract:

- repository path and automation ids using `vibetype-swift`;
- bundle identifiers such as `potapenko.VibeType`;
- persisted settings, notification, Keychain, temporary-file, and test suite
  keys such as `vibetype.settings.` or `/tmp/vibetype-*`;
- historical completed backlog and QA evidence unless needed for active
  commands.

## Notes

Preserve any pre-existing local edits in `project.pbxproj`, including the
current microphone usage description setting.

## Completion

- Renamed the Xcode project, schemes, app source, iOS source, and test folders
  to `VibeType*`.
- Renamed the macOS module to `VibeType` and set the iOS module explicitly to
  `VibeTypeIOS`.
- Updated Swift test imports, file headers, forward-looking docs, runbooks, and
  active backlog references.
- Kept stable machine identifiers for bundle ids, persistence keys,
  Keychain service names, temporary paths, repo path, and automation ids.

## Verification

- Passed: `xcodebuild -list -project VibeType.xcodeproj`.
- Passed: `python3 scripts/local_tooling_recover_test.py`.
- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType -destination 'platform=macOS' test`.
- Passed: `/opt/homebrew/bin/timeout 300 xcodebuild -project VibeType.xcodeproj -scheme VibeType-iOS -destination 'generic/platform=iOS Simulator' build-for-testing`.
- Passed: `git diff --check`.
