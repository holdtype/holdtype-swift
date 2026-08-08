#!/bin/zsh

set -euo pipefail
typeset -F 6 SECONDS

script_directory=${0:A:h}
repository_root=${script_directory:h}
program_name="$0"
mode="${1:---help}"
build_timeout_seconds=600
camera_id=""
capture_duration=10
case_id="capture"
permission_timeout_seconds=420
timeout_executable=""
capture_supervisor_pid=""
permission_app_pid=""
permission_deadline=""
permission_app_exit_status=""
permission_app_ppid=""
permission_app_executable=""
permission_app_command=""
permission_app_start=""
permission_app_inode=""
permission_operator_log=""
permission_marker=""
permission_supervision_uncertain=0
permission_preserve_root=0
permission_quiet_rescan_complete=0
observed_permission_ppid=""
observed_permission_executable=""
observed_permission_command=""
observed_permission_start=""
observed_permission_inode=""
typeset -a permission_baseline_pids=()
typeset -a permission_baseline_executables=()
typeset -a permission_baseline_commands=()
typeset -a permission_baseline_starts=()
typeset -a permission_baseline_inodes=()
typeset -a permission_registry_pids=()
typeset -a permission_registry_ppids=()
typeset -a permission_registry_executables=()
typeset -a permission_registry_commands=()
typeset -a permission_registry_starts=()
typeset -a permission_registry_inodes=()
typeset -a permission_registry_roles=()
typeset -a permission_registry_topologies=()

usage() {
    print -r -- "usage: $program_name [--help|--build-only|--request-camera-permission|--hardware --camera-id ID [--duration SECONDS] [--case-id ID]]"
    print -r -- ""
    print -r -- "--build-only  compile the Debug harness without launching camera or microphone"
    print -r -- "--request-camera-permission  explicitly request Camera access without starting capture"
    print -r -- "--hardware    explicit future hardware mode; never implied by another option"
}

timeout_command() {
    "$timeout_executable" "$@"
}

