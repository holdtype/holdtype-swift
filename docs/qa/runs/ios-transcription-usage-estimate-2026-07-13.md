# iOS Transcription Usage Estimate QA

Date: 2026-07-13
Milestone: P5U Transcription Usage Estimate

## Scope

- Add the independent `Settings > Transcription Usage Estimate` route.
- Reuse one portable 30-day summary across macOS and iOS presentation.
- Make foreground Voice, failed-History Retry, Settings, and every scene use
  one composition-owned usage repository and mandatory failure-reporting
  client.
- Preserve accepted output when local usage recording fails.
- Support known, mixed, and unknown local pricing; local refresh; confirmed
  Reset; unreadable-data recovery; and a process-local incomplete-estimate
  warning.
- Keep usage, tokens, repository state, provider work, and recovery entirely
  outside the keyboard and App Group.

## Automated Evidence

- Portable Domain summary strict test run
  - Result: 165 tests in 33 suites passed with warnings as errors.
  - Log: `/tmp/p5u-domain-summary-strict-tests.log`.
- Focused macOS usage-estimate regression
  - Result: 5 tests passed.
  - Log: `/tmp/p5u-macos-openai-usage-estimate-tests.log`.
- Strict Persistence usage repository/client run
  - Result: 24 tests passed with warnings as errors.
  - Log: `/tmp/p5u-persistence-usage-strict-tests.log`.
- Full strict Persistence regression, serialized
  - Result: 1,099 tests in 57 suites passed with warnings as errors.
  - Log: `/tmp/p5u-persistence-strict-serialized-tests.log`.
- Full strict iOS Core regression, serialized
  - Result: 97 tests in 8 suites passed with warnings as errors.
  - Log: `/tmp/p5u-ioscore-strict-serialized-tests.log`.
- Focused current-source iOS simulator run, serialized
  - Result: 33 tests in 5 suites passed on iPhone 16 / iOS 18.1,
    `B12CCB99-5B3D-49A5-8CF2-7976C570D2EB`.
  - Covered state owner, formatter and chart accessibility, qualification
    routes, and the exact production composition graph.
  - Log: `/tmp/p5u-ios-focused-final.log`.
- Full iOS simulator regression, serialized
  - Result: 1,941 tests in 182 suites passed with automation mode enabled and
    Keychain UI disabled.
  - Log: `/tmp/p5u-ios-full-serialized-final.log`.
- macOS shared-code regression
  - Result: the `HoldType` Debug build passed and 441 tests in 50 suites passed
    serially with automation mode enabled.
  - Logs: `/tmp/p5u-macos-build-final.log` and
    `/tmp/p5u-macos-test-final.log`.
- iOS Release boundary
  - Result: generic iOS Simulator Release build passed.
  - Result: all automated bundle checks passed; only the two documented
    processed-App-Group entitlement checks remained manual for a generic
    Simulator signature.
  - Logs: `/tmp/p5u-ios-release-build-final.log` and
    `/tmp/p5u-ios-release-verifier-final.json`.
  - The verifier's 15 unit tests passed after adding usage and qualification
    fixture markers to its fail-closed boundary.

## Ownership And Failure Contract

- The composition test proves both production recording clients are backed by
  the exact repository actor exposed by the composition root.
- A corrupt-file integration path records through failed-History Retry,
  publishes a content-free warning, performs confirmed Reset and its write
  fence, then records through foreground Voice and proves the later failure is
  visible.
- Write tokens contain no usage content and have redacted description and
  reflection. Reset acknowledges only failures at or before its repository
  fence. Counter exhaustion fails closed by treating every terminal-token
  failure as fresh.
- Refresh and Reset are mutually exclusive across scenes. A cancelled refresh
  cannot publish a late success or failure even when its storage closure ignores
  task cancellation. Reset failures preserve the last confirmed summary or the
  unreadable presentation.
