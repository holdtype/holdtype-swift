# Dev Vlogs Persistent Goal Registry

Status: active

Goal thread: `019fe09f-e938-7bb3-b984-dd3ac4f05848`

Started: 2026-08-08

Governing plan: [`docs/dev-vlogs-implementation-plan.md`](dev-vlogs-implementation-plan.md)

Pinned contract: [`docs/specs/features/dev-vlogs.md`](specs/features/dev-vlogs.md),
revision `DV-DRAFT-4`, checkpoint `2f3266a`.

## Restart Gate

After every start, resume, clear, or context compaction, `/root` must read the
active persistent goal, `AGENTS.md`, `root-orchestration.md`,
`product-truth-governance.md`, the governing plan, the current Dev Vlogs
contract, and this registry before dispatching or accepting goal work.

Chat memory, summaries, live worker state, and earlier green checks do not
replace this pass.

## Scope Guard

The goal ends after accepted Phase 4 local Build, Export, and macOS Share.
Direct publication adapters and every other deferred item in the governing plan
are outside the goal.

No packet may improve, refactor, redesign, or clean up an adjacent product or
shared owner beyond the smallest change proven necessary for Dev Vlogs. The
protected domains are ordinary dictation, transcription and output, Transcript
History, Recording Cache, shared Settings, Keychain, diagnostics, updates,
unrelated menu behavior, all iOS behavior, and website/marketing.

Real technical blockers remain visible. A worker must return the exact
dependency or environment residual rather than weaken the contract, invent a
fallback, or broaden scope.

## Accepted Decisions

The user accepted `DV-D01` through `DV-D13` on 2026-08-08. Their original
Draft integration is `DV-DRAFT-3@ed108fa`; the later native-source decision is
integrated and independently accepted in `DV-DRAFT-4@2f3266a`. The contract is
still Draft evidence, not an Active product implementation epoch.

On 2026-08-08 the user superseded the fixed 720p/30 source-quality part of
`DV-D05`: HoldType must preserve the camera/macOS-negotiated source without an
app-imposed resolution/FPS downgrade or extra source-video recompression. The
exact Build fallback when passthrough is impossible remains a pending material
decision, but it does not block a source-only contract delta. Affected
capture/runtime packets are stale until `DV-DRAFT-4` records and independently
reviews the new source rule. Native 1080p or another negotiated format is not a
new HoldType preset or control; HoldType simply does not downsample it.

## Contract Epoch

| Epoch | Authority | Status | Notes |
| --- | --- | --- | --- |
| `DV-DRAFT-2@8081c10` | Earlier discovery draft | superseded | Replaced after the accepted decisions were integrated and reviewed. |
| `DV-DRAFT-3@ed108fa` | Prior decision-complete discovery draft plus Phase 0B protocol | superseded | Source-quality clauses replaced by accepted DV-DRAFT-4; unaffected accepted evidence remains recorded. |
| `DV-DRAFT-4@2f3266a` | Native-source-quality Draft revision | current | Accepted for source evidence; final Build fallback remains explicitly pending. Product implementation is still unauthorized. |
| `DV-ACTIVE-1` | Future reconciled Dev Vlogs and adjacent active specs | pending | Required before Phase 1 product implementation. |

## Packet Registry

| Packet | Owner | Contract epoch | Dependencies | Writable scope | Status | Receipt | Residual / next dependency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DV-G0-REGISTRY` | `/root` | `DV-DRAFT-2@8081c10` | none | registry; plan registry link | accepted | recorded below | Dispatch `DV-P0A-SPEC`. |
| `DV-P0A-SPEC` | `/root/dv_p0a_spec` | `DV-DRAFT-2@8081c10` | `DV-G0-REGISTRY` | Dev Vlogs spec; Phase 0B protocol | accepted | `ed108fa` | Decision-complete `DV-DRAFT-3` produced. |
| `DV-P0A-REVIEW` | `/root/dv_p0a_review` | `DV-DRAFT-3@ed108fa` | `DV-P0A-SPEC` | read-only | accepted_with_residual | recorded below | Phase 0B quantitative evidence and UI skill remain expected residuals. |
| `DV-P0B-CAPTURE-E01` | `/root/dv_p0b_capture_map` | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | read-only capture/source/platform evidence | accepted_with_residual | recorded below | Debug-only capture spike feasible; shipping audio lease remains Phase 0C work. |
| `DV-P0B-STORAGE-E01` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW` | read-only storage/source/platform/environment evidence | accepted_with_residual | recorded below | Test-only storage spike feasible; physical disconnect/read-only cells remain environment residuals. |
| `DV-P0B-E01-REVIEW` | `/root/dv_p0b_e01_review` | `DV-DRAFT-3@ed108fa` | both E01 maps | read-only | accepted_with_residual | recorded below | Writable capture/storage packets must be serialized and keep distinct QA run roots. |
| `DV-P0B-CAPTURE-W01` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-3@ed108fa` | accepted `DV-P0B-E01-REVIEW` | exact Debug-only capture paths from accepted E01 map | accepted_with_residual | `9d9efec`, repair `ff70155`; receipts below | Debug/fake/build feasibility accepted; real hardware/media evidence and shipping audio lease remain. |
| `DV-P0B-CAPTURE-W01-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-W01@9d9efec` | read-only | rejected | recorded below | Return exact four blockers to the original owner; runtime/storage remain blocked. |
| `DV-P0B-CAPTURE-W01-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | repair `ff70155` | read-only | accepted_with_residual | recorded below | Storage is dependency-ready; hardware remains a separate controlled runtime gate. |
| `DV-P0B-STORAGE-W01` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | accepted `DV-P0B-CAPTURE-W01@ff70155` | two exact storage test files; one redacted QA summary; marker-verified internal temp roots | accepted_with_residual | `2486b56`, repair `69b2d16`; receipts below | Internal bookmark/capacity/promotion/cleanup evidence accepted; external/media runtime remains. |
| `DV-P0B-STORAGE-W01-REVIEW` | `/root/dv_p0b_storage_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-STORAGE-W01@2486b56` | read-only | rejected | recorded below | Return exact safety/claim repairs to original owner; external/runtime work remains blocked. |
| `DV-P0B-STORAGE-W01-REVIEW-R1` | `/root/dv_p0b_storage_w01_review` | `DV-DRAFT-3@ed108fa` | repair `69b2d16` | read-only | accepted_with_residual | recorded below | Controlled external/runtime evidence may be packetized separately. |
| `DV-P0B-CAPTURE-R01` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-3@ed108fa` | accepted capture/storage W01 repairs | one redacted capture-R01 QA run; raw media in exact temporary run root only | accepted_with_residual | `f698fcb`; receipts below | All camera classes terminal not_available; preflight only, no capture/media claim. |
| `DV-P0B-CAPTURE-R01-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-R01@f698fcb` | read-only | accepted_with_residual | recorded below | Retry capture only when an explicit camera uniqueID enumerates. |
| `DV-P0B-CAPTURE-R02` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-3@ed108fa` | accepted R01 preflight; user reports iPhone connected/prepared | one redacted capture-R02 QA run; raw media in exact temporary run root only | accepted_evidence / functional_fail | `0e21972`; receipts below | Repair typed camera-start evidence and bounded termination before retry. |
| `DV-P0B-CAPTURE-R02-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-R02@0e21972` | read-only | accepted_with_residual | recorded below | Evidence is sound; functional cell remains fail/debug-spike defect. |
| `DV-P0B-CAPTURE-R03` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-3@ed108fa` | accepted `DV-P0B-CAPTURE-R02-REVIEW` | exact Debug launch/camera/event/test/script paths | accepted_with_residual | base `8b0b263`; repairs `1276283`, `ba058f8`, `f141be6`; receipts below | Typed category and bounded termination accepted; real hardware/media remains. |
| `DV-P0B-CAPTURE-R03-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-CAPTURE-R03@8b0b263` | read-only | rejected | recorded below | Return classifier-only repair to original owner; no hardware/storage dispatch. |
| `DV-P0B-CAPTURE-R03-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | classifier repair `1276283` | read-only | rejected | recorded below | Return propagation-only repair to original owner; accepted lifecycle/script blobs remain protected. |
| `DV-P0B-CAPTURE-R03-REVIEW-R2` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | propagation repair `ba058f8` | read-only | rejected | recorded below | Return explicit-stop context ordering/test repair; no hardware/storage dispatch. |
| `DV-P0B-CAPTURE-R03-REVIEW-R3` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-3@ed108fa` | stop-context repair `f141be6` | read-only | accepted_with_residual | recorded below | One controlled Continuity retry is dependency-ready. |
| `DV-P0B-CAPTURE-R04` | unassigned | stale `DV-DRAFT-3@ed108fa` quality clauses | accepted `DV-P0B-CAPTURE-R03-REVIEW-R3` | one redacted capture-R04 QA run; raw media in exact temp root only | retired before dispatch | — | User superseded fixed 720p/30 source quality; redefine only after DV-DRAFT-4 review. |
| `DV-P0A-QUALITY-SPEC` | `/root/dv_p0b_capture_map` | `DV-DRAFT-4@2f3266a` | explicit user native-source decision | Dev Vlogs spec; Phase 0B protocol; governing plan only | accepted_with_residual | `2f3266a`; receipt below | Source delta accepted; Build fallback remains separate. |
| `DV-P0A-QUALITY-REVIEW` | `/root/dv_g0_registry_review` | `DV-DRAFT-4@2f3266a` | `DV-P0A-QUALITY-SPEC` | read-only | accepted_with_residual | recorded below | Revalidate affected capture/media packets; Build remains gated. |
| `DV-P0A-BUILD-QUALITY-DECISION` | user decision | future Build clause | source-only `DV-DRAFT-4`; Build evidence later | no writable scope | pending | — | Decide whether incompatible sources permit one final no-downscale/no-FPS-reduction encode or make Build fail; does not block source capture evidence. |
| `DV-P0B-CAPTURE-E03` | `/root/dv_p0b_capture_map` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0A-QUALITY-REVIEW` | read-only exact Debug harness/test/script/QA revalidation | accepted_with_residual | receipt below | Passthrough-preserving Debug repair is feasible; realized hardware compatibility remains evidence-needed. |
| `DV-P0B-CAPTURE-W02` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAPTURE-E03` | exact Debug camera/finalizer/probe/preservation/launch/event, focused tests, W01 summary | accepted_with_residual | `f7ff6bf`; receipt below | Native-source Debug repair accepted; real device/media evidence remains. |
| `DV-P0B-CAPTURE-W02-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAPTURE-W02@f7ff6bf` | read-only exact 13-path commit | accepted_with_residual | receipt below | Controlled DV-DRAFT-4 hardware/runtime evidence is dependency-ready. |
| `DV-P0B-CAPTURE-R05` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAPTURE-W02-REVIEW` | one redacted capture-R05 QA run; raw media in exact internal temporary run root only | accepted_evidence / functional_fail | `11cb9a2`; receipt below | Explicit Continuity selection passed; camera permission remained notDetermined before camera start. |
| `DV-P0B-CAPTURE-R05-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAPTURE-R05@11cb9a2` | read-only exact eight-file evidence commit | accepted_with_residual | receipt below | Same signed Debug identity needs one genuine bounded Camera request before capture retry. |
| `DV-P0B-CAMERA-AUTH-W01` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAPTURE-R05-REVIEW` | exact Debug launch/event permission seam, focused tests, existing spike script, W01 summary | accepted_with_residual | `5b3ed20`; receipt below | Same-identity bounded requestAccess seam accepted; genuine prompt remains. |
| `DV-P0B-CAMERA-AUTH-W01-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-W01@5b3ed20` | read-only exact six-path commit | accepted_with_residual | receipt below | One bounded signed Debug permission invocation is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-R01` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-W01-REVIEW` | one redacted capture-auth-R01 QA run; no media | rejected | `4f0efb5`; receipt below | Runtime facts accepted provisionally, but summary overclaims unchanged TCC state. |
| `DV-P0B-CAMERA-AUTH-R01-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R01@4f0efb5` | read-only exact seven-file evidence commit | rejected | recorded below | Summary-only truthfulness repair required before permission action. |
| `DV-P0B-CAMERA-AUTH-R01-R1` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | rejected AUTH-R01 review | exact capture-auth-R01 summary only | accepted_with_residual | `308a191`; receipt below | Summary contradiction repaired; permission state remains unknown. |
| `DV-P0B-CAMERA-AUTH-R01-REVIEW-R1` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | repair `308a191` | read-only exact one-path repair commit | accepted_with_residual | receipt below | Enable and verify HoldType Camera switch before capture retry. |
| `DV-P0B-CAMERA-AUTH-R02` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R01-REVIEW-R1` | exact System Settings Camera action plus one redacted auth-R02 QA run | accepted_with_residual | `36445d2`; receipt below | HoldType Camera row absent; no setting action or capture. |
| `DV-P0B-CAMERA-AUTH-R02-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R02@36445d2` | read-only exact seven-file evidence commit | accepted_with_residual | receipt below | Same-identity activation-before-request seam is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-W02` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R02-REVIEW` | exact Debug Launch, authorization tests, W01 summary | accepted_with_residual | `f35ac7f3659`; receipt below | Auth-only activation repair accepted; real permission runtime remains. |
| `DV-P0B-CAMERA-AUTH-W02-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | incorrect full commit authority | read-only | rejected | recorded below | Requested full SHA did not exist; no source inspection occurred. |
| `DV-P0B-CAMERA-AUTH-W02-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | corrected `DV-P0B-CAMERA-AUTH-W02@f35ac7f3659` | read-only exact three-path commit | accepted_with_residual | receipt below | One bounded same-signed active permission runtime is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-R03` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-W02-REVIEW-R1` | one redacted capture-auth-R03 QA run; no media | accepted_evidence / functional_fail | `744f313`; receipt below | One closed unknown accepted; category/stage diagnosis is a Debug-spike defect. |
| `DV-P0B-CAMERA-AUTH-R03-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R03@744f313` | read-only exact seven-file evidence commit | accepted_with_residual | receipt below | Repair closed stage categories before any permission retry. |
| `DV-P0B-CAMERA-AUTH-W03` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R03-REVIEW` | exact Debug launch/auth/event, authorization tests, W01 summary | rejected | `1ae703f`; receipt below | Diagnostic core passes, but rejection path can issue a second activation and misclassify. |
| `DV-P0B-CAMERA-AUTH-W03-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-W03@1ae703f` | read-only exact five-path commit | rejected | recorded below | Repair activation rejection and behavioral coverage before runtime. |
| `DV-P0B-CAMERA-AUTH-W03-R1` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | rejected W03 review | exact CameraAuthorization source/test; summary only if claim changes | accepted_with_residual | `0e9f032`; receipt below | First activation rejection suppresses all later activation/authorization. |
| `DV-P0B-CAMERA-AUTH-W03-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | repair `0e9f032` | read-only exact two-path repair commit | accepted_with_residual | receipt below | One bounded repaired permission runtime is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-R04` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-W03-REVIEW-R1` | one redacted capture-auth-R04 QA run; no media | accepted_evidence / functional_fail | `baafcb9`; receipt below | Activation semantics and natural cleanup are Debug-spike defects. |
| `DV-P0B-CAMERA-AUTH-R04-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R04@baafcb9` | read-only exact seven-file evidence commit | accepted_with_residual | receipt below | Read-only activation/termination exploration required before repair. |
| `DV-P0B-CAMERA-AUTH-E04` | `/root/dv_p0b_capture_map` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R04-REVIEW` | read-only exact activation/termination/script/SDK evidence | accepted_with_residual | receipt below | One NSApplication activation plus deferred terminate and direct-PID supervision supported. |
| `DV-P0B-CAMERA-AUTH-W04` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-E04` | exact auth/launch tests, permission script, W01 summary | rejected | `b2a2abf`; receipt below | Activation/termination pass; 420-second permission bound is not globally enforced. |
| `DV-P0B-CAMERA-AUTH-W04-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-W04@b2a2abf` | read-only exact six-path commit | rejected | recorded below | Enforce one absolute post-launch deadline and add slow-identity fake. |
| `DV-P0B-CAMERA-AUTH-W04-R1` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | rejected W04 review | permission script and W01 summary only | accepted_with_residual | `48c0d5c`; receipt below | One absolute deadline bounds all permission supervision; genuine permission runtime remains. |
| `DV-P0B-CAMERA-AUTH-W04-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | repair `48c0d5c` | read-only exact two-path repair commit | accepted_with_residual | receipt below | One bounded same-signed permission-only runtime is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-R05` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-W04-REVIEW-R1` | one redacted capture-auth-R05 QA run; no media | accepted_evidence / functional_fail | `4101f74`; receipt below | Activation timed out before authorization; a second same-launch Debug process required exact cleanup TERM. |
| `DV-P0B-CAMERA-AUTH-R05-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R05@4101f74` | read-only exact seven-file evidence commit | accepted_with_residual | receipt below | Evidence accepted; additional same-launch process is a Debug-spike defect. |
| `DV-P0B-CAMERA-AUTH-E05` | `/root/dv_p0b_capture_map` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R05-REVIEW` | read-only exact Debug entry/auth/launch/script/process evidence | accepted_with_residual | receipt below | Exact creator is unrecoverable; script-only marker-bound multi-process supervision is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-W05` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-E05` | exact permission script, authorization script-structure tests, W01 summary | accepted_with_residual | `b071056`; receipt below | Marker-bound multi-process supervision accepted; genuine permission runtime remains. |
| `DV-P0B-CAMERA-AUTH-W05-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-W05@b071056` | read-only exact three-path repair commit | accepted_with_residual | receipt below | One bounded diagnostic permission-only runtime is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-R06` | `/root/dv_p0b_capture_runtime_r01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-W05-REVIEW` | one redacted capture-auth-R06 QA run; no media | accepted_evidence / functional_fail | `a7f47a9`; receipt below | One direct process exited naturally; activation timed out before authorization. |
| `DV-P0B-CAMERA-AUTH-R06-REVIEW` | `/root/dv_p0b_capture_runtime_r01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-R06@a7f47a9` | read-only exact seven-file evidence commit | accepted_with_residual | receipt below | Clean topology accepted; activation remains a platform dependency before authorization. |
| `DV-P0B-CAMERA-AUTH-E06` | `/root/dv_p0b_capture_map` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-R06-REVIEW` | read-only exact activation/LaunchServices/source/script/SDK evidence | accepted_with_residual | receipt below | Exact-URL NSWorkspace design accepted with review corrections. |
| `DV-P0B-CAMERA-AUTH-E06-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | terminal `DV-P0B-CAMERA-AUTH-E06` | read-only exact map/API/ownership review | accepted_with_residual | receipt below | Corrected 12-path Debug repair is dependency-ready. |
| `DV-P0B-CAMERA-AUTH-W06` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | accepted `DV-P0B-CAMERA-AUTH-E06-REVIEW` | exact 12 Debug helper/script/auth/handshake/launch/termination/event/test/summary paths | rejected | `169e895`; receipt below | Architecture/build isolation pass; runtime path/parser/deadline/cancellation guarantees fail. |
| `DV-P0B-CAMERA-AUTH-W06-REVIEW` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | `DV-P0B-CAMERA-AUTH-W06@169e895` | read-only exact 12-path repair commit | rejected | receipt below | Seven-path focused repair required before runtime. |
| `DV-P0B-CAMERA-AUTH-W06-R1` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | rejected W06 review | exact script/helper/auth/three test/summary repair paths | rejected | `daac571`; receipt below | Original five findings closed; cleanup deadline and test-hook isolation remain. |
| `DV-P0B-CAMERA-AUTH-W06-REVIEW-R1` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | repair `daac571` | read-only exact six-path repair commit | rejected | receipt below | Three-path cleanup/hook-isolation repair required. |
| `DV-P0B-CAMERA-AUTH-W06-R2` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | rejected W06 R1 review | permission script, LaunchServices tests, W01 summary only | rejected | `10804b6`; receipt below | Hook isolation closed; timeout escalation and root identity remain unsafe. |
| `DV-P0B-CAMERA-AUTH-W06-REVIEW-R2` | `/root/dv_p0b_capture_w01_review` | `DV-DRAFT-4@2f3266a` | repair `10804b6` | read-only exact three-path repair commit | rejected | receipt below | Hard-bound TERM-ignoring cleanup and no-follow root-identity repair required. |
| `DV-P0B-CAMERA-AUTH-W06-R3` | `/root/dv_p0b_capture_w01` | `DV-DRAFT-4@2f3266a` | rejected W06 R2 review | permission script, LaunchServices tests, W01 summary only | running | — | Add hard timeout escalation and pinned no-follow descriptor-relative cleanup. |
| `DV-P0B-STORAGE-E02` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3@ed108fa` | accepted storage W01 repair and capture R01 cleanup | read-only exact external-runtime seam/command map | accepted_with_residual | receipts below | Existing harness is internal-only; three-path test-only seam is dependency-ready. |
| `DV-P0B-STORAGE-E02-REVIEW` | `/root/dv_p0b_storage_w01_review` | `DV-DRAFT-3@ed108fa` | `DV-P0B-STORAGE-E02` | read-only | accepted_with_residual | recorded below | Implement seam first; exact external mount roots require later explicit authorization. |
| `DV-P0B-STORAGE-W02` | `/root/dv_p0b_storage_map` | `DV-DRAFT-3` storage clauses; revalidated unaffected by pending `DV-DRAFT-4` quality delta | accepted `DV-P0B-STORAGE-E02-REVIEW` | two storage test files plus one test-only wrapper | accepted_with_residual | base `e6b3a13`; repairs `986af6c`, `767edd9`, `d0c9ce5`, `a50026a`; receipts below | Test-only seam accepted; actual external runtime requires exact-root authorization. |
| `DV-P0B-STORAGE-W02-REVIEW` | `/root/dv_p0b_storage_w01_review` | same revalidated storage clauses | `DV-P0B-STORAGE-W02@e6b3a13` | read-only exact three-path commit | rejected | recorded below | Return exact two findings to original owner; repeat review before external runtime. |
| `DV-P0B-STORAGE-W02-REVIEW-R1` | `/root/dv_p0b_storage_w01_review` | same revalidated storage clauses | repair `986af6c` | read-only exact three-path repair commit | rejected | recorded below | Return exact three remaining findings to original owner; repeat review before external runtime. |
| `DV-P0B-STORAGE-W02-REVIEW-R2` | `/root/dv_p0b_storage_w01_review` | same revalidated storage clauses | repair `767edd9` | read-only exact three-path repair commit | rejected | recorded below | One wrapper-only process identity completeness defect remains; repair and repeat review. |
| `DV-P0B-STORAGE-W02-REVIEW-R3` | `/root/dv_p0b_storage_w01_review` | same revalidated storage clauses | repair `d0c9ce5` | read-only wrapper-only repair commit | rejected | recorded below | Supervisor-group repair closed; one caffeinate PID-reuse escalation defect remains. |
| `DV-P0B-STORAGE-W02-REVIEW-R4` | `/root/dv_p0b_storage_w01_review` | same revalidated storage clauses | repair `a50026a` | read-only wrapper-only repair commit | accepted_with_residual | recorded below | Exact-root external runtime may be packetized only after explicit authorization. |
| `DV-P0B-UI` | unassigned | `DV-DRAFT-3@ed108fa` | `DV-P0A-REVIEW`; required skill available | bounded prototype/evidence paths assigned later | queued | — | Do not dispatch until `build-macos-apps:swiftui-patterns` is available and read. |
| `DV-P0B-REVIEW` | unassigned reviewer | `DV-DRAFT-3@ed108fa` | all dispatched P0B packets | read-only | queued | — | Reconcile evidence, residuals, and protected-domain impact. |
| `DV-P0C-CONTRACT` | unassigned | accepted P0A revision | `DV-P0B-REVIEW` | named specs and acceptance map | queued | — | Produce `DV-ACTIVE-1`; no implementation. |
| `DV-P0C-REVIEW` | unassigned reviewer | proposed `DV-ACTIVE-1` | `DV-P0C-CONTRACT` | read-only | queued | — | Independent contract and epoch acceptance. |
| `DV-P1-SETUP` | unassigned | `DV-ACTIVE-1` | `DV-P0C-REVIEW` | assigned foundation/setup paths | queued | — | Foundation and setup vertical slice. |
| `DV-P2-CAPTURE` | unassigned | current Active epoch | accepted Phase 1 | assigned capture paths | queued | — | One-clip slice without dictation regression. |
| `DV-P3-LIBRARY` | unassigned | current Active epoch | accepted Phase 2 | assigned archive/library paths | queued | — | Library, review, exclusion, and exact deletion. |
| `DV-P4-BUILD` | unassigned | current Active epoch | accepted Phase 3 | assigned build/export/share paths | queued | — | Deterministic local Build, Export, and Share. |
| `DV-FINAL-QA` | unassigned reviewers | final Active epoch | accepted Phase 4 | read-only plus controlled runtime evidence | queued | — | Build/tests, signed camera/storage/runtime, SwiftUI QA, and protected-domain verification. |

