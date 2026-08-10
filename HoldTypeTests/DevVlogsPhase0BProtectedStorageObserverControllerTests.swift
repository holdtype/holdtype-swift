#if DEBUG
import Foundation
import Testing
struct DevVlogsPhase0BProtectedStorageObserverControllerTests {
    @Test func helpDefaultAndInvalidModesCannotCreatePrivateRoots() throws {
        let before = try privateObserverRoots()
        let help = try run([scriptPath, "--help"])
        #expect(help.status == 0)
        #expect(help.output.contains("--execute"))
        let normal = try run([scriptPath])
        #expect(normal.status == 64)
        let invalid = try run([scriptPath, "--unknown"])
        #expect(invalid.status == 64)
        var innerEnvironment = ProcessInfo.processInfo.environment
        innerEnvironment["HOLDTYPE_DEV_VLOGS_PROTECTED_STORAGE_OBSERVER_INNER"] = "1"
        let inner = try run([scriptPath, "--controller-inner"], environment: innerEnvironment)
        #expect(inner.status == 64)
        #expect(try privateObserverRoots() == before)
        for output in [help.output, normal.output, invalid.output, inner.output] {
            #expect(!output.contains("/private/tmp/holdtype-dev-vlogs-observer."))
        }
    }
    @Test func classifierRowsAreSingleAndFirstApplicable() throws {
        let rows: [([String], String)] = [
            (["conflict", "continuous", "passed", "unchanged", "passed",
              "unchanged", "valid", "none", "absent", "none", "certain", "clear"],
             "environment_conflict"),
            (["clear", "broken", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"],
             "guard_discontinuity"),
            (["clear", "continuous", "failed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"], "build_failed"),
            (["clear", "continuous", "passed", "uncertain", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"], "metadata_uncertain"),
            (["clear", "continuous", "passed", "changed", "passed", "unchanged",
              "valid", "none", "absent", "none", "certain", "clear"],
             "build_window_change_correlated"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "valid", "all_succeeded", "observed", "outside_only", "certain", "clear"],
             "run_owned_canonical_recovery_write_correlated"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "valid", "all_succeeded", "observed", "outside_only", "certain", "uncertain"],
             "still_unknown"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "invalid", "none", "absent", "none", "certain", "uncertain"],
             "environment_conflict"),
            (["clear", "continuous", "passed", "unchanged", "passed", "changed",
              "invalid", "none", "absent", "mixed", "certain", "clear"], "still_unknown"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "invalid", "none", "absent", "none", "certain", "clear"], "observer_invalid"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "all_succeeded", "observed", "outside_or_indeterminate",
              "certain", "clear"], "evidence_conflict"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "failed", "observed", "private_only", "certain", "clear"],
             "hosted_test_failed"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "observed", "none", "certain", "clear"],
             "owner_exposed_no_mutation"),
            (["clear", "continuous", "passed", "unchanged", "passed", "unchanged",
              "valid", "none", "absent", "none", "uncertain", "clear"], "cleanup_uncertain"),
            (["clear", "continuous", "passed", "missing_unchanged", "passed",
              "missing_unchanged", "valid", "none", "absent", "none", "certain", "clear"],
             "pass_unchanged"),
        ]
        for (arguments, expected) in rows {
            let quoted = arguments.map(shellQuote).joined(separator: " ")
            let result = try run(["/bin/zsh", "-c",
                "source \(shellQuote(scriptPath)); classify_observer_result \(quoted)"])
            #expect(result.status == 0)
            #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == expected)
            #expect(result.output.split(separator: "\n").count == 1)
        }
    }
    @Test func productionParserBindsRunAndFeedsExactFactsToClassification() throws {
        let owner = observerLine(2, "owner_initialized", "none", "recovery_directory",
                                 "private_task_home", "observed")
        let outside = [
            observerLine(2, "owner_initialized", "none", "recovery_directory",
                         "private_task_home", "observed"),
            observerLine(3, "mutation_begin", "replace_recovery_index", "recovery_index",
                         "outside_private_task_home", "attempted"),
            observerLine(4, "mutation_end", "replace_recovery_index", "recovery_index",
                         "outside_private_task_home", "succeeded"),
        ]
        #expect(try parseStream([readyLine, owner]).output == "valid none observed none\n")
        #expect(try parseStream([readyLine] + outside).output
                == "valid all_succeeded observed outside_only\n")
        #expect(try classifyStream([readyLine] + outside, concurrent: "clear").output
                == "run_owned_canonical_recovery_write_correlated\n")
        #expect(try classifyStream([readyLine] + outside, concurrent: "uncertain").output
                == "still_unknown\n")
        var wrongRun = outside
        wrongRun[1] = observerLine(3, "mutation_begin", "replace_recovery_index",
            "recovery_index", "outside_private_task_home", "attempted", runID: otherRunID)
        let invalid: [[String]] = [
            [readyLine] + wrongRun,
            [readyLine, owner, observerLine(3, "mutation_end", "replace_recovery_index",
                "recovery_index", "private_task_home", "succeeded")],
            [readyLine, owner, observerLine(3, "mutation_begin", "replace_recovery_index",
                "recovery_audio", "private_task_home", "attempted")],
            [readyLine, owner.replacingOccurrences(of: "\"sequence\":2",
                with: "\"sequence\":2,\"sequence\":2")],
            [readyLine, observerLine(3, "owner_initialized", "none", "recovery_directory",
                "private_task_home", "observed")],
            [readyLine.replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":true")],
            [readyLine.replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":1.0")],
            [readyLine.replacingOccurrences(of: "\"sequence\":1", with: "\"sequence\":false")],
            [readyLine.replacingOccurrences(of: "\"sequence\":1", with: "\"sequence\":1.0")],
        ]
        for lines in invalid { #expect(try parseStream(lines).status != 0) }
    }
    @Test func absoluteInnerAndOuterBoundsStopTermIgnoringCommands() throws {
        let timeout = try timeoutExecutable()
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            timeout_executable=\(shellQuote(timeout))
            deadline=$(( SECONDS + 2 )); cleanup_reserve_seconds=0
            set +e
            run_timed_command 30 0 1 /bin/zsh -c 'trap "" TERM; while true; do :; done'
            inner_status=$?
            marker=$(/usr/bin/mktemp /private/tmp/holdtype-observer-expired.XXXXXXXX)
            /bin/unlink "$marker"; deadline=$SECONDS
            run_timed_command 30 0 1 /usr/bin/touch "$marker"; expired_status=$?
            outer_timeout_seconds=1; outer_kill_after_seconds=1
            outer_supervise /bin/zsh -c 'trap "" TERM; while true; do :; done'
            outer_status=$?
            set -e
            [[ $inner_status != 0 && $expired_status == 124 && ! -e "$marker" &&
               $outer_status != 0 ]] && print bounds=pass
            """])
        #expect(result.status == 0)
        #expect(result.output == "bounds=pass\n")
    }
    @Test func privateArtifactReplacementAndDiagnosticsFailClosed() throws {
        let timeout = try timeoutExecutable()
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath)); timeout_executable=\(shellQuote(timeout))
            deadline=$(( SECONDS + 60 )); cleanup_reserve_seconds=0
            validate_guard() { return 0 }
            setup() {
                run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-pins.XXXXXXXX)
                /bin/chmod 700 "$run_root"; task_home="$run_root/home"
                derived_data="$task_home/DerivedData"; temporary_root="$task_home/tmp"
                bin_root="$run_root/bin"; logs_root="$run_root/logs"; probe="$bin_root/probe"
                /bin/mkdir -m 700 "$task_home" "$derived_data" "$temporary_root" \
                    "$bin_root" "$logs_root" "$run_root/sibling"
                print fixture >"$probe"; /bin/chmod 700 "$probe"
                run_root_identity=$(identity "$run_root" 700)
                task_home_identity=$(identity "$task_home" 700)
                derived_data_identity=$(identity "$derived_data" 700)
                temporary_root_identity=$(identity "$temporary_root" 700)
                bin_root_identity=$(identity "$bin_root" 700)
                logs_root_identity=$(identity "$logs_root" 700)
                probe_identity=$(regular_file_identity "$probe" 700)
            }
            for name in temporary_root logs_root bin_root probe; do
                setup; target=${(P)name}; /bin/mv "$target" "${target}.original"
                if [[ "$name" == probe ]]; then print replacement >"$target"
                else /bin/mkdir -m 700 "$target"; fi
                /bin/chmod 700 "$target"
                set +e; validate_roots; validation_status=$?; set -e
                [[ $validation_status == 70 && -e "${target}.original" && -e "$target" &&
                   -d "$run_root/sibling" ]] || exit 71
                /bin/rm -rf -- "$run_root"
            done
            setup; bounded_status=0
            run_bounded_to_log 5 "$logs_root/private.log" /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; /bin/sleep 0.2; exit 8' \
                >"$run_root/bounded.output" 2>&1 || bounded_status=$?
            cleanup_command_status=0
            run_cleanup_command /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 9' \
                >"$run_root/cleanup.output" 2>&1 || cleanup_command_status=$?
            [[ $bounded_status == 8 && ! -s "$run_root/bounded.output" &&
               $cleanup_command_status == 9 && ! -s "$run_root/cleanup.output" ]] || exit 72
            /bin/rm -rf -- "$run_root"
            deadline=$(( SECONDS + 10 )); set +e
            output=$(run_metadata_probe /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 7' 2>&1); command_status=$?
            outer_timeout_seconds=5; outer_kill_after_seconds=1; set +e
            outer_output=$(outer_supervise /bin/zsh -c \
                'print -u2 /private/tmp/private-sentinel; exit 9' 2>&1); outer_status=$?
            set -e
            [[ $command_status == 7 && -z "$output" && $outer_status == 9 &&
               -z "$outer_output" ]] && print pins_and_redaction=pass
            """])
        #expect(result.status == 0); #expect(result.output == "pins_and_redaction=pass\n")
    }
    @Test func summaryTruthfullyDisclosesTheRejectedLiveHomeDiagnostic() throws {
        let summary = try String(contentsOfFile: summaryPath, encoding: .utf8); let normalized = summary.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(normalized.contains("exposed the live user Home or default Xcode result-metadata location") && normalized.contains("No protected content was inspected by the worker or reviewer") && normalized.contains("host metadata access was not proven absent"))
        #expect(normalized.contains("ephemeral task-owned `/tmp` token") && normalized.contains("No protected or user path entered durable evidence") && normalized.contains("wrong task-owned private-root prefix") && normalized.contains("canonical private-root rerun passed"))
        #expect(!summary.contains("inert route failed closed"))
    }
    @Test func terminalEvidenceCleanupAndFailureOverridesAreBehavioral() throws {
        let ready = shellQuote(readyLine + "\n"), timeout = try timeoutExecutable()
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath)); timeout_executable=\(shellQuote(timeout)); run_metadata_probe() { "$@" }
            deadline=$(( SECONDS + 60 )); fixture=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-terminal.XXXXXXXX)
            /bin/chmod 700 "$fixture"; stop_supervisor() { trace+=s }; cleanup_run_root() { trace+=r }; stop_guard() { trace+=g }
            assert_failure_safe() { local file content; for file in "$1"/**/*(.N); do content=$(/bin/cat "$file"); [[ "$content" != *'cleanup: complete'* && "$content" != *'"cleanup":"complete"'* && "$content" != *,complete* && "$content" != *pass_unchanged* && "$content" != *run_owned_canonical_recovery_write_correlated* && "$content" != *build_window_change_correlated* && "$content" != *owner_exposed_no_mutation* ]] || return 1; done }
            assert_complete_success() { local saved_class="$terminal_class" saved_phase="$terminal_phase" result=0; terminal_class=pass_unchanged; terminal_phase=hosted; validate_runtime_evidence "$1" || result=$?; terminal_class="$saved_class"; terminal_phase="$saved_phase"; return $result }
            for item in environment_conflict:baseline:uncertain:not_run:70 guard_discontinuity:guard:uncertain:not_run:70 build_failed:build:uncertain:not_run:70 \
                build_window_change_correlated:build:changed:not_run:70 run_owned_canonical_recovery_write_correlated:hosted:unchanged:changed:70 still_unknown:hosted:unchanged:changed:70 \
                evidence_conflict:hosted:unchanged:unchanged:70 observer_invalid:hosted:unchanged:unchanged:70 metadata_uncertain:build:uncertain:not_run:70 \
                hosted_test_failed:hosted:unchanged:unchanged:70 pass_unchanged:hosted:unchanged:unchanged:0 owner_exposed_no_mutation:hosted:unchanged:unchanged:0; do
                values=(${(s/:/)item}); terminal_class=$values[1]; terminal_phase=$values[2]; build_comparison=$values[3]; hosted_comparison=$values[4]
                terminal_exit_status=$values[5]; terminal_finalized=false; terminal_finalizing=false; cleanup_state=incomplete_retained; evidence_write_state=not_attempted; trace=""; retained_observer_events=""; run_id=""
                evidence="$fixture/$terminal_class"; final_status=0; finalize_controller "$evidence" || final_status=$?
                [[ $final_status == $terminal_exit_status && "$trace" == srg && $(/usr/bin/find "$evidence" -type f | /usr/bin/wc -l) -eq 8 ]] || exit 71
                /usr/bin/grep -q "terminal_class: $terminal_class" "$evidence/summary.md" && /usr/bin/grep -q "cleanup: complete" "$evidence/summary.md" || exit 72
            done
            run_id=\(shellQuote(runID)); expected_run="$run_id"; retained_observer_events=\(ready)
            terminal_class=pass_unchanged; terminal_phase=hosted; terminal_exit_status=0
            terminal_finalized=false; terminal_finalizing=false; valid="$fixture/valid"; finalize_controller "$valid"
            validate_observer_stream "$valid/events/storage-observer-r01.jsonl" "$expected_run" >/dev/null || exit 74
            cleanup_run_root() { trace+=r; return 70 }; trace=""; retained_observer_events=""; terminal_finalized=false; terminal_finalizing=false
            cleanup_evidence="$fixture/cleanup-override"; cleanup_status=0
            finalize_controller "$cleanup_evidence" || cleanup_status=$?
            [[ $cleanup_status == 70 && "$trace" == srg && "$terminal_class" == cleanup_uncertain &&
               $(/usr/bin/grep -c 'cleanup: incomplete_retained' "$cleanup_evidence/summary.md") == 1 ]] || exit 75; cleanup_run_root() { trace+=r }
            sentinel='PRIVATE_PATH_SENTINEL_SECRET'; malformed="$fixture/malformed.log"; print -r -- "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 $sentinel" >"$malformed"
            retained_observer_events=$(validate_observer_stream "$malformed" "$expected_run" events 2>/dev/null) || retained_observer_events=""
            terminal_class=observer_invalid; terminal_exit_status=70; terminal_finalized=false; terminal_finalizing=false
            malformed_evidence="$fixture/malformed"; malformed_status=0
            finalize_controller "$malformed_evidence" || malformed_status=$?
            [[ $malformed_status == 70 && ! -s "$malformed_evidence/events/storage-observer-r01.jsonl" &&
               -z "$(/usr/bin/grep -R "$sentinel" "$malformed_evidence" 2>/dev/null)" ]] || exit 75
            exclusive="$fixture/exclusive"; /bin/mkdir -m 700 "$fixture/exclusive-sibling"
            observer_evidence_write_test_hook() { [[ "$1" != summary.md ]] || { print replacement >"$exclusive/summary.md"; /bin/chmod 600 "$exclusive/summary.md"; } }
            terminal_class=pass_unchanged; terminal_exit_status=0; terminal_finalized=false; terminal_finalizing=false
            exclusive_status=0; finalize_controller "$exclusive" || exclusive_status=$?; unfunction observer_evidence_write_test_hook
            [[ $exclusive_status == 74 && $(/bin/cat "$exclusive/summary.md") == replacement && -d "$fixture/exclusive-sibling" ]] || exit 76
            observer_evidence_write_test_hook() { [[ "$1" != measurements.csv ]] }
            terminal_class=pass_unchanged; terminal_exit_status=0; terminal_finalized=false; terminal_finalizing=false
            retained_observer_events=""; mid="$fixture/mid"; mid_status=0
            finalize_controller "$mid" || mid_status=$?; unfunction observer_evidence_write_test_hook
            [[ $mid_status == 74 && "$terminal_class" == evidence_write_failed && -d "$mid" &&
               $(/usr/bin/find "$mid" -type f | /usr/bin/wc -l) -gt 0 ]] && assert_failure_safe "$mid" || exit 76
            observer_evidence_postcondition_test_hook() { print unexpected >"$1/unexpected" }
            terminal_class=pass_unchanged; terminal_phase=hosted; terminal_exit_status=0; terminal_finalized=false; terminal_finalizing=false; post="$fixture/post"; post_status=0; finalize_controller "$post" || post_status=$?
            [[ $post_status == 74 && -e "$post/unexpected" ]] && assert_failure_safe "$post" || exit 77
            unfunction observer_evidence_postcondition_test_hook; observer_evidence_promotion_test_hook() { [[ "$1" != measurements.csv ]] }
            terminal_class=pass_unchanged; terminal_phase=hosted; terminal_exit_status=0; terminal_finalized=false; terminal_finalizing=false; promotion="$fixture/promotion"; promotion_status=0; finalize_controller "$promotion" || promotion_status=$?; unfunction observer_evidence_promotion_test_hook
            [[ $promotion_status == 74 ]] && assert_failure_safe "$promotion" || exit 78
            reset_case() { terminal_class=pass_unchanged; terminal_phase=hosted; terminal_exit_status=0; terminal_finalized=false; terminal_finalizing=false; retained_observer_events="" }
            observer_evidence_before_commit_test_hook() { /bin/mv "$2/environment.json" "$2/environment.original"; print replacement >"$2/environment.json"; /bin/chmod 600 "$2/environment.json" }
            reset_case; replaced="$fixture/replaced"; replaced_status=0; finalize_controller "$replaced" || replaced_status=$?; unfunction observer_evidence_before_commit_test_hook
            [[ $replaced_status == 74 && -e "$success_staging_root/environment.original" && -e "$success_staging_root/environment.json" ]] && assert_failure_safe "$replaced" || exit 79
            observer_evidence_before_commit_test_hook() { /bin/mv "$2" "$2.original"; /bin/mkdir -m 755 "$2" }
            reset_case; directory="$fixture/directory"; directory_status=0; finalize_controller "$directory" || directory_status=$?; unfunction observer_evidence_before_commit_test_hook
            [[ $directory_status == 74 && -d "$success_staging_root" && -d "$success_staging_root.original" ]] && assert_failure_safe "$directory" || exit 80
            observer_evidence_before_commit_test_hook() { /bin/mv "$1" "$1.original"; /bin/mkdir -m 755 "$1" }
            reset_case; retained="$fixture/retained"; retained_status=0; finalize_controller "$retained" || retained_status=$?; unfunction observer_evidence_before_commit_test_hook; [[ $retained_status == 74 && -d "$retained" && -d "$retained.original" ]] && assert_failure_safe "$retained.original" || exit 84
            observer_evidence_before_commit_test_hook() { /bin/mv "$2/events" "$2/events.original"; /bin/mkdir -m 755 "$2/events" }
            reset_case; events="$fixture/events"; events_status=0; finalize_controller "$events" || events_status=$?; unfunction observer_evidence_before_commit_test_hook; [[ $events_status == 74 && -d "$success_staging_root/events" && -d "$success_staging_root/events.original" ]] && assert_failure_safe "$events" || exit 85
            observer_evidence_commit_test_hook() { /bin/mkdir -m 755 "$1/.${2}.pending.${3##*.}"; /bin/mkdir -m 700 "$fixture/commit-collision-sibling" }
            reset_case; collision="$fixture/collision"; collision_status=0; finalize_controller "$collision" || collision_status=$?; unfunction observer_evidence_commit_test_hook
            [[ $collision_status == 74 && -d "$collision" && -d "$fixture/.collision.pending.${success_staging_root##*.}" && -d "$fixture/commit-collision-sibling" ]] && assert_failure_safe "$collision" && assert_complete_success "$success_staging_root" || exit 81
            observer_evidence_final_postcondition_test_hook() { print unexpected >"$1/unexpected" }
            reset_case; schema="$fixture/schema"; schema_status=0; finalize_controller "$schema" || schema_status=$?; unfunction observer_evidence_final_postcondition_test_hook
            [[ $schema_status == 74 && -e "$success_staging_root/unexpected" ]] && assert_failure_safe "$schema" || exit 82
            primitive="$fixture/primitive"; /bin/mkdir -m 755 "$primitive" "$primitive/source" "$primitive/destination" "$primitive/sibling"; primitive_parent_identity=$(evidence_directory_identity "$primitive" 755); primitive_source_identity=$(evidence_directory_identity "$primitive/source" 755); primitive_status=0; rename_directory_exclusively "$primitive" "$primitive_parent_identity" source "$primitive_source_identity" destination 3 || primitive_status=$?
            [[ $primitive_status == 73 && -d "$primitive/source" && -d "$primitive/destination" && -d "$primitive/sibling" && ! -e "$primitive/destination/source" ]] || exit 92
            observer_evidence_final_move_test_hook() { /bin/mkdir -m 755 "$1/$2"; /bin/mkdir -m 700 "$fixture/final-collision-sibling" }; reset_case; late="$fixture/late-collision"; late_status=0; finalize_controller "$late" || late_status=$?; unfunction observer_evidence_final_move_test_hook; set +e; late_public=$(emit_controller_terminal "$late_status" 2>&1); late_public_status=$?; set -e
            [[ $late_status == 74 && $late_public_status == 74 && -z "$late_public" && "$evidence_commit_reconciliation_state" == absent_authority_collision_retained && -d "$late" && -d "$success_staging_root" && -d "$fixture/final-collision-sibling" && -z "$(/usr/bin/find "$late" -mindepth 1 -maxdepth 1 -print -quit)" ]] && assert_complete_success "$success_staging_root" || exit 93
            export HTDV_OBSERVER_TEST_POST_SWAP=exit70; reset_case; interrupted="$fixture/interrupted"; interrupted_status=0
            finalize_controller "$interrupted" || interrupted_status=$?; unset HTDV_OBSERVER_TEST_POST_SWAP
            [[ $interrupted_status == 74 && $evidence_commit_helper_status == 70 && "$evidence_commit_reconciliation_state" == absent_authority && ! -e "$interrupted" && -d "$success_staging_root" ]] && assert_complete_success "$success_staging_root" || exit 86
            timeout_executable=\(shellQuote(timeout)); metadata_timeout_seconds=0.2; evidence_post_swap_reserve_seconds=3; run_metadata_probe() { run_timed_command "$metadata_timeout_seconds" 0 1 "$@"; }
            export HTDV_OBSERVER_TEST_POST_SWAP=sleep; deadline=$(( SECONDS + 5 )); reset_case; timed="$fixture/timed"; timed_status=0; finalize_controller "$timed" || timed_status=$?; unset HTDV_OBSERVER_TEST_POST_SWAP
            [[ $timed_status == 74 && $evidence_commit_helper_status == 124 && "$evidence_commit_reconciliation_state" == absent_authority && ! -e "$timed" && -d "$success_staging_root" ]] && assert_complete_success "$success_staging_root" || exit 87
            export HTDV_OBSERVER_TEST_POST_SWAP=exit70 HTDV_OBSERVER_TEST_POST_SWAP_RECONCILE=sleep; deadline=$(( SECONDS + 3 )); reset_case; stalled="$fixture/stalled"; stalled_status=0; finalize_controller "$stalled" || stalled_status=$?; unset HTDV_OBSERVER_TEST_POST_SWAP HTDV_OBSERVER_TEST_POST_SWAP_RECONCILE
            run_metadata_probe() { "$@" }; metadata_timeout_seconds=15; evidence_post_swap_reserve_seconds=30; deadline=$(( SECONDS + 60 )); [[ $stalled_status == 74 && $evidence_commit_helper_status == 70 && "$evidence_commit_reconciliation_state" == absent_authority && ! -e "$stalled" ]] && assert_complete_success "$success_staging_root" || exit 91
            /bin/mkdir -m 700 "$fixture/late-cleanup-sibling"; export HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER=4
            reset_case; partial="$fixture/partial-cleanup"; partial_status=0; finalize_controller "$partial" || partial_status=$?; unset HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER
            [[ $partial_status == 74 && "$evidence_commit_cleanup_state" == retained_failure_safe && -d "$success_staging_root" && -d "$evidence_failure_safe_quarantine_root" && -d "$fixture/late-cleanup-sibling" ]] && validate_runtime_evidence "$partial" pending && assert_complete_success "$success_staging_root" && assert_failure_safe "$partial" && assert_failure_safe "$evidence_failure_safe_quarantine_root" || exit 90
            cleanup_boundary_pending=true; observer_evidence_cleanup_boundary_test_hook() { [[ $cleanup_boundary_pending == false ]] || { cleanup_boundary_pending=false; /bin/mv "$1" "$1.original"; /bin/mkdir -m 755 "$1"; /bin/mkdir -m 700 "$fixture/cleanup-boundary-sibling"; } }; reset_case; cleanup_replaced="$fixture/cleanup-replaced"; cleanup_replaced_status=0; finalize_controller "$cleanup_replaced" || cleanup_replaced_status=$?; unfunction observer_evidence_cleanup_boundary_test_hook
            [[ $cleanup_replaced_status == 74 && -d "$success_staging_root" && -d "$evidence_failure_safe_quarantine_root" && -d "$evidence_failure_safe_quarantine_root.original" && -d "$fixture/cleanup-boundary-sibling" && -z "$evidence_recovery_staging_root" ]] && assert_failure_safe "$cleanup_replaced" && assert_failure_safe "$evidence_failure_safe_quarantine_root.original" || exit 89
            observer_evidence_cleanup_test_hook() { return 70 }
            reset_case; cleanup="$fixture/atomic-cleanup"; cleanup_status=0; finalize_controller "$cleanup" || cleanup_status=$?; unfunction observer_evidence_cleanup_test_hook
            [[ $cleanup_status == 74 && "$evidence_commit_cleanup_state" == retained_failure_safe && -d "$evidence_failure_safe_quarantine_root" ]] && assert_failure_safe "$cleanup" && assert_failure_safe "$evidence_failure_safe_quarantine_root" && assert_complete_success "$success_staging_root" || exit 83
            cleanup_state=complete; evidence_write_state=complete; terminal_class=pass_unchanged; set +e; public_output=$(emit_controller_terminal 0 2>&1); public_status=$?; set -e
            [[ $public_status == 74 && -z "$public_output" ]] || exit 88
            print terminal_evidence=pass; /bin/rm -rf -- "$fixture"
            """])
        #expect(result.status == 0)
        #expect(result.output == "terminal_evidence=pass\n")
    }
    @Test func cleanupDeletesStableIdentityAndRetainsReplacementAndSibling() throws {
        let stable = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_cleanup_command() { "$@" }
            run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-cleanup.XXXXXXXX)
            /bin/chmod 700 "$run_root"
            run_root_identity=$(identity "$run_root" 700)
            validate_roots() { return 0 }
            cleanup_run_root
            [[ -z "$run_root" ]] && print stable_removed
            """])
        #expect(stable.status == 0)
        #expect(stable.output == "stable_removed\n")
        let replacement = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_cleanup_command() { "$@" }
            fixture=$(/usr/bin/mktemp -d /private/tmp/holdtype-observer-race.XXXXXXXX)
            /bin/chmod 700 "$fixture"
            run_root="$fixture/run"; /bin/mkdir -m 700 "$run_root"
            run_root_identity=$(identity "$run_root" 700)
            sibling="$fixture/sibling"; /bin/mkdir -m 700 "$sibling"
            validate_roots() { return 0 }
            observer_cleanup_test_hook() {
                /bin/mv "$run_root" "${run_root}.original"
                /bin/mkdir -m 700 "$run_root"
            }
            set +e; cleanup_run_root; cleanup_status=$?; set -e
            [[ $cleanup_status == 70 && -n "$run_root" && -d "${run_root}.original" &&
               -d "${run_root}.cleanup" && -d "$sibling" ]] && print replacement_retained
            /bin/rm -rf -- "$fixture"
            """])
        #expect(replacement.status == 0)
        #expect(replacement.output == "replacement_retained\n")
    }
    @Test func productionXCTestRunConfigurationInjectsTheClosedHostedEnvironment() throws {
        let result = try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath))
            run_metadata_probe() { "$@" }
            run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-dev-vlogs-observer.XXXXXXXX)
            /bin/chmod 700 "$run_root"
            task_home="$run_root/home"; derived_data="$task_home/DerivedData"
            products="$derived_data/Build/Products"
            /bin/mkdir -m 700 -p "$products"
            source_file="$products/HoldType_fixture.xctestrun"
            /usr/bin/plutil -create xml1 "$source_file"
            /usr/bin/plutil -insert HoldTypeTests -dictionary "$source_file"
            /usr/bin/plutil -insert HoldTypeTests.EnvironmentVariables -dictionary "$source_file"
            /bin/chmod 644 "$source_file"
            run_id=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee
            validate_roots() { return 0 }
            configure_hosted_xctestrun || exit 71
            [[ "$host_task_home" == /tmp/holdtype-dev-vlogs-observer.*/home &&
               "$host_temporary_root" == "$host_task_home/tmp" &&
               -n "$configured_xctestrun_identity" ]] || exit 72
            for key in HOME CFFIXED_USER_HOME TMPDIR HOLDTYPE_AUTOMATION \
                HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_RUN_ID \
                HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_CASE_ID; do
                /usr/bin/plutil -extract "HoldTypeTests.EnvironmentVariables.$key" raw -o - \
                    "$configured_xctestrun" >/dev/null || exit 73
            done
            print xctestrun_environment=pass
            /bin/rm -rf -- "$run_root"
            """])
        #expect(result.status == 0)
        #expect(result.output == "xctestrun_environment=pass\n")
    }
    @Test func syntheticProbeCoversMissingPresentSymlinkAndModePredicates() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let binary = fixture.root.appendingPathComponent("probe").path
        let compile = try run(["/usr/bin/clang", "-std=c11", "-Wall", "-Wextra", "-Werror",
            "-DHTDV_PROBE_SYNTHETIC=1", probePath, "-o", binary])
        #expect(compile.status == 0)
        var environment = ProcessInfo.processInfo.environment
        environment["HTDV_PROBE_FIXTURE_ROOT"] = fixture.root.path
        environment["HTDV_PROBE_FIXTURE_USER"] = "fixture-user"
        let missing = try run([binary], environment: environment)
        #expect(missing.status == 0 && missing.output == "D|M\nI|M\n")
        let recovery = fixture.home.appendingPathComponent(
            "Library/Application Support/HoldType/TranscriptionRecovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        for path in [
            fixture.home.appendingPathComponent("Library"),
            fixture.home.appendingPathComponent("Library/Application Support"),
            fixture.home.appendingPathComponent("Library/Application Support/HoldType"),
            recovery,
        ] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                  ofItemAtPath: path.path)
        }
        let index = recovery.appendingPathComponent("Recovery.json")
        FileManager.default.createFile(atPath: index.path, contents: Data("fixture".utf8),
                                      attributes: [.posixPermissions: 0o600])
        let present = try run([binary], environment: environment)
        #expect(present.status == 0)
        #expect(present.output.split(separator: "\n").count == 2)
        try FileManager.default.removeItem(at: index)
        let indexMissing = try run([binary], environment: environment)
        #expect(indexMissing.status == 0 && indexMissing.output.contains("I|M\n"))
        FileManager.default.createFile(atPath: index.path, contents: Data("fixture".utf8),
                                      attributes: [.posixPermissions: 0o600])
        let linked = recovery.appendingPathComponent("linked-index")
        try FileManager.default.linkItem(at: index, to: linked)
        #expect(try run([binary], environment: environment).status == 65)
        try FileManager.default.removeItem(at: linked)
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: index.path)
        #expect(try run([binary], environment: environment).status == 65)
        try FileManager.default.removeItem(at: index)
        try FileManager.default.createSymbolicLink(at: index,
            withDestinationURL: fixture.root.appendingPathComponent("unopened-target"))
        #expect(try run([binary], environment: environment).status == 65)
    }
    @Test func probeSourcePinsNoEnumerationNoIndexOpenAndPrePostIdentityCheck() throws {
        let source = try String(contentsOfFile: probePath, encoding: .utf8)
        for forbidden in ["readdir(", "opendir(", "fopen(", "read(", "Data(contentsOf:"] {
            #expect(!source.contains(forbidden))
        }
        #expect(source.contains("fstatat(current, \"Recovery.json\", &index_value, AT_SYMLINK_NOFOLLOW)"))
        #expect(source.contains("fstat(fd, &after)"))
        #expect(source.contains("same_identity(&before, &after)"))
        #expect(!source.contains("openat(current, \"Recovery.json\""))
    }
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private var scriptPath: String { repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0_b_protected_storage_observer.sh").path }
    private var probePath: String { repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0_b_protected_storage_probe.c").path }
    private var summaryPath: String { repositoryRoot.appendingPathComponent("docs/qa/runs/dev-vlogs-phase-0b-storage-observer-w01/summary.md").path }
    private var runID: String { "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee" }
    private var otherRunID: String { "11111111-2222-4333-8444-555555555555" }
    private var readyLine: String {
        observerLine(1, "observer_ready", "none", "observer", "not_applicable", "ready")
    }
    private func observerLine(_ sequence: Int, _ event: String, _ action: String,
                              _ category: String, _ scope: String, _ result: String,
                              runID: String? = nil) -> String {
        "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "
            + "{\"schema_version\":1,\"run_id\":\"\(runID ?? self.runID)\","
            + "\"case_id\":\"protected_metadata\",\"sequence\":\(sequence),"
            + "\"event\":\"\(event)\",\"action\":\"\(action)\","
            + "\"category\":\"\(category)\",\"target_scope\":\"\(scope)\","
            + "\"result\":\"\(result)\"}"
    }
    private func parseStream(_ lines: [String]) throws -> (status: Int32, output: String) {
        try runStream(lines, command: "validate_observer_stream \"$stream\" \(runID)")
    }
    private func classifyStream(_ lines: [String], concurrent: String) throws
        -> (status: Int32, output: String) {
        try runStream(lines, command:
            "classify_observer_stream_result \"$stream\" \(runID) unchanged passed changed \(concurrent)")
    }
    private func runStream(_ lines: [String], command: String) throws
        -> (status: Int32, output: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-observer-stream-\(UUID().uuidString.lowercased())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let stream = root.appendingPathComponent("events.log")
        try (lines.joined(separator: "\n") + "\n").write(to: stream, atomically: true,
                                                          encoding: .utf8)
        return try run(["/bin/zsh", "-c", """
            source \(shellQuote(scriptPath)); run_metadata_probe() { "$@" }
            stream=\(shellQuote(stream.path)); \(command)
            """])
    }
    private func timeoutExecutable() throws -> String {
        let paths = ["/opt/homebrew/bin/timeout", "/usr/local/bin/timeout", "/usr/bin/timeout"]
        return try #require(paths.first(where: FileManager.default.isExecutableFile(atPath:)))
    }
    private func makeFixture() throws -> (root: URL, home: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-observer-probe-\(UUID().uuidString.lowercased())")
        let users = root.appendingPathComponent("Users")
        let home = users.appendingPathComponent("fixture-user")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        for path in [root, users, home] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        }
        return (root, home)
    }
    private func privateObserverRoots() throws -> Set<String> {
        let values = try FileManager.default.contentsOfDirectory(atPath: "/private/tmp")
        return Set(values.filter { $0.hasPrefix("holdtype-dev-vlogs-observer.") })
    }
    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    private func run(
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
#endif
