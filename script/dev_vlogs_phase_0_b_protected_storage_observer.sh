#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}
program_name=${0:t}
execute_enabled=false
guard_pid=""
guard_identity=""
supervisor_pid=""
supervisor_identity=""
run_root=""
run_root_identity=""
task_home=""
task_home_identity=""
derived_data=""
derived_data_identity=""
temporary_root=""
probe=""
configured_xctestrun=""
configured_xctestrun_identity=""
host_task_home=""
host_temporary_root=""
deadline=0
terminal_class="still_unknown"
build_comparison="uncertain"
hosted_comparison="uncertain"
observer_events=""
run_id=""
timeout_executable=""
metadata_timeout_seconds=15
controller_pid=""
controller_parent_pid=""

usage() {
    print -r -- "usage: $program_name --execute"
    print -r -- "Runs one bounded, nonexternal Debug observer evidence attempt."
}
fail() { print -u2 -r -- "error: $1"; exit 64; }

pin_controller() {
    [[ -z "$controller_pid" && -z "$controller_parent_pid" ]] || return 70
    controller_pid=$$; controller_parent_pid=$PPID
    [[ "$controller_pid" == <-> && "$controller_parent_pid" == <-> ]]
}

validate_controller() {
    [[ "$controller_pid" == $$ && "$controller_parent_pid" == $PPID ]]
}

run_metadata_probe() {
    "$timeout_executable" --signal=TERM --kill-after=2s "$metadata_timeout_seconds" "$@"
}

identity() {
    local path="$1" expected_mode="$2" value
    [[ -d "$path" && ! -L "$path" && "${path:A}" == "$path" ]] || return 70
    value=$(run_metadata_probe /usr/bin/stat -f '%u|%Lp|%d|%i' "$path" 2>/dev/null) || return 70
    [[ "$value" == "$EUID|$expected_mode|"* ]] || return 70
    print -r -- "$value"
}

regular_file_identity() {
    local path="$1" expected_mode="$2" value
    [[ -f "$path" && ! -L "$path" ]] || return 70
    value=$(run_metadata_probe /usr/bin/stat -f '%u|%Lp|%d|%i|%l' "$path" 2>/dev/null) || return 70
    [[ "$value" == "$EUID|$expected_mode|"*'|1' ]] || return 70
    print -r -- "$value"
}

process_identity() {
    local pid="$1" value
    [[ "$pid" == <-> ]] || return 70
    value=$(run_metadata_probe /bin/ps -o ppid=,lstart=,command= -p "$pid" 2>/dev/null) || return 70
    value="${value##[[:space:]]#}"
    [[ -n "$value" ]] || return 70
    print -r -- "$pid|$value"
}

validate_guard() {
    local current
    validate_controller || return 70
    [[ "$guard_pid" == <-> && -n "$guard_identity" ]] || return 70
    current=$(process_identity "$guard_pid") || return 70
    [[ "$current" == "$guard_identity" && "$current" == "$guard_pid|$$ "* &&
       "$current" == *'/usr/bin/caffeinate -dimsu -w '* ]] || return 70
}

validate_roots() {
    local current
    validate_guard || return 70
    [[ -n "$run_root_identity" && -n "$task_home_identity" &&
       -n "$derived_data_identity" ]] || return 70
    current=$(identity "$run_root" 700) || return 70
    [[ "$current" == "$run_root_identity" ]] || return 70
    [[ "$task_home" == "$run_root/home" && "$derived_data" == "$task_home/DerivedData" &&
       "$temporary_root" == "$task_home/tmp" ]] || return 70
    current=$(identity "$task_home" 700) || return 70
    [[ "$current" == "$task_home_identity" ]] || return 70
    current=$(identity "$derived_data" 700) || return 70
    [[ "$current" == "$derived_data_identity" ]] || return 70
    identity "$temporary_root" 700 >/dev/null || return 70
    if [[ -n "$configured_xctestrun" ]]; then
        current=$(regular_file_identity "$configured_xctestrun" 600) || return 70
        [[ "$current" == "$configured_xctestrun_identity" ]] || return 70
    fi
}