## Current Coordination State

- Accepted E01 evidence supports bounded Debug-only capture and test-only
  storage spikes without a shipping dependency.
- Repaired capture packet `ff70155` is accepted_with_residual after independent
  review. The original `9d9efec` rejection remains recorded below.
- Accepted evidence is limited to Debug/fake/build feasibility. It does not
  establish camera/TCC/device/media measurements, E07 dictation non-regression,
  or the shipping shared-audio lease.
- Repaired storage packet `69b2d16` is accepted_with_residual after independent
  review. The original `2486b56` rejection remains recorded below.
- Accepted storage evidence is limited to fake/internal APFS bookmark,
  capacity, exclusive-promotion, redaction, and cleanup mechanics. External
  drives, true-stale/remount, interruption, and representative media remain.
- Capture runtime preflight `f698fcb` is accepted_with_residual. Built-in and
  USB are unavailable; the connected iPhone did not enumerate as Continuity
  Camera. No capture, TCC, media, or quantitative claim exists.
- A bounded capture retry waits for an explicit camera uniqueID. Independent
  storage external/runtime evidence may proceed serially after this cleanup.
- `DV-P0B-STORAGE-E02` is accepted_with_residual: the current harness is
  internal-only, and a two-test-file plus one-wrapper seam is dependency-ready.
  External writes still require exact mount-root authorization after review.
- `DV-P0B-CAPTURE-R02@0e21972` evidence is accepted but its functional cell is
  fail/debug-spike defect. Typed camera-start category and bounded termination
  repair is the next serialized writable packet; no hardware retry precedes it.
- Repaired capture packet through `f141be6` is accepted_with_residual. The
  rejected intermediate reviews remain recorded below.
- No runtime packet is running. `DV-P0B-CAPTURE-R04` was retired before
  dispatch when the user superseded the fixed 720p/30 source-quality rule.
- Source-only `DV-DRAFT-4@2f3266a` is accepted_with_residual for evidence work.
  `DV-P0B-CAPTURE-E03` accepted a bounded Apple-native repair design. The
  Debug-only `DV-P0B-CAPTURE-W02@f7ff6bf` repair is accepted_with_residual
  after independent review. `DV-P0B-CAPTURE-R05@11cb9a2` selected one
  Continuity Camera but failed at `camera_permission_required` before camera
  start. Independent review accepted the evidence and found no Debug defect;
  Debug-only permission seam `5b3ed20` is accepted. One bounded genuine
  same-identity Camera authorization request timed out without an actionable
  prompt. Evidence facts and cleanup passed review, but one summary-only TCC
  truthfulness repair `308a191` is accepted. A bounded Computer Use action is
  accepted after finding the HoldType Camera row absent; no switch or TCC
  action occurred. Three-path Debug activation repair `f35ac7f` is accepted
  after corrected-SHA review. One active same-signed permission runtime
  returned closed unknown before a prompt. Evidence is accepted, but stage
  collapse is a Debug-spike defect. Diagnostic repair `1ae703f` was rejected
  for one activation-order regression; repair `0e9f032` is accepted. One
  repaired permission-only runtime proved activation rejection before
  authorization. Review accepted the facts and identified activation semantics
  plus natural cleanup defects. Read-only E04 accepted a bounded six-path
  repair. W04 activation/termination passed review, and script repair
  `48c0d5c` is accepted after proving one absolute deadline across permission
  supervision and identity-safe cleanup. One same-signed permission-only
  runtime ended at `camera_authorization_activation_timed_out` before
  authorization status or requestAccess. Its direct app PID exited naturally,
  but a second same-launch Debug process required exact cleanup TERM. Review
  accepted the runtime facts and classified that additional lifetime as a
  Debug-spike launch/supervision defect. Read-only ownership exploration found
  the exact creator unrecoverable from retained evidence and accepted a
  script-only, run-marker-bound multi-process supervision design. Repair
  `b071056` is in independent review after 17/17 supervisor fakes and 59/59
  Phase 0B tests passed and independent review accepted the repair. One
  diagnostic permission-only runtime retained one direct marker-owned process,
  zero additional identities, and clean natural exit, but again timed out at
  activation_requested before authorization. Review accepted the evidence and
  classified the remaining failure as a platform activation dependency rather
  than signing/TCC proof or a new demonstrated Debug defect. Read-only
  activation/LaunchServices exploration proposed exact-URL NSWorkspace launch
  through a bounded non-requesting helper plus target ownership acknowledgment.
  Independent design review accepted a corrected 12-path Debug-only envelope:
  no explicit helper signing, stronger atomic handshake, and structure-safe
  source extraction. Repair `169e895` compiled and passed tests but review
  rejected its real parser, deadline, result-file, cancellation, and behavioral
  coverage guarantees. Focused repair `daac571` passes 20/20 focused and 66/66
  full Phase 0B tests but repeat review found cleanup outside the global
  deadline and a test hook affecting build-only/hardware modes. Three-path R2
  repair `10804b6` passes 68 Phase 0B tests and closes hook isolation, but
  repeat review found TERM-ignoring cleanup can outlive the deadline and root
  replacement can escape exact ownership. Three-path R3 repair is running;
  capture remains blocked. The
  final Build fallback remains separate and does not block source evidence.
- `DV-P0B-STORAGE-W02` through repair `a50026a` is accepted_with_residual.
  The test-only seam is fail-closed and bounded; no external I/O was performed.
  Actual external runtime still requires explicit authorization of each exact
  mount root. The accepted seam remains unaffected by the quality delta.
- Product implementation is gated until `DV-P0C-REVIEW` accepts
  `DV-ACTIVE-1`.
- The connected iPhone is reserved for the later dependency-ready Continuity
  Camera runtime gate.
- E01 observed writable external SSD and HDD classes. Exact authorized scratch
  bases and runtime availability remain pending for the storage packet.
- `build-macos-apps:swiftui-patterns` was unavailable during planning; do not
  dispatch UI design or implementation until resolved.
- Direct publication is outside the goal and must never be dispatched.

## Accepted Receipts

### `DV-G0-REGISTRY`

```text
packet_id: DV-G0-REGISTRY
status: done

outcome: Persistent goal scope, restart gate, epochs, packet graph, and blocker
policy recorded.
authority_used: User-created goal; governing plan; DV-DRAFT-2;
root-orchestration.md; product-truth-governance.md.
changed_paths: docs/dev-vlogs-execution-registry.md;
docs/dev-vlogs-implementation-plan.md
reused_owners: Existing Dev Vlogs plan and specification system.
checks_run: Documentation diff hygiene before checkpoint acceptance.
scope_check: Coordination-only; no product behavior or source change.
deviations: none
residual: DV-D01-D13 require specification integration and review.
next_dependency: DV-P0A-SPEC
runtime_or_visual_handoff: none
```

### `DV-G0-REGISTRY-REVIEW`

```text
packet_id: DV-G0-REGISTRY-REVIEW
status: done

outcome: accept
authority_used: User-created persistent goal; AGENTS.md; governing plan;
DV-DRAFT-2@8081c10.
changed_paths: none
reused_owners: Existing Dev Vlogs plan and specification system.
checks_run: Exact two-path diff inspection; tracked and untracked diff hygiene;
plan/spec linkage; packet graph and scope gates.
scope_check: Scope guard, Phase 0 dependency order, UI skill gate, and exclusion
of direct publication are coherent.
deviations: none
residual: Registry awaits the coordinator's scoped checkpoint commit.
next_dependency: DV-P0A-SPEC
runtime_or_visual_handoff: none
```

### `DV-P0A-SPEC`

```text
packet_id: DV-P0A-SPEC
status: done

outcome: Integrated DV-D01-D13 into decision-complete DV-DRAFT-3 and added a
bounded Phase 0B feasibility and measurement protocol.
authority_used: User acceptance; DV-DRAFT-2@8081c10; governing plan and
registry; product-truth governance.
changed_paths: docs/specs/features/dev-vlogs.md;
docs/qa/dev-vlogs-phase-0b-feasibility-and-measurement-protocol.md
reused_owners: Existing Dev Vlogs specification and QA evidence layers.
checks_run: Staged diff hygiene, complete staged-diff inspection, post-commit
path audit.
scope_check: Only authorized documentation paths changed.
deviations: none
residual: Numeric latency/storage evidence awaits Phase 0B; UI preview waits
for build-macos-apps:swiftui-patterns.
next_dependency: DV-P0A-REVIEW
runtime_or_visual_handoff: none
commit: ed108fa69fe54781dbe09285c3dac59d3d4f1b35
```

### `DV-P0A-REVIEW`

```text
packet_id: DV-P0A-REVIEW
status: done

outcome: accept_with_residual
authority_used: Pinned pre-change authority, user decisions, DV-DRAFT-3 and
Phase 0B protocol at ed108fa.
changed_paths: none
reused_owners: Dev Vlogs specification, plan, registry, and QA evidence layer.
checks_run: Full authority reading; exact commit review; path and diff hygiene;
pre/post comparison; stale-reference check; DV-D01-D13 mapping.
scope_check: Clean; no adjacent spec or source change.
deviations: none
residual: Phase 0B must provide quantitative capture/storage evidence. UI
preview feasibility remains gated on build-macos-apps:swiftui-patterns.
next_dependency: DV-P0B-CAPTURE and DV-P0B-STORAGE
runtime_or_visual_handoff: none
```

### `DV-REGISTRY-P0A-UPDATE-REVIEW`

```text
packet_id: DV-REGISTRY-P0A-UPDATE-REVIEW
status: done

outcome: accept after repair of two stale revision/status statements
authority_used: DV-DRAFT-3@ed108fa; accepted DV-P0A-SPEC and DV-P0A-REVIEW
receipts; governing plan and goal scope.
changed_paths: none
reused_owners: Persistent-goal registry and governing plan.
checks_run: Exact coordination diff review and diff hygiene.
scope_check: Current epoch, accepted decisions, dependency-ready packets, and
UI skill gate are coherent.
deviations: none
residual: Phase 0B capture/storage evidence remains required; UI remains
skill-gated.
next_dependency: DV-P0B-CAPTURE and DV-P0B-STORAGE
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-E01`