- Missing, corrupt, and unsupported storage are never silently replaced with
  empty success. The unreadable surface offers local Retry and confirmed Reset.

## Runtime And Visual Evidence

- iPhone 16 / iOS 18.1, dark appearance, Increase Contrast, maximum Dynamic
  Type
  - All seven routes rendered: empty, known, mixed, unknown, load failure,
    write warning, and reset failure.
  - Known summary and scroll evidence:
    `/tmp/p5u-usage-known-iphone-max-top.jpg` and
    `/tmp/p5u-usage-known-iphone-max-bottom.jpg`.
  - Unknown pricing selected Minutes automatically and retained complete
    duration copy: `/tmp/p5u-usage-unknown-iphone-max.jpg`.
  - The destructive confirmation exposed its complete title, message, Reset,
    and Cancel through the accessibility tree; its message was scrollable at
    maximum Dynamic Type:
    `/tmp/p5u-usage-reset-confirmation-iphone-max.jpg`.
  - Standard-size native hierarchy:
    `/tmp/p5u-usage-known-iphone-standard.jpg`.
  - The ordinary containing-app shell was also relaunched without a DEBUG
    qualification route at standard Dynamic Type; its native Voice, Library,
    History, and Settings inventory remained visible:
    `/tmp/p5u-normal-shell-iphone-standard.png`.
- iPad Pro 11-inch (M4) / iOS 26.0, regular width, light appearance, maximum
  Dynamic Type, `A9A3B96B-3D87-4466-A4EB-94113C91B330`
  - All seven routes rendered and remained vertically scrollable.
  - Evidence:
    `/tmp/p5u-usage-known-ipad-max.jpg`,
    `/tmp/p5u-usage-empty-ipad-max.jpg`,
    `/tmp/p5u-usage-mixed-ipad-max.jpg`,
    `/tmp/p5u-usage-unknown-ipad-max.jpg`,
    `/tmp/p5u-usage-load-failure-ipad-max.jpg`,
    `/tmp/p5u-usage-write-warning-ipad-max.jpg`, and
    `/tmp/p5u-usage-reset-failure-ipad-max.jpg`.
- The DEBUG gallery is side-effect-free. It uses fixed UTC dates, fixed local
  events, and in-memory failures. It does not read Keychain, request microphone
  permission, contact OpenAI, or touch App Group state.

## Privacy And Accessibility

- Summary values provide the complete textual equivalent of the chart.
- Every chart bar exposes a calendar day and formatted Cost or Minutes value.
- Unknown pricing defaults to Minutes instead of presenting an apparently empty
  Cost chart. Mixed and unknown warnings state the limitation without depending
  on orange color.
- Summary rows stack at accessibility sizes. Refresh, warning Dismiss, Reset,
  Reset confirmation, failure Retry, and chart metric remain named controls.
- Very small positive durations/costs render as `<0.1 min` or `<$0.0001`, never
  as zero.
- Runtime and automated checks used no real API key, live Keychain item,
  microphone, audio session, provider request, transcript, prompt, dictionary
  content, or raw audio.
- The Release verifier rejects usage repository, estimate, storage filename,
  and qualification-fixture markers from the keyboard bundle and rejects the
  qualification fixture from the containing-app Release bundle.

## Review Assessment

Independent architecture, state-machine, UX, accessibility, and test reviews
found and drove fixes for the second-repository ownership defect, late warning
after Reset, unreadable-source Reset, cancellation-insensitive refresh,
confirmation concurrency, unknown-cost chart default, small positive-value
formatting, warning contrast, and counter-exhaustion behavior. After those
fixes, no unresolved P0-P2 finding remained.

## Assessment

P5U passes as an independent containing-app slice. It does not claim provider
billing truth and does not advance the keyboard, Full Access, Quick Session,
History presentation, or physical-device release gates. P4D-2C/P4D-5B remain
open; the next P5 work must keep failed-row Retry hidden until its consent-v2
and neutral-reader prerequisites are complete.