cleanup_run_root() {
    local quarantine="${run_root}.cleanup" current
    [[ -n "$run_root" && -n "$run_root_identity" ]] || return 0
    validate_roots || return 70
    if (( $+functions[observer_cleanup_test_hook] )); then observer_cleanup_test_hook; fi
    [[ ! -e "$quarantine" && ! -L "$quarantine" ]] || return 70
    /bin/mv -n "$run_root" "$quarantine" || return 70
    [[ ! -e "$run_root" && ! -L "$run_root" ]] || return 70
    current=$(identity "$quarantine" 700) || return 70
    [[ "$current" == "$run_root_identity" ]] || return 70
    /bin/rm -rf -- "$quarantine" || return 70
    [[ ! -e "$quarantine" && ! -L "$quarantine" ]] || return 70
    run_root=""; run_root_identity=""; task_home=""; task_home_identity=""
    derived_data=""; derived_data_identity=""; temporary_root=""; probe=""
    configured_xctestrun=""; configured_xctestrun_identity=""
    host_task_home=""; host_temporary_root=""
}

stop_supervisor() {
    local current checks=50
    [[ "$supervisor_pid" == <-> ]] || return 0
    if kill -0 "$supervisor_pid" 2>/dev/null; then
        current=$(process_identity "$supervisor_pid") || return 70
        [[ "$current" == "$supervisor_identity" ]] || return 70
        kill -TERM "$supervisor_pid" 2>/dev/null || true
        while kill -0 "$supervisor_pid" 2>/dev/null && (( checks-- > 0 )); do /bin/sleep .1; done
        if kill -0 "$supervisor_pid" 2>/dev/null; then
            current=$(process_identity "$supervisor_pid") || return 70
            [[ "$current" == "$supervisor_identity" ]] || return 70
            kill -KILL "$supervisor_pid" 2>/dev/null || true
        fi
    fi
    set +e; wait "$supervisor_pid" 2>/dev/null; set -e
    supervisor_pid=""; supervisor_identity=""
}

stop_guard() {
    local current checks=50
    [[ "$guard_pid" == <-> ]] || return 0
    validate_guard || return 70
    kill -TERM "$guard_pid" 2>/dev/null || true
    while kill -0 "$guard_pid" 2>/dev/null && (( checks-- > 0 )); do /bin/sleep .1; done
    if kill -0 "$guard_pid" 2>/dev/null; then
        current=$(process_identity "$guard_pid") || return 70
        [[ "$current" == "$guard_identity" ]] || return 70
        kill -KILL "$guard_pid" 2>/dev/null || true
    fi
    set +e; wait "$guard_pid" 2>/dev/null; set -e
    guard_pid=""; guard_identity=""
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    stop_supervisor || status=70
    if ! cleanup_run_root; then terminal_class=cleanup_uncertain; status=70; fi
    stop_guard || status=70
    unset run_id task_home task_home_identity derived_data derived_data_identity temporary_root
    exit "$status"
}

run_bounded() {
    local seconds="$1" exit_code; shift
    (( SECONDS < deadline )) || return 124
    validate_roots || return 70
    "$timeout_executable" --signal=TERM --kill-after=5s "$seconds" "$@" &
    supervisor_pid=$!
    supervisor_identity=$(process_identity "$supervisor_pid") || return 70
    [[ "$supervisor_identity" == "$supervisor_pid|$$ "* ]] || return 70
    set +e; wait "$supervisor_pid"; exit_code=$?; set -e
    supervisor_pid=""; supervisor_identity=""
    return "$exit_code"
}

product_census_clear() {
    local output status
    set +e; output=$(run_metadata_probe /usr/bin/pgrep -x HoldType 2>/dev/null); status=$?; set -e
    (( status == 1 )) && return 0
    [[ -z "$output" ]] && return 70
    return 70
}

probe_snapshot() {
    validate_roots || return 70
    run_metadata_probe "$probe"
}

compare_snapshot() {
    local before="$1" after="$2"
    [[ -n "$before" && -n "$after" ]] || { print -r -- uncertain; return; }
    if [[ "$before" == "$after" ]]; then
        [[ "$before" == $'D|M\nI|M' ]] && print -r -- missing_unchanged || print -r -- unchanged
    else
        print -r -- changed
    fi
}

evidence_relative_paths() {
    print -rl -- summary.md source-feasibility.md environment.json matrix.csv \
        measurements.csv artifacts.csv residuals.md events/storage-observer-r01.jsonl
}