```text
packet_id: DV-P0B-CAPTURE-E01
status: done

outcome: Apple-native Debug-only camera/audio/mux spike is feasible with one
existing microphone owner and no shipping dependency.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; active microphone,
durability, and privacy contracts; exact recorder/controller/project source;
official Apple AVFoundation/CoreMedia documentation.
changed_paths: none
reused_owners: AVFoundationAudioRecorderService, AudioRecorderEngine,
RecordingCaptureJournal, and existing exact-once artifact finalization.
checks_run: Read-only source, project, SDK-header, and official-platform review.
scope_check: Capture feasibility only; no storage, UI, or product change.
deviations: none
residual: Shipping shared-audio lease is not implemented or authorized;
camera/TCC/signing/device/codec/latency/sync/fragment evidence remains.
next_dependency: DV-P0B-E01-REVIEW
runtime_or_visual_handoff: none
```

### `DV-P0B-STORAGE-E01`

```text
packet_id: DV-P0B-STORAGE-E01
status: done

outcome: Apple-native test-only destination/bookmark/capacity/promotion spike
is feasible with a separate Dev Vlogs owner.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; active storage/privacy/
durability/distribution contracts; exact storage owners; official Apple APIs.
changed_paths: none
reused_owners: Existing app distribution and file-system platform boundaries;
protected Cache, History, and recovery owners remain separate.
checks_run: Read-only source/project/platform review and redacted disk inventory.
scope_check: Storage feasibility only; no write, mount, unmount, or user-data
mutation.
deviations: none
residual: Real bookmark/remount/capacity/promotion/interruption evidence and
physical disconnect/read-only-media cells remain.
next_dependency: DV-P0B-E01-REVIEW
runtime_or_visual_handoff: none
```

### `DV-P0B-E01-REVIEW`

```text
packet_id: DV-P0B-E01-REVIEW
status: done

outcome: capture accept_with_residual; storage accept_with_residual
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; governing plan/registry;
exact source/project ownership; official Apple documentation.
changed_paths: none
reused_owners: Existing recorder/journal and protected storage owners.
checks_run: Pinned-contract comparison; lifecycle/startup/project/storage/API
inspection; read-only environment classification.
scope_check: Clean; explorers made no changes.
deviations: none
residual: Capture shipping lease and runtime evidence remain; storage real
filesystem/interruption evidence remains; quantitative data is evidence-only.
next_dependency: Repair stale plan references, checkpoint receipts, then
DV-P0B-CAPTURE-W01 followed by serialized storage work.
runtime_or_visual_handoff: none
```

### `DV-REGISTRY-E01-UPDATE-REVIEW`

```text
packet_id: DV-REGISTRY-E01-UPDATE-REVIEW
status: done

outcome: accept
authority_used: Accepted capture/storage E01 maps and E01 review; governing
plan, registry, and DV-DRAFT-3@ed108fa.
changed_paths: none
reused_owners: Persistent-goal registry and governing plan.
checks_run: Exact coordination diff review and diff hygiene.
scope_check: E01 residuals, serialized writable order, UI skill gate, and Phase
5 exclusion are coherent.
deviations: none
residual: Capture W01 is dependency-ready; storage and UI remain gated.
next_dependency: DV-P0B-CAPTURE-W01
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-W01`

```text
packet_id: DV-P0B-CAPTURE-W01
status: done

outcome: Built and fake-verified the isolated Debug-only camera/audio/mux
harness; repair ff70155 closed all four findings from the rejected base.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; accepted E01 evidence;
bounded W01 and R1 packets.
changed_paths: Fifteen original authorized paths plus nine path-bounded repair
changes; commits 9d9efec and ff70155.
reused_owners: Existing AVFoundationAudioRecorderService and AudioRecorderEngine;
no shipping shared-audio lease.
checks_run: Structure; 21 focused fake tests; Debug build-only; bounded Release
compile; Debug/Release settings and artifact isolation; script checks; path audit.
scope_check: Debug-only harness and exact integration paths; protected product
owners, Release camera declarations, UI, iOS, dependencies, and publication
unchanged.
deviations: Initial commit was rejected and repaired by the original owner.
residual: Real camera/microphone/TCC/Continuity, device/media/codec/timing/
resource evidence, E07, and the shipping shared-audio lease remain.
next_dependency: DV-P0B-CAPTURE-W01-REVIEW-R1
runtime_or_visual_handoff: none
accepted_repair_commit: ff70155aa0559678487eacb67bc16a62ce199b75
```

### `DV-P0B-CAPTURE-W01-REVIEW-R1`

```text
packet_id: DV-P0B-CAPTURE-W01-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Repair closes harness-only scene routing, steady-error exact-once
cleanup, bounded terminate-later cleanup, and callback-independent export/script
timeouts. Debug/fake/build feasibility is accepted.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; original W01 packet;
rejected review; repair ff70155; protected adjacent contracts.
changed_paths: none
checks_run: Exact nine-path diff; structure; 21 focused tests; bounded Release
build; Debug/Release settings and artifacts; Debug guards; one-mic/no-fallback
scan; script and QA-claim audit.
scope_check: Clean; Release retains original plist/entitlements and contains no
Dev Vlogs symbols. No app, hardware, TCC, UI, provider, Keychain, or storage run.
deviations: none
residual: Hardware/runtime/media measurements, E07, and shipping audio lease
remain outside this acceptance.
next_dependency: DV-P0B-STORAGE-W01 or separately controlled hardware runtime.
runtime_or_visual_handoff: none
reviewed_commit: ff70155aa0559678487eacb67bc16a62ce199b75
```

### `DV-P0B-STORAGE-W01`

```text
packet_id: DV-P0B-STORAGE-W01
status: done

outcome: Test-only storage harness verifies marker-owned roots, ordinary
bookmark rename-following, injected capacity/destination states, synchronized
writes, APFS exclusive no-overwrite promotion, truthful partial classification,
redaction, and exact cleanup. Repair 69b2d16 hardens cleanup ancestry identity.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E08; accepted E01 map;
bounded W01 and R1 packets.
changed_paths: Two storage test files and one redacted QA summary; commits
2486b56 and 69b2d16.
reused_owners: Internal FileManager temporary directory and ordinary unsandboxed
Foundation bookmarks only; no protected storage owner.
checks_run: Structure; 19 focused tests; redirected-prefix survival; bounded
Debug build; diff/path and zero-residue/process audits.
scope_check: Internal marker-owned temp roots only; no product source, project,
entitlement, UserDefaults, external volume, user archive, media, UI, or hardware.
deviations: Initial commit was rejected and repaired by the original owner.
residual: True-stale/external bookmark recovery, SSD/HDD, read-only/remount/
disconnect, representative media, and numeric Phase 0C inputs remain.
next_dependency: DV-P0B-STORAGE-W01-REVIEW-R1
runtime_or_visual_handoff: none
accepted_repair_commit: 69b2d163a696b4a13fab3e58475ad3065b57269f
```

### `DV-P0B-STORAGE-W01-REVIEW-R1`

```text
packet_id: DV-P0B-STORAGE-W01-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Cleanup prefix/root identity and stale-claim repairs close both prior
findings; internal XCTest/storage feasibility is accepted.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E08; original packet; rejected
review; repair 69b2d16.
changed_paths: none
checks_run: Exact three-path diff; ancestry/prefix/root/attack-fixture review;
structure; 19 cases; bounded Debug build; zero-residue and process audit.
scope_check: Clean; no product, external-volume, app, hardware, UI, provider,
Keychain, or representative-media access.
deviations: none
residual: External/read-only/remount/interruption/bookmark/media and numeric
threshold evidence remain.
next_dependency: Separately controlled external/runtime storage evidence.
runtime_or_visual_handoff: none
reviewed_commit: 69b2d163a696b4a13fab3e58475ad3065b57269f
```

### `DV-P0B-CAPTURE-R01`

```text
packet_id: DV-P0B-CAPTURE-R01
status: done

outcome: Bounded Debug/signing/internal-capacity preflight found zero built-in,
USB, Continuity, or other external cameras. No capture started.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; accepted capture and
storage harness repairs; finite R01 packet.
changed_paths: Twelve redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-r01/; commit f698fcb.
checks_run: Debug build; signing/Release isolation; bounded bundled enumeration;
capacity; JSON/CSV/redaction/path checks; cleanup audit.
scope_check: Evidence-only; no source, TCC, UI, provider, Keychain, iOS,
external-storage, or protected-owner change.
deviations: Initial detached idle guard exited early; enumeration repeated once
under a verified same-shell guard.
residual: No camera uniqueID; functional capture/media/TCC and all quantitative
evidence remain unqualified.
next_dependency: DV-P0B-CAPTURE-R01-REVIEW
runtime_or_visual_handoff: none
commit: f698fcb55e2d5b993947daf35bb41aecef075c6d
```

### `DV-P0B-CAPTURE-R01-REVIEW`

```text
packet_id: DV-P0B-CAPTURE-R01-REVIEW
status: done
verdict: accept_with_residual

outcome: Evidence supports terminal not_available classification for built-in,
USB, and Continuity cells; it makes no functional capture or media claim.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E02/E04/E06/E08; exact R01
evidence and accepted harness authority.
changed_paths: none
checks_run: Exact commit and twelve-blob audit; JSON/CSV parsing; redaction and
media scans; cleanup/process/caffeinate zero-residue snapshot.
scope_check: Clean; no source, spec, project, TCC, UI, Keychain, provider,
external storage, or protected-owner change.
deviations: Initial guard deviation was disclosed and corrected by guarded
repeat.
residual: Only enumeration/signing preflight is accepted. E02 functional media
and E06 measurements wait for an explicit camera identity.
next_dependency: Controlled retry after camera hardware enumerates.
runtime_or_visual_handoff: none
reviewed_commit: f698fcb55e2d5b993947daf35bb41aecef075c6d
```

### `DV-P0B-CAPTURE-R03`

```text
packet_id: DV-P0B-CAPTURE-R03
status: done

outcome: Debug harness now preserves closed redacted camera categories through
actual start/first-frame/observer/stop routes and exits boundedly without
self-await. Script bounds hardware mode at duration plus 300 seconds and cleans
only exact run-owned children.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted R02 failure evidence;
bounded R03 repairs and reviews.
changed_paths: Authorized Debug camera/launch/event, focused tests, script, and
W01 summary across commits 8b0b263, 1276283, ba058f8, and f141be6.
checks_run: Structure; final 35-test Phase 0B suite; Debug build-only; bounded
Release build; Debug/Release isolation; script and redaction/path audits.
scope_check: Debug/test/evidence only; no product, TCC, UI, storage, iOS,
provider, Keychain, dependency, or Release camera behavior.
deviations: Three rejected intermediate reviews drove bounded repairs by the
original owner.
residual: Hardware/media/codec/timing/resource evidence and shipping audio
lease remain.
next_dependency: DV-P0B-CAPTURE-R03-REVIEW-R3
runtime_or_visual_handoff: none
accepted_repair_commit: f141be6da26ffc04a20f5fcbcb92ee614afd84f8
```

### `DV-P0B-CAPTURE-R03-REVIEW-R3`

```text
packet_id: DV-P0B-CAPTURE-R03-REVIEW-R3
status: done
verdict: accept_with_residual

outcome: Explicit-stop context repair closes the final known propagation
defect; concrete service test covers disconnect/runtime, cleanup, and duplicate.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; R02/R03 reviews; repair f141be6.
changed_paths: none
checks_run: Exact three-path diff; concrete route trace; 12 camera and 35 full
tests; structure; Debug/Release isolation; accepted-owner comparison.
scope_check: Clean; no hardware, TCC, storage, product, or protected-owner run.
deviations: none
residual: Real device/media measurements and shipping audio lease remain.
next_dependency: One separately authorized Continuity runtime retry.
runtime_or_visual_handoff: none
reviewed_commit: f141be6da26ffc04a20f5fcbcb92ee614afd84f8
```

## Reviewed Runtime And Seam Evidence

### `DV-P0B-CAPTURE-R02`

```text
packet_id: DV-P0B-CAPTURE-R02
status: failed

outcome: One explicit candidate-capable Continuity Camera enumerated and was
selected with no fallback. Camera start failed before first frame; termination
then exceeded the accepted cleanup window.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted harness; user-authorized
Continuity retry.
changed_paths: Eight redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-r02/; commit 0e21972.
checks_run: Guarded enumeration and 10-second invocation; exact-once event and
artifact probes; bounded Computer Use attempt; cleanup/redaction/path audits.
scope_check: Evidence-only; no source, TCC, UI, provider, Keychain, iOS, or
external-storage change.
deviations: Exact run-owned TERM was required after cleanup overrun; Computer
Use could not attach to the non-activating harness.
residual: Underlying camera-start category is not logged; termination hangs
after the terminal failure; TCC state remains uncertain. No media gate passed.
next_dependency: DV-P0B-CAPTURE-R02-REVIEW
runtime_or_visual_handoff: none
commit: 0e21972071d76eff1dd53a67a0b397d7bc32518e
```

### `DV-P0B-STORAGE-E02`

```text
packet_id: DV-P0B-STORAGE-E02
status: done

outcome: Existing storage harness cannot accept an external base. A minimal
test-only seam is feasible in two storage test files plus one wrapper script.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B E03/E04/E06/E08; accepted W01;
current test scheme/tooling and read-only external inventory.
changed_paths: none
checks_run: Read-only harness/scheme/tooling and redacted disk metadata review.
scope_check: No file, volume, app, camera, UI, or external-content mutation.
deviations: none
residual: External actual I/O, representative media, unplug/remount, and
read-only media remain; each runtime mount root needs explicit authorization.
next_dependency: DV-P0B-STORAGE-E02-REVIEW
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-R02-REVIEW`

```text
packet_id: DV-P0B-CAPTURE-R02-REVIEW
status: done
verdict: accept_with_residual
functional_cell: fail

outcome: Evidence truthfully establishes one explicitly selected Continuity
attempt failing during camera start, followed by a termination-cleanup overrun.
Evidence acceptance does not accept capture functionality.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted harness; R02 evidence.
changed_paths: none
checks_run: Exact eight-file commit/blob audit; structured-data consistency;
redaction/media scans; chronology; narrow harness mapping; zero-residue snapshot.
scope_check: Clean; no source, TCC, UI, Keychain, provider, external storage,
or protected-owner mutation.
deviations: Exact run-owned TERM and bounded failed Computer Use attachment are
preserved in the evidence.
residual: Camera-start error category and TCC state remain unknown; termination
is not runtime-safe after this failure; no media gate passed.
next_dependency: Original Debug harness owner repairs category and termination,
then independent review precedes another Continuity retry.
runtime_or_visual_handoff: none
reviewed_commit: 0e21972071d76eff1dd53a67a0b397d7bc32518e
```

### `DV-P0B-STORAGE-E02-REVIEW`

```text
packet_id: DV-P0B-STORAGE-E02-REVIEW
status: done
verdict: accept_with_residual

outcome: Proposed external-storage seam is necessary, minimal, and feasible;
it authorizes no external write or success by itself.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted storage harness; current
test scheme/project/distribution evidence.
changed_paths: none
checks_run: Harness/test authority review; scheme and synchronized-membership;
unsandboxed test-host settings; wrapper patterns; structure/diff hygiene.
scope_check: Read-only; no external write, app, project, entitlement, dependency,
or product-source change.
deviations: none
residual: Seam implementation/review, exact-root authorization, actual SSD/HDD
I/O, read-only/remount/interruption/media/numeric evidence remain.
next_dependency: DV-P0B-STORAGE-W02 after the serialized capture repair.
runtime_or_visual_handoff: none
```

### `DV-P0B-STORAGE-W02`

```text
packet_id: DV-P0B-STORAGE-W02
status: done

outcome: Implemented a fail-closed test-only explicit external-root authority
seam and bounded runtime wrapper. Fake/internal evidence covers closed
configuration, exact root/device/inode/marker validation, a 64 KiB cap,
exclusive promotion, collision preservation, and pending cleanup. No external
runtime I/O occurred.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
accepted E02 map and review.
changed_paths: Two storage test files and one test-only wrapper; commit e6b3a13.
reused_owners: Accepted W01 bookmark, RENAME_EXCL, ancestry/marker, redaction,
cleanup, capacity, and classification owners; no shipping owner.
checks_run: 24 unique focused XCTest cells; structure; bounded Debug build;
wrapper syntax/help and nine fail-closed negative cases; exact-path, mode,
protected-owner, redaction, residue, and process audits.
scope_check: Exact three-path test/tooling scope; no product, project,
entitlement, plist, settings, protected storage, UI, media, hardware,
external-volume, or dependency change.
deviations: Seven tiny internal /tmp outputs from an early negative command and
four empty marker-owned failed-test roots were precisely validated and removed;
no user or external content was touched. Final residue and process counts zero.
residual: Actual SSD/HDD I/O, exact authorized roots, genuine read-only media,
unplug/reconnect/remount, representative media, and true bookmark stale remain.
next_dependency: DV-P0B-STORAGE-W02-REVIEW
runtime_or_visual_handoff: none
commit: e6b3a13f046a6e0ac703643c87ee869e222ead6f
```

### `DV-P0B-STORAGE-W02-R1`

