#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}
program_name="$0"
mode="${1:---help}"
build_timeout_seconds=600
camera_id=""
capture_duration=10
case_id="capture"
permission_timeout_seconds=420
permission_cleanup_reserve_seconds=11
timeout_executable=""
capture_supervisor_pid=""
permission_app_pid=""
permission_app_ppid=""
permission_app_executable=""
permission_app_command=""
permission_app_start=""
permission_operator_log=""
observed_permission_ppid=""
observed_permission_executable=""
observed_permission_command=""
observed_permission_start=""

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

read_permission_identity() {
    local child_pid="$1"
    observed_permission_ppid=$(timeout_command 2 ps -p "$child_pid" -o ppid= | tr -d '[:space:]') || return 1
    observed_permission_executable=$(timeout_command 2 lsof -a -p "$child_pid" -d txt -Fn 2>/dev/null |
        awk '/^n/ { print substr($0, 2); exit }') || return 1
    observed_permission_command=$(timeout_command 2 ps -ww -p "$child_pid" -o command= |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    observed_permission_start=$(timeout_command 2 ps -p "$child_pid" -o lstart= |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    [[ -n "$observed_permission_ppid" && -n "$observed_permission_executable" &&
        -n "$observed_permission_command" && -n "$observed_permission_start" ]]
}

capture_permission_identity() {
    local child_pid="$permission_app_pid"
    local checks_remaining=50
    while (( checks_remaining > 0 )); do
        if read_permission_identity "$child_pid" &&
            [[ "$observed_permission_ppid" == "$$" &&
               "$observed_permission_executable" == "$app_binary" &&
               "$observed_permission_command" == "$app_binary" ]]; then
            permission_app_ppid="$observed_permission_ppid"
            permission_app_executable="$observed_permission_executable"
            permission_app_command="$observed_permission_command"
            permission_app_start="$observed_permission_start"
            return 0
        fi
        sleep 0.1
        checks_remaining=$(( checks_remaining - 1 ))
    done
    return 1
}

permission_identity_matches() {
    local child_pid="$permission_app_pid"
    [[ "$child_pid" == <-> ]] || return 1
    read_permission_identity "$child_pid" || return 1
    [[ "$observed_permission_ppid" == "$permission_app_ppid" &&
       "$observed_permission_executable" == "$permission_app_executable" &&
       "$observed_permission_command" == "$permission_app_command" &&
       "$observed_permission_start" == "$permission_app_start" ]]
}

reap_permission_app() {
    local child_pid="$permission_app_pid"
    [[ "$child_pid" == <-> ]] || return 0
    local child_status=0
    set +e
    wait "$child_pid"
    child_status=$?
    set -e
    permission_app_pid=""
    return "$child_status"
}

terminate_permission_app() {
    local child_pid="$permission_app_pid"
    [[ "$child_pid" == <-> ]] || return 0
    if ! kill -0 "$child_pid" 2>/dev/null; then
        reap_permission_app || true
        return 0
    fi
    permission_identity_matches || {
        print -u2 -r -- "cleanup refused: Camera permission process identity changed"
        return 1
    }
    kill -TERM "$child_pid" 2>/dev/null || true
    local checks_remaining=50
    while kill -0 "$child_pid" 2>/dev/null && (( checks_remaining > 0 )); do
        sleep 0.1
        checks_remaining=$(( checks_remaining - 1 ))
    done
    if kill -0 "$child_pid" 2>/dev/null; then
        permission_identity_matches || {
            print -u2 -r -- "cleanup refused: Camera permission process identity changed before KILL"
            return 1
        }
        kill -KILL "$child_pid" 2>/dev/null || true
        checks_remaining=10
        while kill -0 "$child_pid" 2>/dev/null && (( checks_remaining > 0 )); do
            sleep 0.1
            checks_remaining=$(( checks_remaining - 1 ))
        done
        kill -0 "$child_pid" 2>/dev/null && return 1
    fi
    reap_permission_app || true
}

permission_terminal_observed() {
    grep -Eq '^dev_vlogs_phase_0b result=(ready|failed|timed_out|cancelled) category=' \
        "$permission_operator_log" || return 1
    local event_log
    for event_log in "$resolved_run_root"/dv-p0b-camera-authorization-*/evidence/events.jsonl(N); do
        grep -Eq '"action":"camera_authorization_terminal"' "$event_log" && return 0
    done
    return 1
}

cleanup() {
    local cleanup_status=0
    terminate_permission_app || cleanup_status=1
    terminate_capture_supervisor
    (( cleanup_status == 0 )) || return 1
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

if [[ "$mode" == "--request-camera-permission" ]]; then
    sanitized_home="$resolved_run_root/home"
    mkdir -p -- "$sanitized_home"
    permission_operator_log="$resolved_run_root/permission-operator.log"
    env \
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
    permission_deadline=$(( SECONDS + permission_timeout_seconds ))
    permission_terminal_deadline=$(( permission_deadline - permission_cleanup_reserve_seconds ))
    capture_permission_identity || {
        print -u2 -r -- "error: Camera permission process identity could not be established"
        exit 1
    }
    while ! permission_terminal_observed; do
        if ! kill -0 "$permission_app_pid" 2>/dev/null; then
            reap_permission_app || true
            print -u2 -r -- "error: Camera permission process exited before terminal evidence"
            exit 1
        fi
        (( SECONDS < permission_terminal_deadline )) || {
            print -u2 -r -- "error: Camera permission request exceeded its bounded deadline"
            exit 124
        }
        sleep 0.1
    done
    natural_exit_checks=50
    while kill -0 "$permission_app_pid" 2>/dev/null && (( natural_exit_checks > 0 )); do
        sleep 0.1
        natural_exit_checks=$(( natural_exit_checks - 1 ))
    done
    if kill -0 "$permission_app_pid" 2>/dev/null; then
        print -u2 -r -- "error: Camera permission process did not exit naturally"
        terminate_permission_app || true
        exit 1
    fi
    reap_permission_app
    grep -E '^dev_vlogs_phase_0b result=' "$permission_operator_log"
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