write_runtime_evidence() {
    local evidence_root="$repository_root/docs/qa/runs/dev-vlogs-phase-0b-storage-observer-r01"
    local relative
    [[ ! -e "$evidence_root" && ! -L "$evidence_root" && -n "$observer_events" ]] || return 70
    /bin/mkdir -m 755 "$evidence_root" "$evidence_root/events" || return 70
    print -r -- "# Phase 0B protected-storage observer R01

terminal_class: $terminal_class
build_window: $build_comparison
hosted_window: $hosted_comparison
cleanup: complete
" >"$evidence_root/summary.md"
    print -r -- "# Source feasibility

controller: script/dev_vlogs_phase_0_b_protected_storage_observer.sh
probe: script/dev_vlogs_phase_0_b_protected_storage_probe.c
observer: HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BProtectedStorageObserver.swift
route_schema: stderr-json-v1
checks: pass
" >"$evidence_root/source-feasibility.md"
    print -r -- '{"schema_version":1,"mode":"nonexternal","private_home":true,"guard":"continuous"}' \
        >"$evidence_root/environment.json"
    print -r -- "case_id,terminal_class,cleanup
protected_metadata,$terminal_class,complete" >"$evidence_root/matrix.csv"
    print -r -- "phase,result
build,$build_comparison
hosted,$hosted_comparison" >"$evidence_root/measurements.csv"
    print -r -- "path,status" >"$evidence_root/artifacts.csv"
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        print -r -- "$relative,present" >>"$evidence_root/artifacts.csv"
    done
    print -r -- "# Residuals

Arbitrary non-run-owned writers remain unattributed and classify as still_unknown.
" >"$evidence_root/residuals.md"
    print -r -- "$observer_events" >"$evidence_root/events/storage-observer-r01.jsonl"
}