```text
packet_id: DV-P0B-STORAGE-W02-R1
status: done

outcome: Direct XCTest authority now independently validates an exact
non-broad mounted external root and physical SSD/HDD class using Disk
Arbitration, IOKit, statfs, destination state, and no-follow ancestry. Wrapper
metadata and process cleanup are bounded and identity/process-group scoped.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
W02 packet and rejected review recorded at a551c12.
changed_paths: Same two storage test files and one test-only wrapper; repair
commit 986af6c.
reused_owners: Accepted W01/W02 identity, marker, bookmark, promotion,
redaction, capacity, and cleanup owners.
checks_run: Structure; 24 focused W01 cases and disabled opt-in runtime cell;
bounded Debug build; wrapper syntax/help and five fail-closed arguments; normal,
timeout, trap TERM-to-KILL, and caffeinate cleanup fixtures; diff, exact-path,
mode, redaction, protected-owner, residue, and process audits.
scope_check: Exact three-path test/tooling repair; zero external-volume I/O and
no product, project, entitlement, spec, registry, QA artifact, media, settings,
or protected-owner change.
deviations: none
residual: Real SSD/HDD Disk Arbitration/IOKit evidence remains for a separately
authorized external runtime packet.
next_dependency: DV-P0B-STORAGE-W02-REVIEW-R1
runtime_or_visual_handoff: none
commit: 986af6ca85147c8236075b30d5fef200f73dec74
```

### `DV-P0B-STORAGE-W02-R2`

```text
packet_id: DV-P0B-STORAGE-W02-R2
status: done

outcome: Probe status 1 alone means empty; timeout/error remain uncertain.
External metadata runs inside one 15-second watchdog subprocess. Harness and
wrapper categorically reject root, home, and home ancestors; injected evidence
tests cover the accepted and negative authority matrix.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E06/E08;
REVIEW-R1 reject recorded at 4d63fb8.
changed_paths: Same two storage test files and one test-only wrapper; repair
commit 767edd9.
reused_owners: Accepted W01/W02 identity, marker, bookmark, promotion,
redaction, capacity, and cleanup owners.
checks_run: Structure; 25 focused invocations; wrapper syntax/help and six
argument negatives; four probe-status, two preflight-failure, and four process
cleanup fixtures; bounded Debug build; diff, path, mode, redaction,
protected-owner, process, and residue audits.
scope_check: Exact three-path test/tooling repair; zero external-volume I/O and
no product, project, entitlement, spec, registry, QA artifact, media, settings,
UI, or protected-owner change.
deviations: none
residual: Actual external SSD/HDD evidence remains for a separately authorized
runtime packet.
next_dependency: DV-P0B-STORAGE-W02-REVIEW-R2
runtime_or_visual_handoff: none
commit: 767edd9eb717f2a5324a79a3aa37dc3086657427
```

### `DV-P0B-STORAGE-W02-R3`

```text
packet_id: DV-P0B-STORAGE-W02-R3
status: done

outcome: Wrapper process-group identities are captured atomically, bounded
probe status survives EXIT traps, and exact member-set plus every identity is
revalidated immediately before the sole group-signal path. Uncertainty emits
no group signal; escalation uses revalidated exact PIDs.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
prior W02 repairs and REVIEW-R2 reject recorded at 88336d9.
changed_paths: Test-only external-storage wrapper only; repair commit d0c9ce5.
reused_owners: Existing explicit opt-in, preflight and process bounds,
no-auto-selection, exact scratch, redaction, and W01/W02 Swift owners.
checks_run: Syntax/help; nine argument negatives; seven identity-set no-signal,
one partial-identity no-signal, five group-probe status, two preflight-failure,
and five lifecycle cells; 29 shell matrix cells total; structural, diff, path,
mode, redaction, protected-owner, process, and residue audits.
scope_check: Exact one-wrapper-path repair; zero external-volume I/O and no
enabled external invocation, diskutil/df, Swift, product, project, spec,
registry, media, hardware, UI, or protected-owner change.
deviations: none
residual: Actual external SSD/HDD evidence remains separately authorized.
next_dependency: DV-P0B-STORAGE-W02-REVIEW-R3
runtime_or_visual_handoff: none
commit: d0c9ce529f8b43234575ce9db2e51a0b007bb484
```

### `DV-P0B-STORAGE-W02-R4`

```text
packet_id: DV-P0B-STORAGE-W02-R4
status: done

outcome: Caffeinate KILL now requires a fresh exact identity match after the
bounded TERM wait. Missing, changed, timed-out, or failed identity evidence
emits no KILL and forces cleanup failure, including through EXIT traps.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
W02 repair chain and REVIEW-R3 reject recorded at 9186352.
changed_paths: Test-only external-storage wrapper only; repair commit a50026a.
reused_owners: Accepted supervisor identity/signaling, preflight, opt-in,
timeouts, exact scratch, redaction, and Swift owners.
checks_run: Syntax/help; five argument negatives; seven direct and six EXIT-trap
caffeinate cells; seven supervisor identity, five group-probe, and four actual
lifecycle cells; 29 cleanup/process cells total; structural, diff, exact-path,
mode, redaction, protected-owner, process, and residue audits.
scope_check: Exact one-wrapper-path repair; zero external-volume I/O and no
enabled external invocation, disk probes, Swift, product, project, spec,
registry, media, UI, or protected-owner change.
deviations: none
residual: Actual external SSD/HDD evidence remains separately authorized.
next_dependency: DV-P0B-STORAGE-W02-REVIEW-R4
runtime_or_visual_handoff: none
commit: a50026aa53d93c0808ac84259f05759073434fdb
```

### `DV-P0B-STORAGE-W02-REVIEW-R4`

```text
packet_id: DV-P0B-STORAGE-W02-REVIEW-R4
status: done
verdict: accept_with_residual

outcome: Fresh caffeinate pre-KILL identity, no-KILL uncertainty behavior,
EXIT-trap false-success prevention, bounded reap, and supervisor group cleanup
are accepted. The complete W02 test-only external-storage seam is accepted;
this verdict accepts no external runtime evidence.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
accepted W01/E02 evidence and the complete W02 repair chain.
changed_paths: none
checks_run: Exact wrapper repair audit; syntax/help; seven direct and seven
EXIT-trap caffeinate cases; supervisor lifecycle/regression fixtures; nine
wrapper negatives; structural TERM/KILL/wait/identity, redaction,
protected-owner, process, and residue audits. No external I/O.
scope_check: Exact wrapper-only repair; Swift blobs unchanged from 767edd9 and
no product, project, protected-owner, media, quality, or threshold change.
deviations: none
residual: Actual authorized SSD/HDD I/O, genuine read-only media,
unplug/reconnect/remount, representative media, true bookmark staleness, and
quantitative evidence remain separately authorized.
next_dependency: Separately authorize an exact-root external runtime packet.
runtime_or_visual_handoff: none
reviewed_commit: a50026aa53d93c0808ac84259f05759073434fdb
```

### `DV-P0A-QUALITY-SPEC`

```text
packet_id: DV-P0A-QUALITY-SPEC
status: done

outcome: Proposed DV-DRAFT-4 preserves camera/macOS-negotiated source video
without HoldType downsampling or additional source-video encoding, requires a
proven passthrough source-finalization path, removes capture-quality controls,
reframes capacity evidence, and isolates the unresolved Build fallback.
authority_used: Explicit user native-source decision; prior DV-DRAFT-3;
governing plan, protocol, registry, and product-truth governance.
changed_paths: Dev Vlogs spec, Phase 0B protocol, and implementation plan;
commit 2f3266a.
reused_owners: Existing Draft, QA protocol, and plan; protected product owners
unchanged.
checks_run: Exact three-path and cached diff inspection; diff hygiene; revision,
clause, link, and stale-term searches; post-commit path audit.
scope_check: Documentation-only source-quality evolution; no code, runtime,
Build fallback choice, adjacent contract, UI, iOS, or publication change.
deviations: none
residual: DV-BUILD-6 remains a user decision; independent DV-DRAFT-4 review is
required before capture/media packet revalidation.
next_dependency: DV-P0A-QUALITY-REVIEW
runtime_or_visual_handoff: none
commit: 2f3266a
```

### `DV-P0A-QUALITY-REVIEW`

```text
packet_id: DV-P0A-QUALITY-REVIEW
status: done
verdict: accept_with_residual

outcome: DV-DRAFT-4 coherently preserves camera/macOS-negotiated source
dimensions and frame rate without a HoldType selector, downsample, or extra
source-video encode; native negotiated 1080p is not a promised preset or RAW.
Source finalization fails truthfully when proven passthrough is unavailable.
authority_used: Explicit user native-source decision; DV-DRAFT-3@ed108fa;
product-truth governance; exact DV-DRAFT-4 three-path commit.
changed_paths: none
checks_run: Exact parent/path/blob and diff review; stale-term, clause,
revision, link, and plan/protocol/spec consistency checks.
scope_check: Draft-only source evolution; protected domains, UI skill gate,
publication exclusion, and product implementation gate unchanged.
deviations: none
residual: DV-BUILD-6 remains a user decision between one final
no-downscale/no-nominal-FPS-reduction encode and failing an incompatible Build.
next_dependency: Revalidate affected capture/media packets against DV-DRAFT-4.
runtime_or_visual_handoff: none
reviewed_commit: 2f3266a12643251f890f5347dc9f1ca09d47516d
```

### `DV-P0B-CAPTURE-E03`

```text
packet_id: DV-P0B-CAPTURE-E03
status: done

outcome: Accepted harness lifecycle remains reusable, but its media path is
stale under DV-DRAFT-4. A bounded Apple-native Debug repair is feasible using
default high negotiation, no format/FPS override, passthrough composition,
transform propagation, and pre/post encoded-sample comparison.
authority_used: DV-DRAFT-4@2f3266a; revised Phase 0B E02/E04/E06; accepted
W01/R03 lifecycle and review evidence; Apple SDK headers and primary docs.
changed_paths: none
checks_run: Exact Debug harness/test/script/QA and Debug/Release isolation
inspection; SDK/API verification; scoped Git/diff checks. No build or runtime.
scope_check: Read-only; no product, dictation, storage, UI, iOS, Build,
publication, project, entitlement, or dependency change.
deviations: none
residual: Realized default-high camera format, passthrough compatibility,
sample preservation, orientation, VFR, timing, resource, and byte-rate evidence
remain hardware-dependent. DV-BUILD-6 remains separate.
next_dependency: DV-P0B-CAPTURE-W02 Debug-only native-source repair.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-W02`

```text
packet_id: DV-P0B-CAPTURE-W02
status: done

outcome: Debug-only native-source repair leaves format, frame-rate, and codec
negotiation to macOS; finalization is QuickTime passthrough-only with full
tracks and preferred-transform preservation; camera/final probes and stored-
sample preservation gate Ready.
authority_used: DV-DRAFT-4@2f3266a; revised Phase 0B protocol and plan;
accepted E03 and W01/R03 owners.
changed_paths: Thirteen exact Debug source, test, and evidence paths; commit
f7ff6bf.
reused_owners: Existing video-only capture, one run-owned microphone, R03
lifecycle, event, termination, and run-root owners.
checks_run: Structure; 45/45 focused tests; Debug build-only; bounded unsigned
Release; Debug/Release settings and artifact isolation; stale-token,
redaction, path, diff, and residue audits.
scope_check: Debug, test, and evidence only; no product, script, project,
plist, entitlement, spec, registry, UI, storage, iOS, Build, or runtime change.
deviations: none
residual: Real device, codec, passthrough, Continuity Camera, TCC, and
quantitative evidence remain.
next_dependency: DV-P0B-CAPTURE-W02-REVIEW
runtime_or_visual_handoff: none
commit: f7ff6bfd445dee1857514d21b5898ab85e59cb66
```

### `DV-P0B-CAPTURE-W02-REVIEW`

```text
packet_id: DV-P0B-CAPTURE-W02-REVIEW
status: done
verdict: accept_with_residual

outcome: Independent review accepts the thirteen-path Debug-only native-source
repair: macOS-negotiated video is preserved through passthrough-only source
finalization and robust stored-sample proof before Ready.
authority_used: DV-DRAFT-4@2f3266a; revised Phase 0B protocol and plan; E03,
W01/R03, W02, and current registry evidence.
reviewed_commit_and_parent: f7ff6bfd445dee1857514d21b5898ab85e59cb66;
a385caabb6e6c4df17cb4d3ffa89405e754dcc1c.
changed_paths: Read-only review of exactly thirteen authorized paths; no
reviewer changes.
checks_run: Exact scope/diff; structure; 45 selected and passed focused tests;
Debug build-only; bounded unsigned Release; Debug/Release settings and artifact
isolation; forbidden-override/fallback scans; plist, process, temp-root, and
worktree audits.
findings_closed_or_open: No source preset, format, frame-rate, codec, quality,
downsample, transcode, or fallback path; passthrough compatibility, full-track
insertion, transform, probes, encoded samples, timing, format, dimensions, and
Ready gating accepted. No repair finding remains.
scope_check: Debug/test/evidence only; protected product, Release, Build,
storage, UI, iOS, and publication behavior unchanged.
deviations: Successful independent tests used sanitized HOME with command-line
ad-hoc signing after two certificate-only pre-test setup failures.
residual: Real camera, microphone, TCC, Continuity, negotiated formats,
passthrough/playability, timing, resources, byte rate, and storage measurements
remain; shipping audio lease and DV-BUILD-6 are outside this acceptance.
next_dependency: Separately authorized DV-DRAFT-4 controlled hardware/runtime
evidence.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAPTURE-R05`

```text
packet_id: DV-P0B-CAPTURE-R05
status: failed
functional_result: fail

outcome: Exactly one Continuity Camera enumerated and was selected without
fallback. One functional attempt terminated before camera start with
camera_permission_required; no prompt, media, or Ready clip existed.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E02/E04/E06/E08; accepted W02
harness; finite R05 packet.
changed_paths: Eight redacted capture-R05 evidence files; commit 11cb9a2.
hardware_selection: Connected non-suspended Continuity Camera with stable
private identity retained only in memory; built-in and USB unavailable.
functional_results: Explicit selection/no fallback passed. One audio owner
started once and cancelled at the permission gate. Camera, probes, passthrough,
preservation, transform, and Ready were not exercised.
realized_media: none
measurements_disposition: All media, timing, sample, resource, byte-rate,
sync/drift, and finalization fields unavailable and evidence_only.
checks_run: Bounded enumeration and invocation; signed Debug build; structured
evidence, redaction, media, path, diff, process, protected-path, and cleanup
audits.
cleanup_receipt: Raw/private roots, scoped caffeinate, and all run-owned
processes removed; pre-existing HoldType preserved; protected paths unchanged.
scope_check: Evidence-only; no source, spec, project, TCC, UI, Keychain,
provider, external-storage, iOS, or protected-owner change.
deviations: One pre-functional invocation failed invalid_configuration because
of redirected TMPDIR and created no attempt or media; the corrected invocation
was the sole functional attempt. No capture retry occurred.
residual: Environment or signing residual: this signed Debug identity had no
ordinary Camera authorization surface during the run.
next_dependency: DV-P0B-CAPTURE-R05-REVIEW
runtime_or_visual_handoff: No Computer Use action because no prompt appeared.
commit: 11cb9a253896e98c2c5c29f6df82ce48dafd0fb0
```

### `DV-P0B-CAPTURE-R05-REVIEW`

```text
packet_id: DV-P0B-CAPTURE-R05-REVIEW
status: done
verdict: accept_with_residual
functional_cell: fail — camera_permission_required

outcome: Evidence truthfully establishes one explicitly selected Continuity
Camera, one functional permission-gated attempt, zero camera starts, and zero
Ready clips. No Debug-harness defect is implicated.
authority_used: DV-DRAFT-4@2f3266a; revised Phase 0B protocol and plan; accepted
E03/W02/R01/R02 evidence; current registry.
reviewed_commit_and_parent: 11cb9a253896e98c2c5c29f6df82ce48dafd0fb0;
c298cdc23af686e014fef8059857914a4df99fd4.
changed_paths_reviewed: Exactly eight redacted capture-R05 files; no reviewer
changes.
checks_run: Exact commit/path/blob audit; structured-data and semantic checks;
redaction/media/digest scans; accepted category provenance; process, guard,
run-root, protected-path, and current-blob audits.
classification_review: Explicit selection/no fallback passed. AVCaptureDevice
authorization was notDetermined and mapped correctly to the closed permission
category. Functional result remains fail with environment/signing residual.
cleanup_review: Sound; no media/digest, run root, process, guard, or protected-
path residue; pre-existing HoldType preserved; no external I/O.
scope_check: Evidence-only; protected product and TCC state unchanged.
deviations: Redirected-TMPDIR pre-functional failure was separate from the one
functional attempt; terminal monotonic time was unavailable and not claimed.
residual: The same signed Debug identity lacks an ordinary Camera authorization
decision; all media and quantitative evidence remain unavailable/evidence_only.
next_dependency: One bounded genuine AVCaptureDevice.requestAccess action for
the same signed Debug identity, then a separately authorized Continuity retry.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W01`

```text
packet_id: DV-P0B-CAMERA-AUTH-W01
status: done

outcome: Added an explicit Debug-only Camera authorization mode for the same
early-isolated signed HoldType identity. It requests video access exactly once
only from notDetermined, returns closed redacted bounded results, writes one
terminal event, and constructs no capture, audio, media, or product owner.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted
E03/W01/R03/W02/R05 evidence and reviews; Apple AVFoundation API.
changed_paths: New Debug authorization source and tests; Debug launch and event
integration; existing spike script; W01 QA summary; commit 5b3ed20. Six paths.
reused_owners: Existing pre-product Debug entry/isolation, R03 termination,
JSONL event owner, signed Debug plist/entitlements, and exact script supervisor.
checks_run: Structure; 8/8 authorization and 53/53 full Phase 0B logical tests;
signed Debug build-only; bounded Release scheme compile; Debug/Release settings
and artifact isolation; script help/negative/build-only/structural checks;
redaction, owner, path, wrapper, diff, process, and residue audits.
behavior_verified: All authorization statuses; exact-one request and terminal;
grant/deny/restrict, timeout, cancellation, late/duplicate callback; early
route isolation; no capture/audio/product construction.
scope_check: Exact six-path Debug/test/script/evidence commit; no project,
plist, entitlement, product, Release, iOS, storage, or media-owner change; no
hardware, TCC, app/UI, provider/Keychain, Computer Use, or external I/O.
deviations: A non-authoritative direct-target Release experiment hit existing
local-package module resolution; authoritative Release scheme checks passed.
residual: Genuine prompt/authorization remains a separate runtime action; R05
is not retroactively relabeled and all camera/media evidence remains open.
next_dependency: DV-P0B-CAMERA-AUTH-W01-REVIEW
runtime_or_visual_handoff: none
commit: 5b3ed205a4e1669379accda43811755c09b5a2b6
```