case "$mode" in
    --help|-h|help)
        (( $# == 0 )) || shift
        (( $# == 0 )) || { print -u2 -r -- "error: help accepts no additional arguments"; exit 64; }
        usage
        exit 0
        ;;
    --build-only)
        shift
        (( $# == 0 )) || { print -u2 -r -- "error: --build-only accepts no additional arguments"; exit 64; }
        ;;
    --request-camera-permission)
        shift
        (( $# == 0 )) || {
            print -u2 -r -- "error: --request-camera-permission accepts no additional arguments"
            exit 64
        }
        ;;
    --hardware)
        shift
        while (( $# > 0 )); do
            case "$1" in
                --camera-id)
                    (( $# >= 2 )) || { print -u2 -r -- "error: --camera-id requires a value"; exit 64; }
                    camera_id="$2"
                    shift 2
                    ;;
                --duration)
                    (( $# >= 2 )) || { print -u2 -r -- "error: --duration requires a value"; exit 64; }
                    capture_duration="$2"
                    shift 2
                    ;;
                --case-id)
                    (( $# >= 2 )) || { print -u2 -r -- "error: --case-id requires a value"; exit 64; }
                    case_id="$2"
                    shift 2
                    ;;
                *)
                    print -u2 -r -- "error: unknown option $1"
                    usage >&2
                    exit 64
                    ;;
            esac
        done
        [[ -n "$camera_id" ]] || { print -u2 -r -- "error: --hardware requires --camera-id"; exit 64; }
        [[ "$capture_duration" =~ '^[1-9][0-9]{0,2}$' ]] && (( capture_duration <= 900 )) || {
            print -u2 -r -- "error: duration must be a whole number from 1 through 900"
            exit 64
        }
        [[ "$case_id" =~ '^[A-Za-z0-9_-]{1,64}$' ]] || {
            print -u2 -r -- "error: case ID may contain only letters, numbers, hyphen, and underscore"
            exit 64
        }
        ;;
    *)
        print -u2 -r -- "error: unknown mode $mode"
        usage >&2
        exit 64
        ;;
esac

if command -v timeout >/dev/null 2>&1; then
    timeout_executable=$(command -v timeout)
elif command -v gtimeout >/dev/null 2>&1; then
    timeout_executable=$(command -v gtimeout)
else
    print -u2 -r -- "error: a bounded timeout command is required"
    exit 127
fi

run_root=$(mktemp -d "${TMPDIR%/}/holdtype-dv-p0b.XXXXXX")
resolved_temp_root=${TMPDIR:A}
resolved_run_root=${run_root:A}

terminate_capture_supervisor() {
    local child_pid="$capture_supervisor_pid"
    [[ "$child_pid" == <-> ]] || return 0
    if kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
        local checks_remaining=50
        while kill -0 "$child_pid" 2>/dev/null && (( checks_remaining > 0 )); do
            sleep 0.1
            checks_remaining=$(( checks_remaining - 1 ))
        done
        if kill -0 "$child_pid" 2>/dev/null; then
            kill -KILL "$child_pid" 2>/dev/null || true
        fi
    fi
    wait "$child_pid" 2>/dev/null || true
    capture_supervisor_pid=""
}

permission_timeout_cap() {
    local deadline="$1"
    local maximum_seconds="$2"
    [[ -n "$deadline" && "$maximum_seconds" == <-> ]] || return 1
    local -F 6 remaining_seconds=$(( deadline - SECONDS ))
    (( remaining_seconds > 0.0 )) || return 1
    if (( remaining_seconds < maximum_seconds )); then
        REPLY="$remaining_seconds"
    else
        REPLY="$maximum_seconds"
    fi
}

permission_sleep() {
    local deadline="$1"
    permission_timeout_cap "$deadline" 1 || return 1
    local -F 6 sleep_seconds="$REPLY"
    (( sleep_seconds < 0.1 )) || sleep_seconds=0.1
    sleep "$sleep_seconds"
    (( SECONDS <= deadline ))
}

read_permission_identity() {
    local child_pid="$1"
    local deadline="$2"
    local text_identity
    permission_timeout_cap "$deadline" 2 || return 1
    observed_permission_ppid=$(timeout_command "$REPLY" ps -p "$child_pid" -o ppid= |
        tr -d '[:space:]') || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    text_identity=$(timeout_command "$REPLY" lsof -a -p "$child_pid" -d txt -Ffin 2>/dev/null |
        awk '
            /^ftxt$/ { in_text = 1; next }
            in_text && /^i/ && inode == "" { inode = substr($0, 2); next }
            in_text && /^n/ { print inode "\t" substr($0, 2); exit }
        ') || return 1
    observed_permission_inode="${text_identity%%$'\t'*}"
    observed_permission_executable="${text_identity#*$'\t'}"
    permission_timeout_cap "$deadline" 2 || return 1
    observed_permission_command=$(timeout_command "$REPLY" ps -ww -p "$child_pid" -o command= |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    observed_permission_start=$(timeout_command "$REPLY" ps -p "$child_pid" -o lstart= |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    [[ -n "$observed_permission_ppid" && -n "$observed_permission_inode" &&
        -n "$observed_permission_executable" && -n "$observed_permission_command" &&
        -n "$observed_permission_start" ]]
}

permission_process_is_active() {
    local child_pid="$1"
    local deadline="$2"
    kill -0 "$child_pid" 2>/dev/null || return 1
    permission_timeout_cap "$deadline" 1 || return 2
    local process_state
    if ! process_state=$(timeout_command "$REPLY" ps -p "$child_pid" -o state= |
        tr -d '[:space:]'); then
        kill -0 "$child_pid" 2>/dev/null || return 1
        return 2
    fi
    [[ -n "$process_state" ]] || return 2
    [[ "$process_state" == Z* ]] && return 1
    return 0
}

permission_marker_matches() {
    local child_pid="$1"
    local deadline="$2"
    permission_timeout_cap "$deadline" 2 || return 1
    timeout_command "$REPLY" ps -E -ww -p "$child_pid" -o command= |
        awk -v marker="$permission_marker" '
            {
                for (field = 1; field <= NF; field += 1) {
                    if ($field == marker) {
                        found = 1
                    }
                }
            }
            END { exit(found ? 0 : 1) }
        ' >/dev/null
}

discover_permission_candidate_pids() {
    local deadline="$1"
    local output
    local command_status=0
    permission_timeout_cap "$deadline" 2 || return 1
    set +e
    output=$(timeout_command "$REPLY" lsof -t -- "$app_binary" 2>/dev/null)
    command_status=$?
    set -e
    (( command_status == 0 || command_status == 1 )) || return 1
    REPLY="$output"
}

permission_identity_is_target() {
    [[ "$observed_permission_executable" == "$app_binary" &&
       "$observed_permission_command" == "$app_binary" &&
       "$observed_permission_inode" == "$permission_app_inode" ]]
}

permission_baseline_contains_observed() {
    local index=1
    while (( index <= ${#permission_baseline_pids} )); do
        if [[ "${permission_baseline_pids[$index]}" == "$1" &&
              "${permission_baseline_executables[$index]}" == "$observed_permission_executable" &&
              "${permission_baseline_commands[$index]}" == "$observed_permission_command" &&
              "${permission_baseline_starts[$index]}" == "$observed_permission_start" &&
              "${permission_baseline_inodes[$index]}" == "$observed_permission_inode" ]]; then
            return 0
        fi
        index=$(( index + 1 ))
    done
    return 1
}

permission_registry_index() {
    local child_pid="$1"
    local index=1
    while (( index <= ${#permission_registry_pids} )); do
        if [[ "${permission_registry_pids[$index]}" == "$child_pid" ]]; then
            REPLY="$index"
            return 0
        fi
        index=$(( index + 1 ))
    done
    return 1
}

permission_topology_for_observed() {
    local child_pid="$1"
    local parent_pid="$observed_permission_ppid"
    local deadline="$2"
    if [[ "$parent_pid" == "$permission_app_pid" ]]; then
        REPLY="descendant"
        return 0
    fi
    if [[ "$parent_pid" == "$$" ]]; then
        REPLY="script-sibling"
        return 0
    fi
    if [[ "$parent_pid" == 0 || "$parent_pid" == 1 ]]; then
        REPLY="reparented-unknown"
        return 0
    fi
    local ancestor="$parent_pid"
    local depth=0
    local next_parent
    while [[ "$ancestor" == <-> ]] && (( ancestor > 1 && depth < 16 )); do
        permission_timeout_cap "$deadline" 2 || return 1
        next_parent=$(timeout_command "$REPLY" ps -p "$ancestor" -o ppid= |
            tr -d '[:space:]') || {
            REPLY="reparented-unknown"
            return 0
        }
        if [[ "$ancestor" == "$permission_app_pid" || "$next_parent" == "$permission_app_pid" ]]; then
            REPLY="descendant"
            return 0
        fi
        if [[ "$ancestor" == "$$" || "$next_parent" == "$$" ]]; then
            REPLY="script-sibling"
            return 0
        fi
        [[ "$next_parent" == <-> ]] || {
            REPLY="reparented-unknown"
            return 0
        }
        ancestor="$next_parent"
        depth=$(( depth + 1 ))
    done
    REPLY="external-parent"
}

register_permission_process() {
    local child_pid="$1"
    local role="$2"
    local topology="$3"
    permission_registry_pids+=("$child_pid")
    permission_registry_ppids+=("$observed_permission_ppid")
    permission_registry_executables+=("$observed_permission_executable")
    permission_registry_commands+=("$observed_permission_command")
    permission_registry_starts+=("$observed_permission_start")
    permission_registry_inodes+=("$observed_permission_inode")
    permission_registry_roles+=("$role")
    permission_registry_topologies+=("$topology")
    print -u2 -r -- "camera_permission_process=observed role=$role topology=$topology"
}

capture_permission_baseline() {
    local deadline="$1"
    discover_permission_candidate_pids "$deadline" || return 1
    local candidate_pids="$REPLY"
    local candidate_pid
    for candidate_pid in ${(f)candidate_pids}; do
        [[ "$candidate_pid" == <-> ]] || return 1
        if ! read_permission_identity "$candidate_pid" "$deadline"; then
            set +e
            permission_process_is_active "$candidate_pid" "$deadline"
            local activity_status=$?
            set -e
            (( activity_status == 0 || activity_status == 2 )) && return 1
            continue
        fi
        permission_identity_is_target || continue
        permission_baseline_pids+=("$candidate_pid")
        permission_baseline_executables+=("$observed_permission_executable")
        permission_baseline_commands+=("$observed_permission_command")
        permission_baseline_starts+=("$observed_permission_start")
        permission_baseline_inodes+=("$observed_permission_inode")
    done
}

capture_permission_identity() {
    local child_pid="$permission_app_pid"
    local deadline="$1"
    local capture_deadline=$(( SECONDS + 5 ))
    (( capture_deadline < deadline )) || capture_deadline="$deadline"
    while (( SECONDS < capture_deadline )); do
        if read_permission_identity "$child_pid" "$capture_deadline" &&
            permission_identity_is_target &&
            [[ "$observed_permission_ppid" == "$$" ]] &&
            permission_marker_matches "$child_pid" "$capture_deadline"; then
            permission_app_ppid="$observed_permission_ppid"
            permission_app_executable="$observed_permission_executable"
            permission_app_command="$observed_permission_command"
            permission_app_start="$observed_permission_start"
            register_permission_process "$child_pid" "direct" "script-sibling"
            return 0
        fi
        kill -0 "$child_pid" 2>/dev/null || return 1
        permission_sleep "$capture_deadline" || return 1
    done
    return 1
}

permission_identity_matches_index() {
    local index="$1"
    local deadline="$2"
    local child_pid="${permission_registry_pids[$index]}"
    if ! read_permission_identity "$child_pid" "$deadline"; then
        set +e
        permission_process_is_active "$child_pid" "$deadline"
        local activity_status=$?
        set -e
        (( activity_status == 1 )) && return 2
        return 1
    fi
    [[ "$observed_permission_executable" == "${permission_registry_executables[$index]}" &&
       "$observed_permission_command" == "${permission_registry_commands[$index]}" &&
       "$observed_permission_start" == "${permission_registry_starts[$index]}" &&
       "$observed_permission_inode" == "${permission_registry_inodes[$index]}" ]] || return 1
    permission_marker_matches "$child_pid" "$deadline" || return 1
}

mark_permission_uncertain() {
    permission_supervision_uncertain=1
    permission_preserve_root=1
    permission_quiet_rescan_complete=0
}

fail_permission_scan() {
    local deadline="$1"
    (( SECONDS >= deadline )) || mark_permission_uncertain
    return 1
}

scan_permission_processes() {
    local deadline="$1"
    discover_permission_candidate_pids "$deadline" || {
        fail_permission_scan "$deadline"
        return $?
    }
    local candidate_pids="$REPLY"
    local candidate_pid
    local topology
    local index
    for candidate_pid in ${(f)candidate_pids}; do
        [[ "$candidate_pid" == <-> ]] || {
            fail_permission_scan "$deadline"
            return $?
        }
        if ! read_permission_identity "$candidate_pid" "$deadline"; then
            set +e
            permission_process_is_active "$candidate_pid" "$deadline"
            local activity_status=$?
            set -e
            if (( activity_status == 0 || activity_status == 2 )); then
                fail_permission_scan "$deadline"
                return $?
            fi
            continue
        fi
        permission_identity_is_target || continue
        permission_baseline_contains_observed "$candidate_pid" && continue
        if permission_registry_index "$candidate_pid"; then
            index="$REPLY"
            if ! permission_identity_matches_index "$index" "$deadline"; then
                local match_status=$?
                (( match_status == 2 )) && continue
                fail_permission_scan "$deadline"
                return $?
            fi
            continue
        fi
        if ! permission_marker_matches "$candidate_pid" "$deadline"; then
            fail_permission_scan "$deadline"
            return $?
        fi
        permission_topology_for_observed "$candidate_pid" "$deadline" || {
            fail_permission_scan "$deadline"
            return $?
        }
        topology="$REPLY"
        register_permission_process "$candidate_pid" "additional" "$topology"
    done
}

permission_registry_has_active_process() {
    local deadline="$1"
    local child_pid
    local activity_status
    for child_pid in "${permission_registry_pids[@]}"; do
        set +e
        permission_process_is_active "$child_pid" "$deadline"
        activity_status=$?
        set -e
        (( activity_status == 0 )) && return 0
        if (( activity_status == 2 )); then
            (( SECONDS >= deadline )) || mark_permission_uncertain
            return 0
        fi
    done
    return 1
}

reap_permission_app() {
    local child_pid="$permission_app_pid"
    local deadline="$1"
    [[ "$child_pid" == <-> ]] || return 0
    permission_timeout_cap "$deadline" 1 || return 1
    kill -0 "$child_pid" 2>/dev/null && return 1
    local child_status=0
    set +e
    wait "$child_pid"
    child_status=$?
    set -e
    permission_app_exit_status="$child_status"
    permission_app_pid=""
    (( SECONDS <= deadline ))
}

wait_for_permission_exit() {
    local deadline="$1"
    local maximum_seconds="$2"
    local phase_deadline=$(( SECONDS + maximum_seconds ))
    (( phase_deadline < deadline )) || phase_deadline="$deadline"
    while true; do
        permission_timeout_cap "$phase_deadline" 1 || return 1
        scan_permission_processes "$phase_deadline" || return 1
        if ! permission_registry_has_active_process "$phase_deadline"; then
            permission_sleep "$phase_deadline" || return 1
            scan_permission_processes "$phase_deadline" || return 1
            if ! permission_registry_has_active_process "$phase_deadline"; then
                permission_quiet_rescan_complete=1
                return 0
            fi
        fi
        permission_sleep "$phase_deadline" || return 1
    done
}

permission_quiet_rescan() {
    local deadline="$1"
    permission_quiet_rescan_complete=0
    scan_permission_processes "$deadline" || return 1
    permission_registry_has_active_process "$deadline" && return 1
    permission_sleep "$deadline" || return 1
    scan_permission_processes "$deadline" || return 1
    permission_registry_has_active_process "$deadline" && return 1
    permission_quiet_rescan_complete=1
}

signal_permission_processes() {
    local signal_name="$1"
    local deadline="$2"
    scan_permission_processes "$deadline" || return 1
    local -a active_indexes=()
    local index=1
    local match_status
    while (( index <= ${#permission_registry_pids} )); do
        set +e
        permission_process_is_active "${permission_registry_pids[$index]}" "$deadline"
        local activity_status=$?
        set -e
        if (( activity_status == 2 )); then
            mark_permission_uncertain
            return 1
        fi
        if (( activity_status == 0 )); then
            set +e
            permission_identity_matches_index "$index" "$deadline"
            match_status=$?
            set -e
            if (( match_status == 1 )); then
                mark_permission_uncertain
                return 1
            fi
            (( match_status == 0 )) && active_indexes+=("$index")
        fi
        index=$(( index + 1 ))
    done
    for index in "${active_indexes[@]}"; do
        set +e
        permission_identity_matches_index "$index" "$deadline"
        match_status=$?
        set -e
        if (( match_status == 1 )); then
            mark_permission_uncertain
            return 1
        fi
        (( match_status == 2 )) && continue
        permission_timeout_cap "$deadline" 1 || return 1
        kill -"$signal_name" "${permission_registry_pids[$index]}" 2>/dev/null || true
    done
}

terminate_permission_processes() {
    local deadline="$1"
    permission_timeout_cap "$deadline" 1 || {
        mark_permission_uncertain
        print -u2 -r -- "cleanup refused: Camera permission deadline expired"
        return 1
    }
    signal_permission_processes TERM "$deadline" || {
        print -u2 -r -- "cleanup refused: Camera permission process identity is uncertain"
        return 1
    }
    wait_for_permission_exit "$deadline" 5 || true
    if permission_registry_has_active_process "$deadline"; then
        signal_permission_processes KILL "$deadline" || {
            print -u2 -r -- "cleanup refused: Camera permission process identity changed before KILL"
            return 1
        }
        wait_for_permission_exit "$deadline" 1 || return 1
    fi
    permission_quiet_rescan "$deadline" || return 1
    reap_permission_app "$deadline"
}

permission_terminal_observed() {
    local deadline="$1"
    permission_timeout_cap "$deadline" 2 || return 1
    timeout_command "$REPLY" grep -Eq \
        '^dev_vlogs_phase_0b result=(ready|failed|timed_out|cancelled) category=' \
        "$permission_operator_log" || return 1
    local event_log
    for event_log in "$resolved_run_root"/dv-p0b-camera-authorization-*/evidence/events.jsonl(N); do
        permission_timeout_cap "$deadline" 2 || return 1
        timeout_command "$REPLY" grep -Eq '"action":"camera_authorization_terminal"' \
            "$event_log" && return 0
    done
    return 1
}

cleanup() {
    local cleanup_status=0
    if [[ -n "$permission_deadline" &&
          ( "$permission_app_pid" == <-> || ${#permission_registry_pids} > 0 ) ]]; then
        if [[ -z "$permission_app_pid" && "$permission_quiet_rescan_complete" == 1 ]]; then
            :
        else
            terminate_permission_processes "$permission_deadline" || cleanup_status=1
        fi
    fi
    terminate_capture_supervisor
    (( cleanup_status == 0 )) || return 1
    (( permission_supervision_uncertain == 0 && permission_preserve_root == 0 )) || {
        print -u2 -r -- "cleanup retained: Camera permission process ownership was inconclusive"
        return 1
    }
    if [[ -n "$permission_deadline" ]]; then
        (( permission_quiet_rescan_complete == 1 )) || return 1
        [[ -z "$permission_app_pid" ]] || return 1
    fi
    if [[ "$resolved_run_root" != "$resolved_temp_root"/holdtype-dv-p0b.* ]]; then
        print -u2 -r -- "cleanup refused: run root did not match the exact temporary prefix"
        return 1
    fi
    if [[ -d "$resolved_run_root" ]]; then
        rm -rf -- "$resolved_run_root"
    fi
}
finish_cleanup() {
    local prior_status=$?
    trap - EXIT
    cleanup || prior_status=1
    exit "$prior_status"
}
trap finish_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$repository_root"
timeout_command "$build_timeout_seconds" xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    build

if [[ "$mode" == "--build-only" ]]; then
    print -r -- "build_only=pass hardware=not_run"
    exit 0
fi

build_settings=$(timeout_command "$build_timeout_seconds" xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    -showBuildSettings)
target_build_directory=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')
full_product_name=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')
app_binary="$target_build_directory/$full_product_name/Contents/MacOS/HoldType"
[[ -x "$app_binary" ]] || { print -u2 -r -- "error: Debug app binary is unavailable"; exit 1; }
app_binary=${app_binary:A}

if [[ "$mode" == "--request-camera-permission" ]]; then
    if [[ -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS:-}" ]]; then
        [[ "$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS" == <-> ]] &&
            (( HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS >= 1 &&
               HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS <= 420 )) || {
            print -u2 -r -- "error: Camera permission timeout must be 1 through 420 seconds"
            exit 64
        }
        permission_timeout_seconds="$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS"
    fi
    sanitized_home="$resolved_run_root/home"
    mkdir -p -- "$sanitized_home"
    permission_operator_log="$resolved_run_root/permission-operator.log"
    permission_deadline=$(( SECONDS + permission_timeout_seconds ))
    permission_marker="HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT=$resolved_run_root"
    permission_timeout_cap "$permission_deadline" 2 || exit 124
    permission_app_inode=$(timeout_command "$REPLY" stat -f '%i' "$app_binary") || exit 1
    [[ "$permission_app_inode" == <-> ]] || exit 1
    capture_permission_baseline "$permission_deadline" || {
        print -u2 -r -- "error: Camera permission process baseline was inconclusive"
        permission_preserve_root=1
        exit 1
    }
    env \
        -u HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS \
        -u OPENAI_API_KEY \
        -u HOLDTYPE_DEBUG_API_KEY_FILE \
        HOME="$sanitized_home" \
        HOLDTYPE_AUTOMATION=1 \
        HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_REQUEST_CAMERA_PERMISSION=1 \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID="camera-authorization" \
        "$app_binary" >"$permission_operator_log" 2>&1 &
    permission_app_pid=$!
    capture_permission_identity "$permission_deadline" || {
        print -u2 -r -- "error: Camera permission process identity could not be established"
        exit 1
    }
    scan_permission_processes "$permission_deadline" || {
        print -u2 -r -- "error: Camera permission process ownership was inconclusive"
        exit 1
    }
    while ! permission_terminal_observed "$permission_deadline"; do
        scan_permission_processes "$permission_deadline" || {
            print -u2 -r -- "error: Camera permission process ownership was inconclusive"
            exit 1
        }
        if ! kill -0 "$permission_app_pid" 2>/dev/null; then
            reap_permission_app "$permission_deadline" || true
            print -u2 -r -- "error: Camera permission process exited before terminal evidence"
            exit 1
        fi
        (( SECONDS < permission_deadline )) || {
            print -u2 -r -- "error: Camera permission request exceeded its bounded deadline"
            exit 124
        }
        permission_sleep "$permission_deadline" || exit 124
    done
    if ! wait_for_permission_exit "$permission_deadline" 5; then
        print -u2 -r -- "error: Camera permission processes did not exit naturally"
        terminate_permission_processes "$permission_deadline" || true
        exit 1
    fi
    permission_quiet_rescan "$permission_deadline" || {
        print -u2 -r -- "error: Camera permission process set did not become quiet"
        terminate_permission_processes "$permission_deadline" || true
        exit 1
    }
    reap_permission_app "$permission_deadline" || exit 124
    (( permission_app_exit_status == 0 )) || exit "$permission_app_exit_status"
    permission_timeout_cap "$permission_deadline" 2 || exit 124
    timeout_command "$REPLY" grep -E '^dev_vlogs_phase_0b result=' "$permission_operator_log"
    print -r -- "camera_permission_request=terminal capture=not_run microphone=not_run"
    exit 0
fi

hardware_timeout_seconds=$(( capture_duration + 300 ))
"$timeout_executable" --signal=TERM --kill-after=5s "$hardware_timeout_seconds" env \
    HOLDTYPE_AUTOMATION=1 \
    HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
    HOLDTYPE_DEV_VLOGS_PHASE_0B=1 \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_CAMERA_ID="$camera_id" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_DURATION="$capture_duration" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID="$case_id" \
    "$app_binary" &
capture_supervisor_pid=$!
set +e
wait "$capture_supervisor_pid"
capture_status=$?
set -e
capture_supervisor_pid=""
(( capture_status == 0 )) || exit "$capture_status"

print -r -- "hardware_run=terminal raw_media_cleanup=scheduled"