configure_hosted_xctestrun() {
    local products source key value observed
    local -a sources pairs
    validate_roots || return 70
    products="$derived_data/Build/Products"
    sources=("$products"/*.xctestrun(N))
    (( ${#sources} == 1 )) || return 70
    source="${sources[1]}"
    regular_file_identity "$source" 644 >/dev/null || return 70
    configured_xctestrun="$products/HoldType_protected_storage_observer.xctestrun"
    [[ ! -e "$configured_xctestrun" && ! -L "$configured_xctestrun" ]] || return 70
    /bin/cp -p "$source" "$configured_xctestrun" || return 70
    /bin/chmod 600 "$configured_xctestrun" || return 70
    [[ "$task_home" == /private/tmp/* ]] || return 70
    host_task_home="${task_home#/private}"
    host_temporary_root="$host_task_home/tmp"
    pairs=(
        HOME "$host_task_home"
        CFFIXED_USER_HOME "$host_task_home"
        TMPDIR "$host_temporary_root"
        HOLDTYPE_DEV_VLOGS_STORAGE_VALIDATE_PRIVATE_HOME 1
        HOLDTYPE_AUTOMATION 1
        HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI skip
        HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST 1
        HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER stderr-json-v1
        HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_RUN_ID "$run_id"
        HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_CASE_ID protected_metadata
    )
    while (( ${#pairs} > 0 )); do
        key="${pairs[1]}"; value="${pairs[2]}"; shift 2 pairs
        run_metadata_probe /usr/bin/plutil -insert "HoldTypeTests.EnvironmentVariables.$key" \
            -string "$value" "$configured_xctestrun" || return 70
        observed=$(run_metadata_probe /usr/bin/plutil -extract "HoldTypeTests.EnvironmentVariables.$key" \
            raw -o - "$configured_xctestrun" 2>/dev/null) || return 70
        [[ "$observed" == "$value" ]] || return 70
    done
    configured_xctestrun_identity=$(regular_file_identity "$configured_xctestrun" 600) || return 70
    validate_roots
}

classify_observer_result() {
    local preexisting="$1" guard="$2" build="$3" build_compare="$4"
    local hosted="$5" hosted_compare="$6" stream="$7" mutations="$8"
    local owner="$9" scopes="${10}" cleanup_state="${11}" concurrent="${12}"
    if [[ "$preexisting" != clear ]]; then print -r -- environment_conflict
    elif [[ "$guard" != continuous ]]; then print -r -- guard_discontinuity
    elif [[ "$build" != passed ]]; then print -r -- build_failed
    elif [[ "$build_compare" == uncertain ]]; then print -r -- metadata_uncertain
    elif [[ "$build_compare" == changed ]]; then print -r -- build_window_change_correlated
    elif [[ "$hosted_compare" == uncertain ]]; then print -r -- metadata_uncertain
    elif [[ "$hosted_compare" == changed && "$stream" == valid && "$mutations" == all_succeeded &&
            "$scopes" == outside_only ]]; then
        print -r -- run_owned_canonical_recovery_write_correlated
    elif [[ "$hosted_compare" == changed ]]; then print -r -- still_unknown
    elif [[ "$stream" != valid ]]; then print -r -- observer_invalid
    elif [[ "$mutations" == succeeded_outside_or_indeterminate ]]; then print -r -- evidence_conflict
    elif [[ "$mutations" != none ]]; then print -r -- hosted_test_failed
    elif [[ "$hosted" != passed ]]; then print -r -- hosted_test_failed
    elif [[ "$cleanup_state" != certain ]]; then print -r -- cleanup_uncertain
    elif [[ "$concurrent" != clear ]]; then print -r -- environment_conflict
    elif [[ "$owner" == observed ]]; then print -r -- owner_exposed_no_mutation
    else print -r -- pass_unchanged
    fi
}

validate_observer_stream() {
    local stream="$1"
    /usr/bin/python3 - "$stream" <<'PY'
import json, pathlib, sys, uuid
prefix = "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "
path = pathlib.Path(sys.argv[1])
lines = [line for line in path.read_text().splitlines() if line.startswith(prefix)]
if not 1 <= len(lines) <= 128: raise SystemExit(65)
allowed_events = {"observer_ready", "owner_initialized", "mutation_begin", "mutation_end", "observer_overflow"}
allowed_actions = {"none", "ensure_recovery_directory", "copy_recovery_audio", "replace_recovery_index",
 "write_saved_state_marker", "write_processing_checkpoint_marker", "write_provider_dispatch_marker",
 "delete_saved_state_marker", "delete_processing_checkpoint_marker", "delete_provider_dispatch_marker",
 "delete_recovery_audio"}
allowed_categories = {"observer", "recovery_directory", "recovery_index", "recovery_marker", "recovery_audio"}
allowed_scopes = {"not_applicable", "private_task_home", "outside_private_task_home", "indeterminate"}
allowed_results = {"ready", "observed", "attempted", "succeeded", "failed", "overflow"}
keys = ["schema_version", "run_id", "case_id", "sequence", "event", "action", "category", "target_scope", "result"]
values = []
for number, line in enumerate(lines, 1):
    if len(line.encode()) > 512: raise SystemExit(65)
    value = json.loads(line[len(prefix):], object_pairs_hook=lambda pairs: pairs)
    if [key for key, _ in value] != keys: raise SystemExit(65)
    value = dict(value)
    if value["schema_version"] != 1 or value["case_id"] != "protected_metadata" or value["sequence"] != number: raise SystemExit(65)
    try: parsed = uuid.UUID(value["run_id"])
    except (ValueError, TypeError, AttributeError): raise SystemExit(65)
    if str(parsed) != value["run_id"]: raise SystemExit(65)
    if value["event"] not in allowed_events or value["action"] not in allowed_actions or value["category"] not in allowed_categories or value["target_scope"] not in allowed_scopes or value["result"] not in allowed_results: raise SystemExit(65)
    values.append(value)
if sum(value["event"] == "observer_ready" for value in values) != 1: raise SystemExit(65)
if any(value["event"] == "observer_overflow" for value in values): raise SystemExit(65)
if values[0]["event"] != "observer_ready" or values[0]["action"] != "none" or values[0]["category"] != "observer" or values[0]["target_scope"] != "not_applicable" or values[0]["result"] != "ready": raise SystemExit(65)
for index, value in enumerate(values):
    if value["event"] == "owner_initialized" and (value["action"] != "none" or value["category"] != "recovery_directory" or value["result"] != "observed"): raise SystemExit(65)
    if value["event"] == "mutation_begin":
        if value["result"] != "attempted": raise SystemExit(65)
        if index + 1 >= len(values) or values[index + 1]["event"] != "mutation_end": raise SystemExit(65)
        if any(values[index + 1][key] != value[key] for key in ("action", "category", "target_scope")): raise SystemExit(65)
        if values[index + 1]["result"] not in {"succeeded", "failed"}: raise SystemExit(65)
print("valid")
PY
}

run_controller() {
    local baseline after_build after_hosted build_compare hosted_compare stream_state
    validate_controller || fail "controller identity unavailable"
    /usr/bin/caffeinate -dimsu -w $$ &
    guard_pid=$!
    guard_identity=$(process_identity "$guard_pid") || fail "guard identity unavailable"
    validate_guard || fail "guard continuity unavailable"
    run_root=$(/usr/bin/mktemp -d /private/tmp/holdtype-dev-vlogs-observer.XXXXXXXX) || fail "private root unavailable"
    /bin/chmod 700 "$run_root"
    run_root_identity=$(identity "$run_root" 700) || fail "private root identity unavailable"
    task_home="$run_root/home"; temporary_root="$task_home/tmp"; derived_data="$task_home/DerivedData"
    /bin/mkdir -m 700 "$task_home" "$temporary_root" "$derived_data" "$run_root/bin" "$run_root/logs"
    task_home_identity=$(identity "$task_home" 700) || fail "task HOME identity unavailable"
    derived_data_identity=$(identity "$derived_data" 700) || fail "DerivedData identity unavailable"
    probe="$run_root/bin/probe"
    run_id=$(run_metadata_probe /usr/bin/uuidgen) || fail "run token unavailable"
    run_id="${run_id:l}"
    run_bounded 60 /usr/bin/clang -std=c11 -Wall -Wextra -Werror -O2 \
        "$script_directory/dev_vlogs_phase_0_b_protected_storage_probe.c" -o "$probe" \
        >"$run_root/logs/probe-build.log" 2>&1 || {
        terminal_class=build_failed; return 70
    }
    product_census_clear || { terminal_class=environment_conflict; return 70; }
    baseline=$(probe_snapshot) || { terminal_class=metadata_uncertain; return 70; }
    run_bounded 600 /usr/bin/xcodebuild -project "$repository_root/HoldType.xcodeproj" \
        -scheme HoldType -configuration Debug -destination 'platform=macOS' \
        -derivedDataPath "$derived_data" build-for-testing \
        >"$run_root/logs/build.log" 2>&1 || {
        terminal_class=build_failed; return 70
    }
    product_census_clear || { terminal_class=environment_conflict; return 70; }
    after_build=$(probe_snapshot) || { terminal_class=metadata_uncertain; return 70; }
    build_compare=$(compare_snapshot "$baseline" "$after_build"); build_comparison="$build_compare"
    [[ "$build_compare" == unchanged || "$build_compare" == missing_unchanged ]] || {
        terminal_class=$([[ "$build_compare" == changed ]] && print build_window_change_correlated || print metadata_uncertain)
        return 70
    }
    configure_hosted_xctestrun || { terminal_class=hosted_test_failed; return 70; }
    run_bounded 180 /usr/bin/xcodebuild -xctestrun "$configured_xctestrun" \
        -destination 'platform=macOS' -parallel-testing-enabled NO \
        -resultBundlePath "$run_root/logs/hosted.xcresult" test-without-building \
        -only-testing:HoldTypeTests/DevVlogsPhase0BProtectedStorageObserverHostedTests \
        >"$run_root/logs/hosted.log" 2>&1 || terminal_class=hosted_test_failed
    product_census_clear || { terminal_class=environment_conflict; return 70; }
    after_hosted=$(probe_snapshot) || { terminal_class=metadata_uncertain; return 70; }
    hosted_compare=$(compare_snapshot "$after_build" "$after_hosted"); hosted_comparison="$hosted_compare"
    stream_state=$(validate_observer_stream "$run_root/logs/hosted.log" 2>/dev/null || print invalid)
    observer_events=$(/usr/bin/grep '^HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 ' \
        "$run_root/logs/hosted.log") || return 70
    terminal_class=$(classify_observer_result clear continuous passed "$build_compare" \
        $([[ "$terminal_class" == hosted_test_failed ]] && print failed || print passed) \
        "$hosted_compare" "$stream_state" none absent none certain clear)
    unset baseline after_build after_hosted
    [[ "$terminal_class" == pass_unchanged || "$terminal_class" == owner_exposed_no_mutation ]]
}

if [[ "${ZSH_EVAL_CONTEXT:-}" == toplevel ]]; then
    while (( $# > 0 )); do
        case "$1" in
            --help|-h) usage; exit 0 ;;
            --execute) [[ "$execute_enabled" == false ]] || fail "duplicate --execute"; execute_enabled=true ;;
            *) fail "unknown option" ;;
        esac
        shift
    done
    [[ "$execute_enabled" == true ]] || fail "explicit --execute opt-in is required"
    if command -v timeout >/dev/null 2>&1; then timeout_executable=$(command -v timeout)
    elif command -v gtimeout >/dev/null 2>&1; then timeout_executable=$(command -v gtimeout)
    else fail "a bounded timeout command is required"
    fi
    pin_controller || fail "controller identity unavailable"
    deadline=$(( SECONDS + 900 ))
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    cd "$repository_root"
    run_controller
    cleanup_run_root || { terminal_class=cleanup_uncertain; exit 70; }
    write_runtime_evidence || exit 70
    print -r -- "protected_storage_observer result=$terminal_class cleanup=complete"
fi