### `DV-P0B-CAMERA-AUTH-W01-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-W01-REVIEW
status: done
verdict: accept_with_residual

outcome: The same-signed-identity Debug Camera authorization seam is accepted
as early-isolated, exact-once, bounded, redacted, and free of capture, audio,
media, or product-owner construction.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted
E03/W01/R03/W02/R05 evidence; exact authorization packet and receipt.
reviewed_commit_and_parent: 5b3ed205a4e1669379accda43811755c09b5a2b6;
ca1f117e33139f1e28bec45c7ba7e933c777c798.
changed_paths_reviewed: Exactly six authorized paths; no reviewer changes.
checks_run: Exact diff/path/mode/blob and structure; 8/8 authorization and
53/53 full Phase 0B tests; script syntax/help/negatives/build-only; bounded
Release; Debug/Release settings and artifact isolation; owner, redaction,
process, temp-root, and worktree audits.
findings_closed_or_open: Explicit routing and signed identity; notDetermined-
only exact request; all closed statuses; independent callback timeout/cancel;
exact-one redacted terminal; no forbidden owners; script and Release isolation.
No repair remains.
scope_check: Debug/test/script/evidence only; product, project, plist,
entitlement, signing, bundle, Release, UI, storage, iOS, Build, and publication
unchanged.
deviations: Fake tests used ad-hoc signing under sanitized HOME; repository
build-only retained the established Apple Development identity.
residual: Genuine Camera prompt/decision and all capture/media/quantitative
evidence remain open; R05 remains unchanged.
next_dependency: One bounded same-signed-identity permission invocation, then
evidence review before capture retry.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-R01`

```text
packet_id: DV-P0B-CAMERA-AUTH-R01
status: done
authorization_result: timeout

outcome: The accepted same-signed Debug Camera authorization mode was invoked
exactly once and closed naturally as camera_authorization_timed_out. Camera
capture and Microphone were not run; no retry occurred.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission and cleanup boundaries;
accepted W01 seam/review, R05 review, and R03 lifecycle.
changed_paths: Seven redacted capture-auth-R01 evidence files; commit 4f0efb5.
identity_evidence: Existing Debug bundle and Apple Development signing class,
Camera purpose, and Camera/audio-input entitlements preserved; no private
signing material retained.
prompt_and_action: Computer Use skill used. One bounded attach to the exact
Debug identity timed out; no prompt action, alternate surface, System Settings,
TCC reset, or second request.
event_results: Exactly one request start and one terminal timeout; monotonic
values unavailable and not fabricated.
checks_run: Structured evidence and count checks; redaction/media/path/diff;
post-commit process, root, guard, and protected-path audits.
cleanup_receipt: Script exited naturally; no temp root, run-owned process, or
guard remains; pre-existing HoldType and protected paths preserved; no
external/remote I/O.
scope_check: Evidence-only; no source, spec, project, signing, TCC, product,
UI, camera, mic, media, provider, Keychain, storage, or iOS change.
deviations: Auxiliary private watcher missed its glob and retained no raw
event; normalized evidence used the accepted closed operator summary. Computer
Use could not attach to the activation-prohibited Debug identity.
residual: Final Camera authorization state remains unknown; timeout is neither
grant nor denial and authorizes no capture retry.
next_dependency: DV-P0B-CAMERA-AUTH-R01-REVIEW
runtime_or_visual_handoff: none
commit: 4f0efb557ab4502b16bac8881e731319c6ff16ad
```

### `DV-P0B-CAMERA-AUTH-R01-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-R01-R1
status: done

outcome: Repaired the summary-only contradiction: certainty is limited to no
tccutil reset or direct database operation, while final authorization and any
system-managed TCC state after requestAccess remain explicitly unknown.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; rejected AUTH-R01 review.
changed_paths: capture-auth-R01/summary.md only; commit 308a191.
checks_run: Exact one-path and unchanged-evidence audit; contradiction scan;
structured-evidence unchanged; redaction, diff, and worktree checks.
scope_check: Documentation repair only; no runtime, TCC, UI, source, build,
test, or other evidence action.
deviations: none
residual: Authorization and system-managed TCC state remain unknown; timeout
remains neither grant nor denial.
next_dependency: DV-P0B-CAMERA-AUTH-R01-REVIEW-R1
runtime_or_visual_handoff: none
commit: 308a191a55de44971f036352561a9e3b8664fa15
```

### `DV-P0B-CAMERA-AUTH-R01-REVIEW-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-R01-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: The summary-only repair closes the TCC contradiction. Evidence now
truthfully supports one same-signed request, one terminal timeout, zero retries,
and no capture, microphone, media, or product owner.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; prior rejection; accepted
authorization seam and review; exact repair.
reviewed_commit_and_parent: 308a191a55de44971f036352561a9e3b8664fa15;
2d0d6e4bcb3372051a0ed09ec898b9a94879a0a9.
changed_paths_reviewed: capture-auth-R01/summary.md only; other six evidence
blobs unchanged.
checks_run: Exact commit/path/blob and diff; contradiction/required-wording;
structured-evidence spot checks; redaction/media and zero-residue snapshot.
claim_repair_review: Broad unchanged-TCC claims are gone; only no tccutil reset
or direct database operation is claimed, and final authorization/system state
remains unknown.
scope_check: Documentation-only repair; no source, runtime, UI, TCC, signing,
media, or other evidence change.
deviations: Original watcher and Computer Use limitations remain disclosed.
residual: Authorization remains timed out; prompt and final state are unknown.
user_action_required: Enable HoldType under System Settings > Privacy &
Security > Camera and verify On; if absent, stop. No reset or blind retry.
next_dependency: Verify the switch On, then separately authorize Continuity
capture without another blind permission request.
runtime_or_visual_handoff: Exact Camera settings action only.
```

### `DV-P0B-CAMERA-AUTH-R02`

```text
packet_id: DV-P0B-CAMERA-AUTH-R02
status: done
permission_state: holdtype_row_absent

outcome: Computer Use opened System Settings > Privacy & Security > Camera and
found no HoldType row, so no switch existed and no setting changed.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission/cleanup boundary;
accepted AUTH-R01 repair/review.
changed_paths: Seven redacted capture-auth-R02 evidence files; commit 36445d2.
computer_use_actions: Opened System Settings, navigated to Camera privacy,
inspected HoldType row presence, and closed the packet-opened window. No switch,
unrelated-row, or authentication action.
verification: HoldType row absent; On/Off and authorization state unavailable;
no screenshot retained.
checks_run: Structured evidence and counts; unrelated-name/private-token/media/
MIME/screenshot scans; exact path/diff; process/root/guard/protected audits.
cleanup_receipt: Packet-opened window closed; exact lingering System Settings
PID identity-validated and TERM-cleaned; scoped guard stopped; pre-existing
HoldType and protected paths preserved.
scope_check: Evidence-only; no requestAccess, camera, mic, media, TCC reset/DB,
source, project, signing, product, provider, Keychain, external, or iOS action.
deviations: System Settings required exact run-owned TERM after UI quit left it
resident.
residual: Row absence establishes neither grant nor denial and exposes no
operator switch.
next_dependency: DV-P0B-CAMERA-AUTH-R02-REVIEW
runtime_or_visual_handoff: Exact Camera pane only; no screenshot or capture.
commit: 36445d2fb0a9fd6ad9bc7b95831c4fa867596481
```

### `DV-P0B-CAMERA-AUTH-R02-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-R02-REVIEW
status: done
verdict: accept_with_residual
permission_cell: not_available — holdtype_row_absent

outcome: Computer Use evidence supports that the Camera pane had no visible
HoldType row and no setting changed. Row absence establishes neither grant nor
denial and provides no manual switch.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted
AUTH-R01 repair/review; exact R02 evidence.
reviewed_commit_and_parent: 36445d2fb0a9fd6ad9bc7b95831c4fa867596481;
04134352f932381268afff74a55e4b86e5906640.
changed_paths_reviewed: Exactly seven redacted evidence files; no changes.
checks_run: Exact diff/path/blob; structured chronology; Computer Use and
no-action checks; redaction/media/path scans; process, guard, run-root, and
protected-path snapshot.
classification_review: Camera pane open, HoldType row unavailable, terminal
closure; zero switch/unrelated/auth/request/capture/mic/media/TCC actions.
cleanup_review: Exact lingering System Settings process was identity-validated
and boundedly terminated; no residue and pre-existing HoldType preserved.
scope_check: Exact evidence-only scope; no product, signing, TCC, storage, or
iOS change.
deviations: Packet-opened System Settings remained resident after UI quit and
required exact TERM cleanup.
residual: Authorization remains unknown; no manual switch or capture retry.
next_dependency: Debug-only activation-before-request repair limited to Launch,
authorization tests, and W01 summary, then review and one permission runtime.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W02`

```text
packet_id: DV-P0B-CAMERA-AUTH-W02
status: done

outcome: Explicit Debug Camera-authorization mode makes the same signed process
regular/active and boundedly confirms activation before the existing
authorization harness. Activation failure returns closed unknown without an
authorization call; normal Debug and hardware routes remain unchanged.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted AUTH
W01/R01/R02 reviews and R03 lifecycle.
changed_paths: Debug Launch, authorization tests, and W01 summary; commit
f35ac7f.
reused_owners: Early Debug route/isolation, signed app identity, authorization
owner/categories/120s bound, R03 termination, script, Debug plist/entitlements.
checks_run: Structure; 11/11 authorization and 56/56 full Phase 0B tests;
signed Debug build-only; bounded unsigned Release; Debug/Release settings and
artifact isolation; route, redaction, path, diff, process, and residue audits.
behavior_verified: Auth-only policy then activation then status/request order;
both activation failures prevent authorization; normal/hardware routes do not
activate or authorize; existing authorization cases preserved.
scope_check: Exact three Debug/test/evidence paths; no script, project, plist,
entitlement, product, capture, audio, media, storage, UI, iOS, or Release
semantic change; no TCC/runtime/Computer Use.
deviations: Initial test helper/token issues were repaired before green suites;
existing unrelated Release warnings remain.
residual: Genuine same-identity permission runtime and review remain; no
prompt, grant, row, capture, media, or TCC-state claim.
next_dependency: DV-P0B-CAMERA-AUTH-W02-REVIEW
runtime_or_visual_handoff: none
commit: f35ac7f3659f660e14d596ff0e2e6eb6fa1695be
```

### `DV-P0B-CAMERA-AUTH-W02-REVIEW-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W02-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Debug-only activation-before-authorization is accepted. Explicit mode
establishes regular/active process state before the unchanged authorization
seam; failure closes redacted without request. No product/hardware/Release
regression found.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted AUTH
W01/R01/R02 and R03 lifecycle; corrected exact commit.
reviewed_commit_and_parent: f35ac7f3659f660e14d596ff0e2e6eb6fa1695be;
f8e0cc00e6e90294d477a1a4e63fbae9cdd3f2ef.
changed_paths_reviewed: Debug Launch, authorization tests, and W01 summary;
current blobs exact.
checks_run: Exact diff/path/blob; structure; 11/11 authorization and 56/56
full tests; signed Debug build-only; bounded Release; Debug/Release settings,
plist, entitlement, binary isolation; owner/redaction/process/root audits.
findings_closed_or_open: Explicit-route-only activation; MainActor policy then
activation then bounded confirmation then authorization; both failures skip
request; no window/product/capture/audio/media owner; behavioral tests and
truthful fake/build-only claims accepted. No repair remains.
scope_check: Exact three-path Debug/test/evidence scope; protected owners,
script, configuration, signing, Release, storage, UI, iOS, Build unchanged.
deviations: Sanitized tests used ad-hoc signing; Release evidence is compile/
settings/plist/binary isolation, not signing qualification.
residual: Genuine active permission prompt/decision, Camera row, capture/media,
and quantitative evidence remain.
next_dependency: One bounded active same-signed authorization runtime, then
review before capture.
runtime_or_visual_handoff: Explicit permission mode only; no capture.
```

### `DV-P0B-CAMERA-AUTH-R03`

```text
packet_id: DV-P0B-CAMERA-AUTH-R03
status: failed
authorization_result: unknown

outcome: The accepted active same-signed permission route ran exactly once and
closed naturally as camera_authorization_unknown. Capture and microphone were
not run; active-state confirmation and requestAccess start are not established.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission/cleanup; accepted AUTH
W02/review and prior AUTH evidence.
changed_paths: Seven redacted capture-auth-R03 evidence files; commit 744f313.
identity_evidence: Accepted activation blobs and Debug identity/configuration
were verified without retaining private identity.
computer_use_actions: Bounded post-terminal observation; process already exited,
no prompt, click, System Settings, or screenshot.
event_results: One route start and one closed unknown terminal. Authorization
harness/requestAccess start is not claimed because activation may have failed.
checks_run: Ancestry/blob/config/artifact; bounded route; structured data,
redaction/media/path/diff; process/root/guard/protected cleanup.
cleanup_receipt: No run-owned process/root/media/guard; pre-existing HoldType and
protected paths preserved; no external I/O.
scope_check: Evidence-only; no source, configuration, product UI, capture, mic,
media, provider, storage, iOS, Build, publication, or direct TCC change.
deviations: Route exited before Computer Use could observe it; no retry/fallback.
residual: Unknown does not distinguish pre-harness activation failure from an
unknown post-activation status and authorizes no capture.
next_dependency: DV-P0B-CAMERA-AUTH-R03-REVIEW
runtime_or_visual_handoff: none
commit: 744f313e1d1aa24e91e0be9ed7b11a96e3baeb67
```

### `DV-P0B-CAMERA-AUTH-R03-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-R03-REVIEW
status: done
verdict: accept_with_residual
authorization_cell: fail — Debug-spike diagnostic defect

outcome: Evidence truthfully records one route invocation and one unknown
terminal, but environment/signing is not accepted: the Debug seam collapses
multiple internal stages into the same category.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted AUTH
W02/review; exact R03 evidence and narrow source trace.
reviewed_commit_and_parent: 744f313e1d1aa24e91e0be9ed7b11a96e3baeb67;
6681497a4e074e142a28ab3d628293444ff88e12.
paths: Exactly seven redacted evidence files; no changes.
checks: Exact diff/path/blob; structured semantics; configuration provenance;
activation/authorization trace; Computer Use timing; redaction/media/path and
zero-residue audits.
classification: Unknown may mean policy failure, activation reject/cancel/
timeout, harness setup failure, or unknown AVFoundation status. Activation,
harness entry, and requestAccess start are unproven; no prompt/grant/denial.
cleanup: Sound; no run-owned residue and pre-existing HoldType preserved.
scope: Evidence-only; accepted source/configuration and protected domains
unchanged.
deviations: Process exited before Computer Use observation; no retry/fallback.
residual: Authorization remains unknown and capture blocked.
next_dependency: Original Debug authorization owner adds closed stage/result
categories and furthest-stage evidence in five named paths, then review.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W03`

```text
packet_id: DV-P0B-CAMERA-AUTH-W03
status: done

outcome: Replaced catch-all authorization unknown with closed activation-policy,
activation-rejection, activation-timeout, activation-cancel, harness-unavailable,
and post-activation status-unknown outcomes; terminal evidence carries one
compact monotonic furthest_stage.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted AUTH
W01/W02/R03 receipts and reviews.
changed_paths: Debug authorization, event, and launch; authorization tests; W01
summary; commit 1ae703f.
reused_owners: Same-signed Debug route, exact-one request/120s bridge, R03
termination, event log, Debug configuration, and script supervisor.
checks_run: Structure; 14/14 auth and 59/59 full Phase 0B tests; signed Debug
build-only; bounded unsigned Release; Debug/Release settings/artifact isolation;
redaction, route, wrapper, path, diff, process, and residue audits.
behavior_verified: Closed pre/status/request stages; monotonic frozen terminal;
late callback/cancel safety; no authorization after prior failure; normal and
hardware routes have no authorization activity.
scope_check: Exact five Debug/test/evidence paths; all Swift DEBUG and <=500;
no script, project, configuration, product, capture/audio/media, storage, iOS,
Release, runtime, TCC, or UI change.
deviations: One audit shell shadowed PATH with zsh special variable and was
corrected/rerun green; no product impact.
residual: Historical R03 remains unknown; a new permission runtime and review
remain before capture.
next_dependency: DV-P0B-CAMERA-AUTH-W03-REVIEW
runtime_or_visual_handoff: none
commit: 1ae703fa0a4ced0cea0b73ef8ffeee85adb2ac13
```

### `DV-P0B-CAMERA-AUTH-W03-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W03-R1
status: done

outcome: Live activation calls are independently injected; a false process
activation returns activation_rejected before the second activation, polling,
authorization status, or requestAccess.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; exact W03 rejection.
changed_paths: CameraAuthorization source and authorization tests; commit
0e9f032. Summary unchanged.
reused_owners: W03 categories/stages/exact-one, request bridge, W02 activation,
R03 termination, script, and Debug/Release configuration.
checks_run: Structure; 14/14 auth and 59/59 full tests; signed Debug build-only;
bounded Release/isolation; diff, wrapper, redaction, path, process, root audits.
behavior_verified: First rejection makes one process activation and zero app
activation/status/request calls; exact category/stage and one terminal. Success
order and active timeout/cancel remain green.
scope_check: Exact two Debug/test paths; no other source, script, configuration,
product, capture/audio/media, Release, runtime, TCC, or UI change.
deviations: none
residual: Historical R03 remains unknown; permission runtime remains.
next_dependency: DV-P0B-CAMERA-AUTH-W03-REVIEW-R1
runtime_or_visual_handoff: none
commit: 0e9f032959876aa92b4eea2f32e60bf9c22194dd
```

### `DV-P0B-CAMERA-AUTH-W03-REVIEW-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W03-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: Repair closes activation rejection: false process activation suppresses
secondary activation, polling, status, and requestAccess while emitting one
truthful rejection terminal at activation_requested.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; prior W03
rejection; exact repair.
reviewed_commit_and_parent: 0e9f032959876aa92b4eea2f32e60bf9c22194dd;
41f513e62cc0c8213b29402f796b15bfab3b2922.
paths: CameraAuthorization source and authorization tests only.
checks: Exact diff/path/blob; structure; 14/14 auth and 59/59 full tests;
signed Debug build-only; bounded Release/isolation; redaction/owner/process/root.
findings: Rejection stops after process activation; separate-call behavioral
counts and exact category/stage/terminal pass. Success ordering, timeout/cancel,
all W03 categories/stages, request bounds, late freeze, and protected routes
remain intact.
scope: Exact two-path Debug/test repair; no other source/configuration/product/
runtime/TCC/UI/Release change.
deviations: none
residual: Genuine authorization and capture/media evidence remain.
next_dependency: One bounded repaired permission runtime, then review.
runtime_or_visual_handoff: Explicit permission mode only; no capture.
```

### `DV-P0B-CAMERA-AUTH-R04`

```text
packet_id: DV-P0B-CAMERA-AUTH-R04
status: failed
authorization_result: unknown
furthest_stage: activation_requested

outcome: One repaired same-signed permission route closed as
camera_authorization_activation_rejected before authorization status or
requestAccess; capture and microphone were not run.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission/cleanup; accepted W03
repair/review; prior AUTH evidence.
changed_paths: Seven redacted capture-auth-R04 evidence files; commit baafcb9.
identity_evidence: Accepted repair/configuration and signed Debug class verified;
no private identity retained.
computer_use_actions: Exact Debug process observed, but bounded attachment could
not reach its permission surface; no prompt, click, System Settings, screenshot.
event_results: One route start and one terminal activation rejection at
activation_requested; no authorization/request start.
checks_run: Ancestry/config/artifact; bounded route/process observation;
structured data, redaction/media/path/diff; cleanup audits.
cleanup_receipt: One exact Debug process outlived script terminal and required
fresh identity-validated TERM; all run-owned process/root/guard residue zero;
pre-existing HoldType and protected paths preserved.
scope_check: Evidence-only; no source/configuration/product/capture/mic/media/
TCC/System Settings/provider/storage/iOS/Build/publication change.
deviations: Computer Use attachment unavailable; post-terminal Debug process
lifetime required exact cleanup.
residual: Activation rejected before authorization; cleanup lifetime requires
review classification. No capture authority.
next_dependency: DV-P0B-CAMERA-AUTH-R04-REVIEW
runtime_or_visual_handoff: none
commit: baafcb9d46ba8b33a1830ffcd0d7b38eacf4d4e6
```

### `DV-P0B-CAMERA-AUTH-R04-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-R04-REVIEW
status: done
verdict: accept_with_residual
authorization_cell: fail — activation-semantics and natural-cleanup defects

outcome: Evidence truthfully proves immediate process-activation false and no
authorization, but environment/signing is rejected: Boolean semantics and a
surviving post-terminal Debug process are Debug-spike defects.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; accepted W03 repair/review; exact
R04 evidence; installed AppKit SDK headers.
reviewed_commit_and_parent: baafcb9d46ba8b33a1830ffcd0d7b38eacf4d4e6;
75ecba85a1a234babf9b98e216c09b7f2d53cbe3.
paths: Exactly seven redacted evidence files.
checks: Exact diff/path/blob; structured semantics; source termination and
activation trace; SDK headers; Computer Use; redaction/media/path/residue.
classification: NSRunningApplication Boolean reports only whether that request
was sent, not overall activation. Use NSApplication.activate once and bounded
isActive observation. Post-terminal process survival violates accepted natural
termination/supervision ownership.
cleanup: External exact TERM was safe and residue is zero, but does not close
the natural-exit defect.
scope: Evidence-only; protected owners unchanged.
deviations: Computer Use could not attach; one run-owned Debug PID required TERM.
residual: Permission unknown; no request or capture authority.
next_dependency: Read-only activation/termination/script/SDK exploration, then
bounded repair and independent review.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-E04`

```text
packet_id: DV-P0B-CAMERA-AUTH-E04
status: done

outcome: A bounded repair is supported: one NSApplication.activate request plus
bounded isActive observation, next-main-turn natural termination, and exact
direct-app-PID permission-script supervision/reap.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; accepted AUTH/R03 evidence;
installed AppKit headers and primary Apple docs.
changed_paths: none
checks_run: Read-only source, test, script, evidence, configuration, SDK-header,
and primary-documentation inspection.
activation_api: Set regular policy, call NSApplication.activate once, poll
isActive under existing bound; timeout/cancel remain closed at activation_requested.
termination_trace: Completion is MainActor and delegate returns terminateNow;
exact R04 AppKit failure point is unproven. Defer terminate to next main turn.
script_repair: Permission mode must own/reap direct app PID, require bounded
natural exit after terminal, identity-check before TERM/KILL fallback, and fail
the run when fallback is needed. Hardware supervisor remains unchanged.
scope_check: Debug authorization/termination/permission supervisor only;
product, hardware capture, audio/media/storage/UI/iOS/Build/Release protected.
deviations: none
residual: Real natural exit and Camera permission remain evidence-needed.
next_dependency: Six-path W04 repair, independent review, then one permission
runtime.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W04`

```text
packet_id: DV-P0B-CAMERA-AUTH-W04
status: done

outcome: Repaired authorization to one NSApplication activation with bounded
isActive, deferred natural termination one main turn, and direct signed-app-PID
supervision/reap under one 420-second permission bound.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted R04
review and E04 evidence.
changed_paths: Authorization and Launch source/tests, permission script, W01
summary; commit b2a2abf.
reused_owners: W03 categories/stages/request bridge, R03 termination, same
Debug identity/configuration, unchanged hardware supervisor.
checks_run: Structure; 59 logical tests; signed Debug build-only; bounded
Release/isolation; script syntax/help/negatives and natural/stuck/mismatch/trap
supervisor fakes; diff/redaction/path/process/root audits.
behavior_verified: One activate then bounded active observation; normal/hardware
no auth; terminal/task-clear/completed then deferred terminate; external-quit
race; direct PID identity, terminal observation, natural reap or exact bounded
TERM/KILL failure. Hardware path unchanged.
scope_check: Exact six Debug/test/script/evidence paths; no product, capture,
mic, media, TCC/runtime UI, configuration/signing, Release, storage, iOS,
Build, publication, or dependency change.
deviations: Non-authoritative fake path spelling was canonicalized and rerun.
residual: Genuine permission and natural-exit runtime remain.
next_dependency: DV-P0B-CAMERA-AUTH-W04-REVIEW
runtime_or_visual_handoff: none
commit: b2a2abfe6e466d32b9b43b6bb43f629a03966101
```

### `DV-P0B-CAMERA-AUTH-W04-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W04-R1
status: done

outcome: Permission direct-PID supervision uses one absolute monotonic deadline
from immediately before launch through identity, terminal, exit, signals, reap,
and trap cleanup; expiry fails without signaling an unproven identity.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; exact W04 rejection.
changed_paths: Permission script and W01 summary; commit 48c0d5c.
reused_owners: Accepted W04 activation/termination/direct-PID identity; hardware
supervisor unchanged.
checks_run: Script syntax/help/negatives/build-only; natural/stuck/mismatch/trap/
slow-identity fakes; deadline injection; structural remaining-budget audit;
hardware-tail, redaction, path, diff, process, root audits.
behavior_verified: One <=420s post-launch bound; natural reap; exact fallback
failure; mismatch/expiry no signal; trap shares deadline. Slow fake exited in
2.041s under 2s injected deadline and no-signal, within 2.25s wall bound.
scope_check: Exact two script/evidence paths; no Swift, product, runtime, TCC,
hardware, or configuration change.
deviations: none material
residual: Genuine permission runtime remains.
next_dependency: DV-P0B-CAMERA-AUTH-W04-REVIEW-R1
runtime_or_visual_handoff: none
commit: 48c0d5cd34e9b208ade6b1ae61498fa8f77ee254
```

### `DV-P0B-CAMERA-AUTH-W04-REVIEW-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W04-REVIEW-R1
status: done
verdict: accept_with_residual

outcome: One absolute elapsed-time deadline now bounds permission supervision,
including identity and terminal probes, sleeps, natural exit, revalidation,
TERM/KILL, reap, and trap cleanup. Expiry refuses uncertain signaling.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; prior W04
rejection; exact repair 48c0d5c.
changed_paths: none
checks_run: Exact two-path diff; remaining-budget trace; independent natural,
stuck, identity-mismatch, trap, and slow-identity fakes; script syntax/help and
negatives; signed Debug build-only; hardware-tail identity; redaction, process,
root, and worktree audits.
scope_check: Exact repair review only; no Swift, product, Release, hardware,
TCC, signing, capture, audio, media, storage, UI, or configuration change.
deviations: none material
residual: Genuine same-signed Camera permission runtime remains unexecuted.
next_dependency: One bounded permission-only runtime, followed by evidence
review before any capture retry.
runtime_or_visual_handoff: Permission runtime only; no capture or microphone.
reviewed_commit: 48c0d5cd34e9b208ade6b1ae61498fa8f77ee254
```

### `DV-P0B-CAMERA-AUTH-R05`

```text
packet_id: DV-P0B-CAMERA-AUTH-R05
status: failed

outcome: Exactly one accepted same-signed Debug permission route closed before
authorization status or requestAccess; no retry, capture, or microphone run.
category: camera_authorization_activation_timed_out
furthest_stage: activation_requested
prompt_action: Computer Use could not attach to the exact Debug bundle in its
bounded attempt; no genuine Camera prompt was seen and no click occurred.
natural_exit_vs_fallback: The supervised direct app PID exited naturally within
the global deadline and needed no supervisor signal. A distinct same-launch
Debug process outlived script exit and required one freshly identity-validated
exact TERM cleanup.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission and cleanup boundaries;
accepted W04-R1 repair/review.
changed_paths: Seven redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-auth-r05/; commit 4101f74.
checks_run: Accepted ancestry/config/signing; exact route/start/terminal counts;
structured-data, redaction, media-absence, scope, diff, process, root, guard,
and protected-path audits.
cleanup_receipt: Guard and all run-owned Debug processes/roots removed;
pre-existing HoldType preserved; protected paths unchanged.
scope_check: Evidence-only; no source, specification, configuration, signing,
TCC, System Settings, camera, microphone, media, product, provider, Keychain,
external-storage, or iOS change.
deviations: Computer Use attachment unavailable; one additional same-launch
Debug process required exact bounded cleanup TERM.
residual: Environment/signing residual at activation_requested; independent
review must classify the additional-process lifetime as evidence or defect.
next_dependency: DV-P0B-CAMERA-AUTH-R05-REVIEW
runtime_or_visual_handoff: none
commit: 4101f7439cae82dd630c746d802ea2cc62179176
```

### `DV-P0B-CAMERA-AUTH-R05-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-R05-REVIEW
status: done
verdict: accept_with_residual

outcome: Evidence truthfully establishes one same-signed Debug permission
route terminating at activation timeout before authorization. The separate
same-launch Debug process is a remaining launch/supervision defect, not an
environment-only residual.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E02/E04/E06/E08; governing plan;
accepted W04/W04-R1 evidence and reviews.
reviewed_commit_and_parent: 4101f7439cae82dd630c746d802ea2cc62179176;
781d8c4161aa8acbd8a5c99e9f9c8d0c0624f0da.
changed_paths: none
checks_run: Exact seven-file commit/path/blob; structured-data cross-check;
accepted category/termination trace; redaction, path, MIME, media, screenshot,
private-identity, process, root, guard, protected-path, and worktree audits.
category_and_stage: One route start and one
camera_authorization_activation_timed_out terminal at activation_requested;
authorization status/requestAccess, prompt, capture, microphone, and media were
not reached.
direct_pid: The directly launched supervised PID exited naturally and was
reaped inside the absolute deadline without supervisor signal.
additional_process: A distinct run-owned Debug executable survived script exit
and required one exact identity-validated TERM. Its creation mechanism remains
unproven and is a Debug-spike launch/supervision defect.
cleanup: Exact cleanup was safe; no run-owned residue; pre-existing HoldType and
protected storage preserved.
scope_check: Evidence-only; no product, source, configuration, TCC, camera,
microphone, media, storage, UI, iOS, Build, or publication change.
deviations: Bounded Computer Use attachment failed and performed no action;
additional process required exact TERM.
residual: Permission remains not reached; no permission or capture retry is
authorized before ownership repair and review.
next_dependency: Bounded read-only launch/process-ownership exploration, then
the smallest proven repair and independent review.
runtime_or_visual_handoff: none
reviewed_commit: 4101f7439cae82dd630c746d802ea2cc62179176
```

### `DV-P0B-CAMERA-AUTH-E05`

```text
packet_id: DV-P0B-CAMERA-AUTH-E05
status: done

outcome: The exact creator of the second R05 process is not recoverable from
retained evidence. A script-only fail-closed multi-process ownership repair can
capture the missing topology and supervise every proven run-owned process.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted
W04/W04-R1 and R05 evidence/review; repository Swift/tooling rules; installed
ps and lsof documentation.
changed_paths: none
evidence_inspected: Exact Debug app entry, authorization, launch, permission
script, focused tests, W01 summary, all R05 files, and narrow Git history.
process_ownership: Permission mode launches one direct env-exec child; build
work finishes before launch; inspected Swift contains no explicit process or
relaunch path. Current scalar supervision loses visibility after its direct
child exits. R05 retained no second PID, PPID, command, start time, or marker.
minimal_repair: Script baselines the exact Debug executable, proves new
run-owned identities with exact executable/start/command plus the unique run-
root environment marker, supervises all proven identities under one deadline,
signals only after fresh proof, fails without signaling uncertainty, and keeps
the hardware block byte-identical. Update only the stale script-structure test
and W01 summary with the fake matrix.
checks_run: Read-only source/history/man-page and diff-hygiene inspection; no
build, test, launch, signal, camera, microphone, or runtime action.
scope_check: Debug permission launch/process ownership only; no product,
configuration, TCC, capture, media, storage, UI, iOS, Build, or publication.
deviations: none
residual: A reparented process may keep creator unknown even when marker proves
run ownership; an unmarked same-binary process must remain unsignaled and make
the run inconclusive.
next_dependency: Script/test/summary repair and independent review.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W05`

```text
packet_id: DV-P0B-CAMERA-AUTH-W05
status: done

outcome: Implemented marker-bound multi-process permission supervision with
exact executable identity, ownership registry, quiet rescan, and identity-safe
cleanup under one absolute deadline.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; accepted E05 evidence.
changed_paths: Permission spike script, authorization script-structure tests,
and W01 summary; commit b071056.
reused_owners: Accepted W04 deadline, direct-child reap ownership, sanitized
permission launch, and hardware supervisor.
checks_run: Structure; 14/14 authorization and 59/59 full Phase 0B tests;
17/17 deterministic supervisor fakes; signed Debug build-only; bounded unsigned
Release; Debug/Release settings and artifact isolation; syntax/help/negatives;
redaction, diff, path, process, and residue audits.
behavior_verified: Baseline protection; marked additional-process discovery;
natural exit; truthful TERM/KILL fallback failure; unmarked/mismatched
no-signal behavior; late quiet-rescan discovery; topology; traps; one deadline.
hardware_tail_proof: Byte-identical to 48c0d5c.
scope_check: Exact three-path Debug test/tooling/evidence repair; no product
source, TCC, permission runtime, camera, microphone, media, hardware, storage,
UI, iOS, Build, or publication action.
deviations: One commit invocation used incorrect option ordering and made no
change; corrected invocation succeeded.
residual: Genuine same-identity permission runtime remains blocked pending
independent review.
next_dependency: DV-P0B-CAMERA-AUTH-W05-REVIEW
runtime_or_visual_handoff: none
commit: b07105647dce52de4f2a1659d60839bf79a36178
```

### `DV-P0B-CAMERA-AUTH-W05-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-W05-REVIEW
status: done
verdict: accept_with_residual

outcome: Marker-bound multi-process permission supervision is accepted.
Ownership discovery, signaling, cleanup, and deadline behavior are bounded and
fail closed without affecting hardware or product paths.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; accepted E05 map; exact W05
repair; repository Swift/tooling rules.
reviewed_commit_and_parent: b07105647dce52de4f2a1659d60839bf79a36178;
f94705687235db834e12db2bf762741a36a97f30.
changed_paths: none
checks_run: Exact three-path commit; structure; 14/14 authorization and 59/59
full Phase 0B tests; signed Debug build-only; bounded Release/isolation;
syntax/help/negatives; static registry/marker/deadline/signal/redaction audit;
independent process fakes; final process/root/worktree audit.
findings_closed: Exact baseline and marker ownership; no signal to unmarked,
mismatched, baseline, or different executable; fresh pre-signal proof; one
deadline; quiet rescan; direct-child-only reap; traps and uncertainty fail
closed.
behavioral_fake_evidence: Direct/additional/late natural exits, pre-existing
survival, unmarked and mismatch no-signal, stuck TERM/KILL truthful failure,
identity change before KILL, slow deadline, TERM/INT traps all passed.
hardware_preservation: Hardware tail and sanitized permission launch block are
byte-identical to 48c0d5c.
scope_check: Exact Debug test/tooling/evidence scope; no product source, TCC,
camera, microphone, media, storage, UI, iOS, Build, publication, configuration,
project, or dependency change.
deviations: Release stabilization phase re-signed the artifact despite
CODE_SIGNING_ALLOWED=NO; compile and isolation evidence remained valid.
residual: Genuine same-signed Camera permission runtime remains unexecuted. A
very fast natural exit may conservatively return inconclusive/root retention,
but never signals uncertainty or reports false success.
next_dependency: One bounded permission-only runtime and evidence review.
runtime_or_visual_handoff: Permission route only; no capture or microphone.
reviewed_commit: b07105647dce52de4f2a1659d60839bf79a36178
```

### `DV-P0B-CAMERA-AUTH-R06`

```text
packet_id: DV-P0B-CAMERA-AUTH-R06
status: failed

outcome: Exactly one accepted W05 same-signed Debug permission route closed
before authorization status or requestAccess; no retry or capture.
category: camera_authorization_activation_timed_out
furthest_stage: activation_requested
prompt_action: none; the route closed before safe exact-app attachment, and the
protected installed HoldType surface was not operated.
topology: One proven direct marker-owned identity with sanitized script-sibling
topology; zero additional or uncertain identities; no retained root.
process_disposition: Direct child exited naturally and was reaped; quiet rescan
passed; every proven identity exited before script success; no TERM/KILL.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission/E08; accepted W05 and
review.
changed_paths: Seven redacted files under
docs/qa/runs/dev-vlogs-phase-0b-capture-auth-r06/; commit a7f47a9.
checks_run: Mandatory/spec/Computer Use gate; accepted ancestry/config/signing;
structured-data and exact-count checks; topology/redaction/media/path/diff;
post-commit process/root/guard/protected-path audits.
cleanup_receipt: Run root and guard removed; run-owned processes zero;
pre-existing HoldType and protected storage preserved.
scope_check: Evidence-only; no source, specification, configuration, signing,
TCC, System Settings, camera, microphone, media, product, provider, Keychain,
external storage, or iOS change.
deviations: Exact Debug UI attachment was unavailable before terminal; no
generic-app fallback.
residual: Environment/signing activation failure; authorization not reached.
The R05 additional-process defect did not reproduce under W05 supervision.
next_dependency: DV-P0B-CAMERA-AUTH-R06-REVIEW
runtime_or_visual_handoff: none
commit: a7f47a96661c60c7e00a092cc2220bc9e2298c52
```

### `DV-P0B-CAMERA-AUTH-R06-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-R06-REVIEW
status: done
verdict: accept_with_residual

outcome: Evidence is truthful and consistent. Authorization remains failed and
not reached: one route timed out during application activation before status or
requestAccess.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; accepted W05/review and
R05/review; narrow authorization/launch/script source; installed AppKit headers.
reviewed_commit_and_parent: a7f47a96661c60c7e00a092cc2220bc9e2298c52;
c538ed1e84a53fbd5ee9e71fce2c5dad82f5b10c.
changed_paths: none
checks_run: Exact seven-file commit and current equality; structured-data
cross-checks; category/topology provenance; AppKit activation contract;
redaction/media/path/private-data scans; bounded process/root/guard/protected
snapshot.
category_stage: One route start and one activation_timed_out terminal at
activation_requested; authorization, requestAccess, prompt, capture, microphone,
media, provider, and product owners were not reached.
topology_process: One exact marker-owned direct script-sibling exited naturally,
was reaped, passed quiet rescan, and required no signal or retained root.
r05_residual: W05 implementation/review closes supervision design; R06 proves
the real direct-only path and truthfully records only non-reproduction of the
additional process.
cleanup: Sound; zero run-owned residue, protected owners preserved, no external
I/O, no protected content inspected.
scope_check: Evidence-only; no product/source/configuration/TCC/camera/mic/media/
storage/UI/iOS/Build/publication change.
deviations: Exact Debug UI attachment unavailable before terminal; no fallback.
residual: NSApplication activation is not guaranteed. The failure is a platform
activation dependency, not demonstrated signing/TCC causation or a proven new
Debug defect.
next_dependency: Bounded read-only activation/LaunchServices exploration before
any repair or permission retry.
runtime_or_visual_handoff: none
reviewed_commit: a7f47a96661c60c7e00a092cc2220bc9e2298c52
```

### `DV-P0B-CAMERA-AUTH-E06`

```text
packet_id: DV-P0B-CAMERA-AUTH-E06
status: done

outcome: Apple-supported exact-URL NSWorkspace.openApplication with a bounded
run-root helper can launch the same signed Debug app, return typed process
identity, preserve W05 ownership, and gate Camera work on an exact PID/token
acknowledgment.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; accepted W05/R06 evidence;
repository rules; installed AppKit SDK headers and Apple primary documentation.
changed_paths: none
api_findings: Direct Mach-O execution has no LaunchServices foreground request;
regular policy plus NSApplication.activate is non-guaranteed. OpenConfiguration
supports exact app URL, activates, new instance, no substitution/recent item,
sanitized environment, and a returned NSRunningApplication identity.
recommended_route: Compile/ad-hoc-sign a committed run-root helper that never
imports AVFoundation; helper opens the exact Debug app and returns typed
identity; script validates LaunchServices fields plus W05 marker proof; target
cannot inspect status/requestAccess until an atomic PID/token acknowledgment and
active-state confirmation; no second target-side activation request.
minimal_paths: New helper source; permission spike script; Debug Launch,
CameraAuthorization, EventLog; focused authorization/launch tests; W01 summary.
No project, plist, entitlement, HoldTypeApp, normal product, or Release change.
invariants: Same signed Debug HoldType is sole Camera requester; helper has no
Camera capability; exact URL/new instance/no substitution; one deadline;
marker/identity proof before acknowledgment or signal; normal/hardware/Release
unchanged; no broad process action.
checks_run: Read-only source/evidence/SDK/Apple-doc/test-map/diff/worktree review;
no build, test, launch, TCC, Camera, microphone, media, UI, or process action.
scope_check: Activation/LaunchServices evidence only.
deviations: none
residual: LaunchServices activation remains evidence-needed; helper tooling may
be blocked by local compile/sign policy; Camera/TCC remains unproven.
next_dependency: Independent design review, then a bounded writable repair if
accepted.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-E06-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-E06-REVIEW
status: done
verdict: accept_with_residual

outcome: Exact-URL LaunchServices architecture is viable without changing the
signed Camera identity or product/Release behavior, after removing explicit
helper signing, strengthening the PID/token handshake, and expanding paths for
the 500-line structure limit.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; accepted W05/R06 evidence;
repository Swift/tooling; AppKit SDK headers and Apple primary documentation.
changed_paths: none
api_findings: NSWorkspace exact-URL new-instance launch is supported on the
deployment target; substitution is redundant under new-instance mode;
LaunchServices may add environment; returned PID requires returned-object plus
W05 executable/start/inode/marker proof.
helper_decision: One standalone Swift helper under script, compiled into the
run root with no explicit codesign step and no AVFoundation import. It opens
only the exact app URL and publishes a redacted closed result.
handshake: Script alone acknowledges after returned identity and W05 marker
proof. Atomic no-follow mode/owner/type/size-checked PID-digest/token files under
the mode-0700 run root gate target active/status/request work. All boundaries
share one deadline; late/duplicate artifacts are ignored.
lifecycle: Permission-only policy becomes regular in will-finish after strict
preflight; hardware remains prohibited; did-finish waits for acknowledgment and
target isActive; no target-side activate request; product isolation and R03
termination remain.
categories: Add only target acknowledgment invalid/timed-out/cancelled and one
launch_identity_acknowledged stage; helper/script launch failures stay distinct
and redacted; historical evidence is not reinterpreted.
minimal_paths: Standalone helper; spike script; CameraAuthorization; new
Handshake; Launch; new Termination extraction; EventLog; authorization and
event tests; new LaunchServices and Lifecycle tests; W01 summary. All target
Swift remains DEBUG; no project/plist/entitlement/HoldTypeApp change.
checks_run: Read-only source/SDK/Apple-doc/test-map review; no build, runtime,
TCC, Camera, microphone, media, UI, or process action.
scope_check: Debug evidence/tooling only; protected owners unchanged.
deviations: E06 explicit helper signing and literal substitution claim rejected;
path envelope expanded for structure compliance.
residual: LaunchServices foreground behavior, local helper execution, Camera
prompt, and TCC remain runtime evidence. Unexpected Gatekeeper UI must fail.
next_dependency: Corrected 12-path repair, independent review, then one bounded
permission-only runtime.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W06`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06
status: done

outcome: Implemented exact-URL LaunchServices helper launch, marker-bound
identity proof, exclusive atomic acknowledgment, and acknowledgment-gated Camera
authorization lifecycle.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B permission/E08; accepted E06
design review.
changed_paths: Exact 12 authorized helper, script, Debug owner, test, and W01
summary paths; commit 169e895.
reused_owners: W05 multi-process supervision; authorization request bridge;
R03 termination; Debug/Release isolation.
checks_run: Structure; helper compile/injected self-test; 19/19 focused and
63/63 full Phase 0B tests; signed Debug build-only; bounded unsigned Release;
settings/artifact isolation; syntax/help/negatives; hardware-tail hash;
redaction, path, diff, process, and root audits.
behavior_verified: Exact LaunchServices config; no AVFoundation or explicit
helper signing; bounded callback arbitration; token absent from argv/logs;
returned identity plus W05 marker proof; no-follow acknowledgment; ack and
target active before status/request; normal/hardware isolation; termination.
hardware_preservation: Tail byte-identical to b071056 and 48c0d5c.
scope_check: Exact Debug evidence/tooling; no project, plist, entitlement,
product, capture, microphone, media, storage, UI, iOS, Build, or publication.
deviations: W06-specific helper/handshake/lifecycle fakes ran; accepted W05
17-case supervisor matrix was preserved/reused rather than reconstructed as a
new persisted runner.
residual: LaunchServices foreground behavior, Camera prompt, and TCC remain
runtime evidence; no permission or hardware mode invoked.
next_dependency: DV-P0B-CAMERA-AUTH-W06-REVIEW
runtime_or_visual_handoff: none
commit: 169e89562f237484337ab4fed31b12cc0c8040e4
```

### `DV-P0B-CAMERA-AUTH-W06-REVIEW`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06-REVIEW
status: done
verdict: reject

outcome: Helper and Release/product isolation compile and test, but the
permission route aborts before identity proof and required deadline,
result-handoff, cancellation, and behavioral guarantees are not met.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; accepted E06 design, W05
supervision, and R03 lifecycle; repository rules.
reviewed_commit_and_parent: 169e89562f237484337ab4fed31b12cc0c8040e4;
75b75248eddf7965687bf7a026939a341999aade.
changed_paths: none
checks_run: Exact 12-path commit; structure/diff; helper self-test; 19/19
focused and 63/63 full tests; syntax/help/negatives/build-only; signed Debug;
bounded Release/isolation; hardware-tail hash; process/root cleanup.
findings: Script stores category/process_digest but reads unset
launch_category/returned_process_digest under set -u; helper compilation is
outside the claimed 420-second deadline; helper result publication plus
multi-pass path-based plutil parsing lacks descriptor-stable strict schema and
immutability; cancellation is checked after isActive/authorizationStatus;
tests do not traverse real result parsing and summary overclaims these points.
closed: Exact URL/config/imports/no explicit signing; target acknowledgment
reader; categories/stages/termination extraction; normal/hardware/Release
isolation; hardware tail.
scope_check: Exact Debug evidence/tooling; protected owners unchanged; no
runtime/TCC/camera/microphone/media action.
deviations: Accepted W05 matrix not rerun because real route aborts first.
residual: LaunchServices foreground, Camera prompt/TCC, and hardware remain
unproven.
next_dependency: Seven-path parser/deadline/result/cancellation/test/summary
repair and independent review.
runtime_or_visual_handoff: none
reviewed_commit: 169e89562f237484337ab4fed31b12cc0c8040e4
```

### `DV-P0B-CAMERA-AUTH-W06-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06-R1
status: done

outcome: Repaired strict helper-result parsing, descriptor-stable publication
and verification, single 420-second deadline coverage, cancellation ordering,
and behavioral evidence.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; exact W06 rejection.
changed_paths: CameraAuthorization; LaunchServices and authorization tests;
standalone helper; permission script; W01 summary. Six paths in commit daac571;
the authorized lifecycle-test path required no change.
checks_run: Structure; 20/20 focused, 66/66 full Phase 0B, and 7/7 final
LaunchServices tests; actual valid/extra-key/wrong-digest parser fakes; helper
self-test; syntax/help/negatives/build-only; signed Debug; bounded unsigned
Release; settings/artifact isolation; hardware tail and W05 function hashes;
diff/redaction/path/process/root audits.
findings_closed: Normalized initialized parser fields; one deadline begins
before compile; directory-relative exact-schema immutable descriptor snapshot;
cancellation before active/status/request; executable verifier/parser/digest/
ack tests; truthful summary wording.
scope_check: Exact Debug evidence/tooling repair; no product, project, plist,
entitlement, TCC, runtime, camera, microphone, media, storage, UI, iOS, Build,
or publication change.
deviations: Accepted W05 supervisor functions were proven hash-identical rather
than reconstructing the prior ad-hoc multi-process runner.
residual: LaunchServices foreground behavior, Camera prompt/TCC, and hardware
remain runtime evidence.
next_dependency: DV-P0B-CAMERA-AUTH-W06-REVIEW-R1
runtime_or_visual_handoff: none
commit: daac5718750492f069b04369b98ca7852e2f389e
```

### `DV-P0B-CAMERA-AUTH-W06-REVIEW-R1`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06-REVIEW-R1
status: done
verdict: reject

outcome: R1 closes parser, descriptor-stable result, and cancellation defects,
but permission EXIT cleanup is outside the deadline and the parser test hook
changes protected build-only/hardware behavior.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; exact W06 reject and R1.
reviewed_commit_and_parent: daac5718750492f069b04369b98ca7852e2f389e;
368cd3a8e4465c4c8a7ad5a94fdad7a46fdede53.
changed_paths: none
checks_run: Exact six-path repair; actual parser valid/extra-key/wrong-digest;
helper invalid/immutability matrix; 20/20 focused and 66/66 full Phase 0B;
syntax/help/negatives/build-only; Debug/Release isolation; hardware/function
hashes; process/root/worktree audit.
closed: Initialized production parser; one immutable O_NOFOLLOW strict-schema
snapshot; cancellation before active/status/request; genuine production parser
tests; helper/process/Release/hardware preservation.
findings: EXIT trap uses raw untimed rm operations outside the deadline and does
not verify deletion before uncertainty retention. SCRIPT_RESULT_TEST is checked
before mode isolation and changes build-only/hardware behavior; negative test is
missing. Summary overclaims cleanup and isolation.
scope_check: Exact Debug evidence/tooling; protected product/configuration/TCC/
camera/microphone/media/storage/UI/iOS/Build/publication unchanged.
deviations: W05 matrix not reconstructed because ownership functions remain
byte-identical.
residual: LaunchServices foreground, Camera prompt/TCC, and hardware unproven.
next_dependency: Three-path bounded cleanup and hook-isolation repair, then
repeat review.
runtime_or_visual_handoff: none
reviewed_commit: daac5718750492f069b04369b98ca7852e2f389e
```

### `DV-P0B-CAMERA-AUTH-W06-R2`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06-R2
status: done

outcome: Permission work now leaves an exact 11-second cleanup tail inside the
original 420-second deadline; bounded verified scrub/root cleanup fails with 70
on uncertainty. Parser test hook is permission-only.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; exact R1 rejection.
changed_paths: Permission script, LaunchServices tests, W01 summary; commit
10804b6.
checks_run: Syntax/structure; actual parser fakes; cleanup fake matrix; hook
mode parity including real build-only; 9 focused LaunchServices and 68 full
Phase 0B tests; signed Debug build-only; settings isolation; hardware/W05
hashes; diff/redaction/path/process/root audits.
cleanup_deadline: Work cutoff reserves 6s process cleanup, 1s root verify, 1s
sensitive scrub, 1s reverify, and 2s exact-root delete inside the global
deadline. Uncertainty scrubs sensitive artifacts before retaining a verified
private root; any unproven result returns 70.
hook_isolation: SCRIPT_RESULT_TEST is reached only for explicit permission
mode; help/default/errors/missing-camera hardware and build-only match ordinary
dispatch.
scope_check: Exact three-path Debug tooling/test/evidence repair; no app/helper/
project/configuration/runtime/TCC/camera/microphone/media/storage/UI/iOS/Build/
publication change.
deviations: none
residual: Real same-identity permission/TCC execution remains runtime evidence.
next_dependency: DV-P0B-CAMERA-AUTH-W06-REVIEW-R2
runtime_or_visual_handoff: none
commit: 10804b6f70d04ca1cc805c70355a4954f5229da9
```

### `DV-P0B-CAMERA-AUTH-W06-REVIEW-R2`

```text
packet_id: DV-P0B-CAMERA-AUTH-W06-REVIEW-R2
status: done
verdict: reject

outcome: Hook isolation is repaired and nominal reserve arithmetic is coherent,
but permission cleanup remains neither hard-bounded nor exact-target safe.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B E08; exact R1 reject and R2.
reviewed_commit_and_parent: 10804b6f70d04ca1cc805c70355a4954f5229da9;
62017bdf92f1c73690908df3ae59d5c5336bca7b.
changed_paths: none
checks_run: Exact three paths; structure/syntax; 9/9 focused and 68/68 full
tests; Debug/Release isolation; hardware hash; controlled TERM-ignoring timeout;
process/root/worktree audit.
closed: SCRIPT_RESULT_TEST permission-only isolation and ordinary behavior for
help/default/errors/missing-camera/build-only; nominal 11-second reserve and
status precedence otherwise coherent.
findings: GNU timeout lacks kill-after, so TERM-ignoring cleanup can outlive the
deadline. Run-root verification follows path owner/mode/type without original
device/inode pin or no-follow ancestry and leaves a replacement/check-use race.
Adversarial timeout/root-replacement fakes and summary truth are missing.
scope_check: Exact Debug tooling/test/evidence; protected app/configuration/TCC/
camera/microphone/media/storage/UI/product domains unchanged.
deviations: No permission or hardware mode invoked.
residual: LaunchServices foreground, Camera prompt/TCC, and hardware unproven.
next_dependency: Three-path hard timeout escalation and pinned no-follow root
identity repair, then independent review.
runtime_or_visual_handoff: none
reviewed_commit: 10804b6f70d04ca1cc805c70355a4954f5229da9
```

## Rejected Receipts

### `DV-P0B-CAMERA-AUTH-W04-REVIEW` of `b2a2abf`

```text
packet_id: DV-P0B-CAMERA-AUTH-W04-REVIEW
status: done
verdict: reject

outcome: Activation, deferred termination, and direct-PID supervision pass,
but permission supervision does not enforce its claimed total 420-second bound.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B; E04; exact W04 commit.
reviewed_commit_and_parent: b2a2abfe6e466d32b9b43b6bb43f629a03966101;
088ce2ddcf59f3a894aa46f3a1d8d832ea90c770.
paths: Six authorized W04 paths.
checks: Exact scope; structure; 59 tests; script help/negatives and independent
natural/stuck/mismatch/trap fakes; Debug build-only; Release/isolation;
redaction/owner/process/root.
findings: Terminal reserve counts 11 seconds, but natural wait, two four-probe
identity reads, TERM/KILL waits, and reap can take up to 27 seconds; identity
capture itself is not bounded by the deadline. No enclosing 420-second bound.
Activation, termination ordering, identity-safe signaling, no broad kill,
hardware preservation, and Release isolation are closed.
scope_check: Exact Debug/test/script/evidence scope; no runtime/TCC/product.
deviations: Reviewer fake canonicalized /tmp to /private/tmp and reran green.
residual: Permission runtime remains blocked.
next_dependency: Script/summary repair with one absolute deadline and slow-
identity behavioral fake; repeat review.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W03-REVIEW` of `1ae703f`

```text
packet_id: DV-P0B-CAMERA-AUTH-W03-REVIEW
status: done
verdict: reject

outcome: Diagnostic categories, monotonic frozen stages, exact-one request,
termination, Debug isolation, and Release isolation pass, but one activation-
rejection route regresses W02 and can emit a false category.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted AUTH
W01/W02/R03 reviews; exact W03 commit.
reviewed_commit_and_parent: 1ae703fa0a4ced0cea0b73ef8ffeee85adb2ac13;
d7ff6861a9c3e8cc4924460420550e4b361ed7ca.
paths: Exactly five authorized paths.
checks: Exact diff/path/blob; structure; 14/14 auth and 59/59 full tests; signed
Debug build-only; bounded Release/isolation; redaction/owner/process/root.
findings: Live requestActivation calls NSApplication.shared.activate even when
NSRunningApplication.current.activate returned false, then reports rejection
without proving active state. Injected Boolean tests miss the second-call
behavior. Other categories/stages and protected routes are closed.
scope: Exact Debug/test/evidence scope; no protected or Release change.
deviations: none material
residual: Permission/capture runtime remains blocked.
next_dependency: Original owner guards the second activation behind first-call
success, adds behavioral platform-call coverage, and repeats review.
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-W02-REVIEW` — incorrect artifact authority

```text
packet_id: DV-P0B-CAMERA-AUTH-W02-REVIEW
status: blocked
verdict: reject

outcome: Requested full SHA f35ac7f0c269f538ac230c966a519994524498d1
does not exist, so review stopped before source inspection.
authority_used: Exact-artifact stop condition.
reviewed_commit_and_parent: none; Git resolves prefix f35ac7f to
f35ac7f3659f660e14d596ff0e2e6eb6fa1695be, parent
f8e0cc00e6e90294d477a1a4e63fbae9cdd3f2ef.
changed_paths_reviewed: none
checks_run: rev-parse, cat-file, and bounded hash reconciliation.
scope_check: No file, runtime, hardware, TCC, or UI action.
deviations: none
residual: Full review pending corrected exact authority.
next_dependency: DV-P0B-CAMERA-AUTH-W02-REVIEW-R1
runtime_or_visual_handoff: none
```

### `DV-P0B-CAMERA-AUTH-R01-REVIEW` of `4f0efb5`

```text
packet_id: DV-P0B-CAMERA-AUTH-R01-REVIEW
status: done
verdict: reject
authorization_cell: fail — camera_authorization_timed_out

outcome: Runtime evidence supports one genuine same-signed request and one
terminal timeout, but summary.md contradicts its unknown final authorization
state by claiming TCC was otherwise unmodified and its database unchanged.
authority_used: DV-DRAFT-4@2f3266a; Phase 0B protocol and plan; accepted R05
and authorization W01 evidence; exact AUTH-R01 commit.
reviewed_commit_and_parent: 4f0efb557ab4502b16bac8881e731319c6ff16ad;
00c7d5222dd9d63111cb3cdc65d2a512e9f934d4.
changed_paths_reviewed: Exactly seven redacted evidence files; no reviewer
changes.
checks_run: Exact diff/path/blob; structured data and semantic counts;
category provenance; redaction/media/path scans; process, guard, root, and
protected-path snapshot.
classification_review: One request and terminal timeout with zero retries,
capture, mic, media, or product owners is supported. Prompt, final TCC state,
and quantitative results remain unknown. No Debug defect is implicated.
cleanup_review: Sound; zero run-owned residue and pre-existing HoldType
preserved.
scope_check: Exact evidence scope; rejection is claim truthfulness only.
deviations: Watcher glob miss and Computer Use timeout are disclosed and do
not invalidate operator-terminal provenance.
residual: Final Camera authorization/TCC state remains unknown.
next_dependency: Original evidence owner repairs only capture-auth-R01
summary.md to say no reset/direct database operation occurred while system-
managed state after requestAccess remains unknown; then repeat review.
runtime_or_visual_handoff: none
```

### `DV-P0B-STORAGE-W02-REVIEW` of `e6b3a13`

```text
packet_id: DV-P0B-STORAGE-W02-REVIEW
status: done
verdict: reject

outcome: Exact scope, internal mechanics, focused tests, and residue checks
pass, but the external runtime seam is not independently fail-closed or fully
bounded. External runtime remains forbidden before repair and repeat review.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E06/E08;
accepted W01/E02 evidence; W02 packet and receipt.
changed_paths: none
checks_run: Exact commit/parent/three-path/mode/blob audit; diff and structure;
24 focused cells; Debug build; wrapper syntax/help and nine negatives; collision,
64 KiB, redirected-prefix, protected-owner, redaction, process, and residue
audits. No external I/O.
scope_check: Commit scope otherwise clean; no product, project, entitlement,
settings, protected storage, media, UI, hardware, dependency, or quality change.
deviations: none
residual: Direct environment-backed XCTest can bypass wrapper-only broad-root
and SSD/HDD checks because suite validation accepts `/` syntactically and
discards destinationClass. External diskutil/df probes, caffeinate wait, and
captured-descendant exit verification are not fully bounded.
next_dependency: Original owner repairs the same three paths and repeats review;
no external runtime first.
runtime_or_visual_handoff: none
reviewed_commit: e6b3a13f046a6e0ac703643c87ee869e222ead6f
```

### `DV-P0B-STORAGE-W02-REVIEW-R1` of `986af6c`

```text
packet_id: DV-P0B-STORAGE-W02-REVIEW-R1
status: done
verdict: reject

outcome: Repair improves physical-media validation and ordinary cleanup, but
broad-root and complete bounded-cleanup requirements remain incomplete.
External runtime remains forbidden.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E06/E08;
accepted W01/E02 evidence; W02 reject and repair.
changed_paths: none
checks_run: Exact three-path repair audit; diff and structure; 25 focused
cells; bounded Debug build/test; wrapper syntax/help and nine negatives;
process fixtures; SDK key verification; redaction, protected-owner, residue,
and process audits. No external I/O.
scope_check: Clean test/tooling-only repair; no protected or quality change.
deviations: none
residual: `group_members` masks timeout/error as empty, allowing a later
unbounded wait; external shell metadata builtins remain outside a finite
boundary; broad/home-root rejection and nonlocal, nonwritable/read-only,
nil-filesystem negative coverage remain incomplete. Actual external evidence
and prior runtime residuals remain.
next_dependency: Original owner repairs the same three paths and repeats review;
no external runtime first.
runtime_or_visual_handoff: none
reviewed_commit: 986af6ca85147c8236075b30d5fef200f73dec74
```

### `DV-P0B-STORAGE-W02-REVIEW-R2` of `767edd9`

```text
packet_id: DV-P0B-STORAGE-W02-REVIEW-R2
status: done
verdict: reject

outcome: Probe statuses, bounded preflight, broad-root rejection, and injected
authority coverage pass, but process-group cleanup can accept incomplete member
identity evidence and then signal the whole group.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E06/E08;
accepted W01/E02 evidence and prior W02 reviews.
changed_paths: none
checks_run: Exact three-path repair audit; diff and structure; 25 focused
invocations; bounded Debug build; eight wrapper negatives; group-status,
metadata-timeout, process, caffeinate, reap, redaction, protected-owner,
residue, and process audits. No external I/O.
scope_check: Clean test/tooling-only repair; no protected or quality change.
deviations: none
residual: `capture_group_identities` skips a member whose identity probe fails;
the incomplete captured set is not matched and revalidated against the observed
set immediately before group signaling. Actual external/runtime residuals
remain.
next_dependency: Original owner repairs only the wrapper, adds a deterministic
partial-identity fixture, and repeats review; no external runtime first.
runtime_or_visual_handoff: none
reviewed_commit: 767edd9eb717f2a5324a79a3aa37dc3086657427
```

### `DV-P0B-STORAGE-W02-REVIEW-R3` of `d0c9ce5`

```text
packet_id: DV-P0B-STORAGE-W02-REVIEW-R3
status: done
verdict: reject

outcome: Supervisor-group identity capture and signaling are closed, but the
caffeinate escalation path can KILL a recycled or unrelated PID and report
cleanup success.
authority_used: DV-DRAFT-3@ed108fa storage clauses; Phase 0B E03/E04/E08;
accepted W01/E02 evidence and prior W02 reviews.
changed_paths: none
checks_run: Exact wrapper-only repair audit; syntax/help; nine negatives;
atomic identity, member-set, probe status, EXIT-trap, lifecycle, caffeinate,
reap, structural, redaction, protected-owner, path, residue, and process
checks. No external I/O.
scope_check: Clean wrapper-only repair; no Swift, protected, or quality change.
deviations: none
residual: `stop_caffeinate` validates identity before TERM but not freshly
before KILL. Deterministic direct and EXIT-trap PID-recycle fixtures reproduce
TERM then KILL to the changed identity. Actual external/runtime residuals
remain.
next_dependency: Original owner repairs only the wrapper and repeats review;
no external runtime first.
runtime_or_visual_handoff: none
reviewed_commit: d0c9ce529f8b43234575ce9db2e51a0b007bb484
```

### `DV-P0B-CAPTURE-W01-REVIEW` of `9d9efec`

```text
packet_id: DV-P0B-CAPTURE-W01-REVIEW
status: done
verdict: reject

outcome: The Debug harness builds and passes focused fake tests, but mandatory
startup-isolation, terminal-cleanup, and bounded-operation safeguards fail.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; original W01 packet;
exact commit and protected adjacent contracts.
changed_paths: none
checks_run: Exact 15-path diff; structure; 13 fake tests; Debug and Release
builds; build-setting and built-artifact isolation; script checks; final audit.
scope_check: Path scope and Release isolation pass; no hardware/TCC/UI/provider
runtime occurred.
deviations: none
residual: Product scenes still compose under the harness gate; steady-state
camera failures may not terminate and clean up; quit does not await cleanup;
the export timeout and one hardware-script build-settings probe are not fully
bounded. All real hardware/media evidence and the shipping lease remain open.
next_dependency: Original capture owner repairs the exact findings, then a new
independent review runs before storage or hardware runtime.
runtime_or_visual_handoff: none
reviewed_commit: 9d9efecc36e6337790a2f80e2571d3118e4bc404
```

### `DV-P0B-STORAGE-W01-REVIEW` of `2486b56`

```text
packet_id: DV-P0B-STORAGE-W01-REVIEW
status: done
verdict: reject

outcome: Path scope, build, 18 focused tests, promotion collision, redaction,
and residue checks pass, but cleanup symlink-prefix safety fails.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B protocol; exact W01 packet and
commit; protected storage contracts.
changed_paths: none
checks_run: Exact three-path diff; structure; focused suite; bounded Debug
build; zero-residue and process audit.
scope_check: Clean; no product, external-volume, media, or hardware runtime.
deviations: none
residual: Cleanup validates the run-root leaf but not the required temp-prefix
component immediately before recursive delete, allowing a parent-symlink
substitution risk. The summary also overstates stale-bookmark evidence: rename
following passed, but a stale result was not deterministically established.
next_dependency: Original storage owner repairs the same three paths, adds a
redirected-prefix survival test, corrects the claim, then repeats review.
runtime_or_visual_handoff: none
reviewed_commit: 2486b56c02130abd905824a0b50da95118a4b81c
```

### `DV-P0B-CAPTURE-R03-REVIEW` of `8b0b263`

```text
packet_id: DV-P0B-CAPTURE-R03-REVIEW
status: done
verdict: reject

outcome: Termination self-dependency and script supervision are closed, but
raw platform camera-start classification remains false or collapsed.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted R02 evidence/review;
R03 commit and Apple SDK AVError authority.
changed_paths: none
checks_run: Exact eight-path diff; 14-case category and raw-error review; SDK
codes; termination/script probes; 26 tests; Debug/Release isolation.
scope_check: Clean; no hardware, TCC, product, storage, or protected-owner run.
deviations: none
residual: Authorization AVError codes collapse to recording failure; pre-start
disconnect is labeled during-capture; numeric codes lack AVFoundation domain
checking; tests do not cover raw classifier/domain/context.
next_dependency: Original R03 owner repairs camera classifier/tests/summary,
then repeat review before hardware or storage dispatch.
runtime_or_visual_handoff: none
reviewed_commit: 8b0b2635832c5f5b52f3191c96a2828d90680498
```

### `DV-P0B-CAPTURE-R03-REVIEW-R1` of `1276283`

```text
packet_id: DV-P0B-CAPTURE-R03-REVIEW-R1
status: done
verdict: reject

outcome: Raw AVFoundation domain/code mapping is repaired, but actual lifecycle
routes can discard or replace the typed category before terminal evidence.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; R02 evidence/review; R03 reject;
Apple SDK AVError authority.
changed_paths: none
checks_run: Exact four-path diff; SDK mapping; observer/catch/movie/terminal
route trace; 29 tests; Debug/Release isolation; accepted blob comparison.
scope_check: Clean; accepted Launch/script behavior unchanged; no hardware run.
deviations: none
residual: Notifications before start continuation may be dropped; disconnect
before first frame and steady interruption can be replaced by generic
capture_stop; behavioral tests do not exercise these routes.
next_dependency: Original owner repairs actual propagation and behavioral tests,
then repeats review before hardware or storage dispatch.
runtime_or_visual_handoff: none
reviewed_commit: 127628385a561c13acf4879602ecd749c965cee3
```

### `DV-P0B-CAPTURE-R03-REVIEW-R2` of `ba058f8`

```text
packet_id: DV-P0B-CAPTURE-R03-REVIEW-R2
status: done
verdict: reject

outcome: Early observer retention and movie-start plus first-frame gate are
closed, but concrete explicit stop mutates state before context classification
and replaces steady disconnect with a start-time category.
authority_used: DV-DRAFT-3@ed108fa; Phase 0B; accepted R02/R03 evidence;
exact propagation repair.
changed_paths: none
checks_run: Exact five-path diff; route trace; 23 focused and 34 full tests;
structure; Debug/Release isolation; accepted script/lifecycle comparison.
scope_check: Clean; no hardware, TCC, storage, product, or protected-owner run.
deviations: none
residual: Explicit stop must preserve steady context or the already-typed error
before terminal state mutation; current tests bypass the concrete stop route and
the summary overclaims later-stop preservation.
next_dependency: Original owner repairs CameraCapture, its concrete stop test,
and the summary, then repeats review.
runtime_or_visual_handoff: none
reviewed_commit: ba058f8742dc409b91612f95e5254db6fac8b6e0
```
