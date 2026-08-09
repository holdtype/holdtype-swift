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
permission_cleanup_process_seconds=6
permission_cleanup_root_probe_seconds=1
permission_cleanup_sensitive_delete_seconds=1
permission_cleanup_root_delete_seconds=2
permission_cleanup_reserve_seconds=$((
    permission_cleanup_process_seconds +
    permission_cleanup_root_probe_seconds +
    permission_cleanup_sensitive_delete_seconds +
    permission_cleanup_root_probe_seconds +
    permission_cleanup_root_delete_seconds
))
timeout_executable=""
capture_supervisor_pid=""
permission_app_pid=""
permission_helper_pid=""
permission_helper_executable=""
permission_helper_command=""
permission_helper_start=""
permission_helper_inode=""
permission_deadline=""
permission_work_deadline=""
permission_app_exit_status=""
permission_app_ppid=""
permission_app_executable=""
permission_app_command=""
permission_app_start=""
permission_app_inode=""
permission_operator_log=""
permission_marker=""
permission_launch_token=""
permission_launcher_result=""
permission_acknowledgment=""
permission_acknowledgment_temporary=""
permission_supervision_uncertain=0
permission_preserve_root=0
permission_quiet_rescan_complete=0
permission_supervision_started=0
permission_cleanup_active=0
permission_result_category=""
permission_result_bundle=""
permission_result_executable=""
permission_result_identifier=""
permission_result_digest=""
permission_root_parent=""
permission_root_name=""
permission_parent_identity=""
permission_root_identity=""
permission_root_guard_executable="/usr/bin/python3"
permission_root_guard_test_action=""
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
    if [[ "$permission_cleanup_active" == 1 ]]; then
        permission_hard_timeout_command "$@"
        return
    fi
    "$timeout_executable" "$@"
}

permission_hard_timeout_command() {
    local -F 6 total_seconds="$1"
    shift
    (( total_seconds >= 0.200000 )) || return 125
    local -F 6 kill_seconds=$(( total_seconds / 4.0 ))
    (( kill_seconds >= 0.050000 )) || kill_seconds=0.050000
    local -F 6 verify_seconds=$(( total_seconds / 4.0 ))
    (( verify_seconds >= 0.050000 )) || verify_seconds=0.050000
    local -F 6 term_seconds=$(( total_seconds - kill_seconds - verify_seconds ))
    (( term_seconds >= 0.050000 )) || return 125
    local term_text kill_text
    printf -v term_text '%.6fs' "$term_seconds"
    printf -v kill_text '%.6fs' "$kill_seconds"
    local -F 6 started_at="$SECONDS"
    "$timeout_executable" --signal=TERM --kill-after="$kill_text" "$term_text" "$@" &
    local timeout_pid=$!
    local result=0
    wait "$timeout_pid" || result=$?
    local -F 6 verification_deadline=$(( started_at + total_seconds ))
    zmodload zsh/zselect
    while kill -0 -- "-$timeout_pid" 2>/dev/null; do
        (( SECONDS < verification_deadline )) || {
            kill -KILL -- "-$timeout_pid" 2>/dev/null || true
            return 125
        }
        kill -KILL -- "-$timeout_pid" 2>/dev/null || true
        zselect -t 1 2>/dev/null || true
    done
    (( result == 137 )) && return 124
    return "$result"
}

permission_root_guard_source=""
read -r -d '' permission_root_guard_source <<'PY' || true
import ctypes
import os
import re
import secrets
import signal
import stat
import sys
import time

O_DIRECTORY = getattr(os, "O_DIRECTORY", 0)
O_NOFOLLOW = getattr(os, "O_NOFOLLOW", 0)
OPEN_DIRECTORY = os.O_RDONLY | O_DIRECTORY | O_NOFOLLOW
RENAME_EXCL = 0x00000004
SENSITIVE = re.compile(r"(?:camera-authorization-launch\.json|camera-authorization-ack\.json|permission-launcher\.log|\.camera-authorization-ack\.[A-Za-z0-9]+)")

def identity(value):
    return (value.st_dev, value.st_ino, value.st_uid, stat.S_IMODE(value.st_mode))

def expected(name):
    parts = os.environ[name].split(":")
    if len(parts) != 4 or any(not part.isdigit() for part in parts):
        raise ValueError("identity")
    return tuple(int(part) for part in parts)

def open_parent(path, wanted=None):
    descriptor = os.open(path, OPEN_DIRECTORY)
    value = os.fstat(descriptor)
    if not stat.S_ISDIR(value.st_mode) or (wanted is not None and identity(value) != wanted):
        os.close(descriptor)
        raise ValueError("parent")
    return descriptor, value

def open_root(parent, name, wanted=None):
    descriptor = os.open(name, OPEN_DIRECTORY, dir_fd=parent)
    value = os.fstat(descriptor)
    if not stat.S_ISDIR(value.st_mode) or (wanted is not None and identity(value) != wanted):
        os.close(descriptor)
        raise ValueError("root")
    return descriptor, value

def sensitive_names():
    raw = os.environ.get("DV_ROOT_SENSITIVE", "")
    values = [value for value in raw.split(":") if value]
    if len(values) > 4 or len(values) != len(set(values)):
        raise ValueError("sensitive")
    if any(SENSITIVE.fullmatch(value) is None for value in values):
        raise ValueError("sensitive")
    return values

def scrub(root, names):
    for name in names:
        try:
            value = os.stat(name, dir_fd=root, follow_symlinks=False)
        except FileNotFoundError:
            continue
        if (not stat.S_ISREG(value.st_mode) or value.st_uid != os.getuid() or
                stat.S_IMODE(value.st_mode) != 0o600 or value.st_nlink != 1):
            raise ValueError("sensitive")
        os.unlink(name, dir_fd=root)
    for name in names:
        try:
            os.stat(name, dir_fd=root, follow_symlinks=False)
        except FileNotFoundError:
            continue
        raise ValueError("sensitive")

def remove_contents(directory, top_level=False, test_action=""):
    with os.scandir(directory) as entries:
        names = [entry.name for entry in entries]
    for name in names:
        if top_level:
            allowed = (name in {"home", "camera-authorization-launcher"} or
                       SENSITIVE.fullmatch(name) is not None or
                       re.fullmatch(r"dv-p0b-camera-authorization-[A-Za-z0-9-]+", name) is not None or
                       (test_action == "timeout_fixture" and
                        re.fullmatch(r"timeout-(?:worker|parent-[1-3]|child-[1-3])", name) is not None))
            if not allowed:
                raise ValueError("name")
        value = os.stat(name, dir_fd=directory, follow_symlinks=False)
        if value.st_uid != os.getuid() or stat.S_IMODE(value.st_mode) & 0o022:
            raise ValueError("ownership")
        if stat.S_ISDIR(value.st_mode):
            child = os.open(name, OPEN_DIRECTORY, dir_fd=directory)
            try:
                if identity(os.fstat(child)) != identity(value):
                    raise ValueError("replacement")
                remove_contents(child)
            finally:
                os.close(child)
            os.rmdir(name, dir_fd=directory)
        elif stat.S_ISREG(value.st_mode) and value.st_nlink == 1:
            os.unlink(name, dir_fd=directory)
        else:
            raise ValueError("type")

def rename_exclusive(parent, source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    call = libc.renameatx_np
    call.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    call.restype = ctypes.c_int
    result = call(parent, os.fsencode(source), parent, os.fsencode(destination), RENAME_EXCL)
    if result != 0:
        raise OSError(ctypes.get_errno(), "rename")

def path_identity(parent, name):
    try:
        return identity(os.stat(name, dir_fd=parent, follow_symlinks=False))
    except FileNotFoundError:
        return None

def capture():
    parent_path = os.environ["DV_ROOT_PARENT"]
    root_name = os.environ["DV_ROOT_NAME"]
    if "/" in root_name or not root_name.startswith("holdtype-dv-p0b."):
        raise ValueError("name")
    parent, parent_value = open_parent(parent_path)
    try:
        root, root_value = open_root(parent, root_name)
        try:
            if root_value.st_uid != os.getuid() or stat.S_IMODE(root_value.st_mode) != 0o700:
                raise ValueError("mode")
            print(":".join(str(value) for value in identity(parent_value) + identity(root_value)))
        finally:
            os.close(root)
    finally:
        os.close(parent)

def cleanup(action):
    parent_path = os.environ["DV_ROOT_PARENT"]
    root_name = os.environ["DV_ROOT_NAME"]
    parent_wanted = expected("DV_ROOT_PARENT_IDENTITY")
    root_wanted = expected("DV_ROOT_IDENTITY")
    test_action = os.environ.get("DV_ROOT_TEST_ACTION", "")
    if test_action == "parent_replaced":
        grand_path, parent_leaf = os.path.split(parent_path)
        grand, _ = open_parent(grand_path)
        try:
            current, _ = open_root(grand, parent_leaf, parent_wanted)
            os.close(current)
            rename_exclusive(grand, parent_leaf, parent_leaf + ".original-test")
            os.mkdir(parent_leaf, 0o700, dir_fd=grand)
        finally:
            os.close(grand)
    parent, _ = open_parent(parent_path, parent_wanted)
    try:
        if test_action in ("root_symlink", "root_replaced"):
            preserved = ".dv-p0b-original-test"
            rename_exclusive(parent, root_name, preserved)
            if test_action == "root_symlink":
                target = ".dv-p0b-sibling-test"
                os.mkdir(target, 0o700, dir_fd=parent)
                os.symlink(target, root_name, dir_fd=parent)
            else:
                os.mkdir(root_name, 0o700, dir_fd=parent)
        root, _ = open_root(parent, root_name, root_wanted)
        try:
            if test_action == "scrub_timeout":
                signal.signal(signal.SIGTERM, signal.SIG_IGN)
                time.sleep(10)
            if test_action == "scrub_failure":
                raise ValueError("test")
            if test_action == "swap_after_open":
                preserved = ".dv-p0b-original-test"
                rename_exclusive(parent, root_name, preserved)
                os.mkdir(root_name, 0o700, dir_fd=parent)
            names = sensitive_names()
            if test_action in ("sensitive_symlink", "sensitive_hardlink", "sensitive_type"):
                name = names[0]
                try:
                    os.unlink(name, dir_fd=root)
                except FileNotFoundError:
                    pass
                if test_action == "sensitive_symlink":
                    os.symlink("permission-launcher.log", name, dir_fd=root)
                elif test_action == "sensitive_hardlink":
                    os.link("permission-launcher.log", name, src_dir_fd=root, dst_dir_fd=root)
                else:
                    os.mkdir(name, 0o700, dir_fd=root)
            scrub(root, names)
            if action == "remove" and test_action == "unexpected_name":
                descriptor = os.open("unexpected-private", os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                                     0o600, dir_fd=root)
                os.close(descriptor)
        finally:
            os.close(root)
        if action == "retain":
            check, _ = open_root(parent, root_name, root_wanted)
            os.close(check)
            print("root_guard=scrubbed_retained")
            return
        if test_action == "remove_timeout":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            time.sleep(10)
        if test_action == "remove_failure":
            raise ValueError("test")
        tombstone = (".dv-p0b-cleanup-collision" if test_action == "tombstone_collision"
                     else ".dv-p0b-cleanup-" + secrets.token_hex(12))
        if test_action == "tombstone_collision":
            os.mkdir(tombstone, 0o700, dir_fd=parent)
        rename_exclusive(parent, root_name, tombstone)
        if test_action == "post_rename_mismatch":
            rename_exclusive(parent, tombstone, ".dv-p0b-original-test")
            os.mkdir(tombstone, 0o700, dir_fd=parent)
        tombstone_identity = path_identity(parent, tombstone)
        if tombstone_identity != root_wanted:
            if path_identity(parent, root_name) is None:
                try:
                    rename_exclusive(parent, tombstone, root_name)
                except OSError:
                    pass
            raise ValueError("quarantine")
        tombstone_fd, _ = open_root(parent, tombstone, root_wanted)
        try:
            remove_contents(tombstone_fd, True, test_action)
        finally:
            os.close(tombstone_fd)
        os.rmdir(tombstone, dir_fd=parent)
        if path_identity(parent, tombstone) is not None or path_identity(parent, root_name) is not None:
            raise ValueError("residual")
        print("root_guard=removed")
    finally:
        os.close(parent)

try:
    operation = sys.argv[1]
    if operation == "capture":
        capture()
    elif operation in ("retain", "remove"):
        cleanup(operation)
    else:
        raise ValueError("operation")
except BaseException:
    os._exit(65)
PY

capture_permission_root_identity() {
    local capture
    local cap="$1"
    capture=$(permission_hard_timeout_command "$cap" env \
        DV_ROOT_PARENT="$permission_root_parent" \
        DV_ROOT_NAME="$permission_root_name" \
        "$permission_root_guard_executable" -c "$permission_root_guard_source" capture) || return 1
    local -a values=("${(@s.:.)capture}")
    (( ${#values} == 8 )) || return 1
    local value
    for value in "${values[@]}"; do
        [[ "$value" == <-> ]] || return 1
    done
    permission_parent_identity="${(j.:.)values[1,4]}"
    permission_root_identity="${(j.:.)values[5,8]}"
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

if [[ "$mode" == "--request-camera-permission" ]]; then
    if [[ -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS:-}" ]]; then
        [[ "$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS" == <-> ]] &&
            (( HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS >
                    permission_cleanup_reserve_seconds &&
               HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS <= 420 )) || exit 64
        permission_timeout_seconds="$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS"
    fi
fi
run_root=$(mktemp -d "${TMPDIR%/}/holdtype-dv-p0b.XXXXXX")
resolved_temp_root=${TMPDIR:A}
resolved_run_root=${run_root:A}
if [[ "$mode" == "--request-camera-permission" ]]; then
    permission_deadline=$(( SECONDS + permission_timeout_seconds ))
    permission_work_deadline=$(( permission_deadline - permission_cleanup_reserve_seconds ))
    permission_root_parent="$resolved_temp_root"
    permission_root_name="${resolved_run_root:t}"
    local_root_capture_cap=$(( permission_work_deadline - SECONDS ))
    (( local_root_capture_cap <= 2.0 )) || local_root_capture_cap=2.0
    (( local_root_capture_cap >= 0.2 )) &&
        capture_permission_root_identity "$local_root_capture_cap" || {
        print -u2 -r -- "cleanup failed: private Camera permission run-root identity unavailable"
        exit 70
    }
fi

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

begin_permission_deadline() {
    local total_seconds="$1"
    [[ -z "$permission_deadline" ]] || return 0
    permission_deadline=$(( SECONDS + total_seconds ))
    permission_work_deadline=$(( permission_deadline - permission_cleanup_reserve_seconds ))
    (( permission_work_deadline > SECONDS ))
}

permission_sleep() {
    local deadline="$1"
    permission_timeout_cap "$deadline" 1 || return 1
    local -F 6 sleep_seconds="$REPLY"
    (( sleep_seconds < 0.1 )) || sleep_seconds=0.1
    if [[ "$permission_cleanup_active" == 1 ]]; then
        permission_hard_timeout_command "$REPLY" sleep "$sleep_seconds" || return 1
    else
        sleep "$sleep_seconds"
    fi
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

capture_permission_helper_identity() {
    local deadline="$1"
    local child_pid="$permission_helper_pid"
    read_permission_identity "$child_pid" "$deadline" || return 1
    [[ "$observed_permission_ppid" == "$$" &&
       "$observed_permission_executable" == "$permission_helper_executable" &&
       "$observed_permission_inode" == "$permission_helper_inode" ]] || return 1
    permission_helper_command="$observed_permission_command"
    permission_helper_start="$observed_permission_start"
}

permission_helper_identity_matches() {
    local deadline="$1"
    local child_pid="$permission_helper_pid"
    [[ "$child_pid" == <-> ]] || return 2
    if ! read_permission_identity "$child_pid" "$deadline"; then
        kill -0 "$child_pid" 2>/dev/null || return 2
        return 1
    fi
    [[ "$observed_permission_executable" == "$permission_helper_executable" &&
       "$observed_permission_inode" == "$permission_helper_inode" &&
       "$observed_permission_command" == "$permission_helper_command" &&
       "$observed_permission_start" == "$permission_helper_start" ]]
}

signal_permission_helper() {
    local signal_name="$1"
    local deadline="$2"
    local match_status
    set +e
    permission_helper_identity_matches "$deadline"
    match_status=$?
    set -e
    (( match_status == 2 )) && return 0
    (( match_status == 0 )) || {
        mark_permission_uncertain
        return 1
    }
    permission_timeout_cap "$deadline" 1 || return 1
    kill -"$signal_name" "$permission_helper_pid" 2>/dev/null || true
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
    local child_pid="$permission_helper_pid"
    local deadline="$1"
    [[ "$child_pid" == <-> ]] || return 0
    permission_timeout_cap "$deadline" 1 || return 1
    set +e
    permission_process_is_active "$child_pid" "$deadline"
    local activity_status=$?
    set -e
    (( activity_status == 1 )) || return 1
    local child_status=0
    set +e
    wait "$child_pid"
    child_status=$?
    set -e
    permission_app_exit_status="$child_status"
    permission_helper_pid=""
    (( SECONDS <= deadline ))
}

wait_for_permission_helper_exit() {
    local deadline="$1"
    local phase_deadline=$(( SECONDS + 5 ))
    (( phase_deadline < deadline )) || phase_deadline="$deadline"
    while true; do
        set +e
        permission_process_is_active "$permission_helper_pid" "$phase_deadline"
        local activity_status=$?
        set -e
        (( activity_status == 1 )) && return 0
        (( activity_status == 0 )) || return 1
        permission_sleep "$phase_deadline" || return 1
    done
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
    signal_permission_helper TERM "$deadline" || {
        print -u2 -r -- "cleanup refused: Camera permission launcher identity is uncertain"
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
    if [[ "$permission_helper_pid" == <-> ]] && kill -0 "$permission_helper_pid" 2>/dev/null; then
        signal_permission_helper KILL "$deadline" || return 1
    fi
    permission_quiet_rescan "$deadline" || return 1
    reap_permission_app "$deadline"
}

permission_terminal_observed() {
    local deadline="$1"
    local event_log
    for event_log in "$resolved_run_root"/dv-p0b-camera-authorization-*/evidence/events.jsonl(N); do
        permission_timeout_cap "$deadline" 2 || return 1
        timeout_command "$REPLY" grep -Eq '"action":"camera_authorization_terminal"' \
            "$event_log" && return 0
    done
    return 1
}

parse_permission_verified_result() {
    local normalized="$1"
    permission_result_category=""
    permission_result_bundle=""
    permission_result_executable=""
    permission_result_identifier=""
    permission_result_digest=""
    [[ "$normalized" ==
        "category=launched bundle=true executable=true identifier=true digest=true" ]] || return 1
    permission_result_category="launched"
    permission_result_bundle="true"
    permission_result_executable="true"
    permission_result_identifier="true"
    permission_result_digest="true"
}

publish_permission_acknowledgment() {
    local expected_digest="$1"
    local deadline="$2"
    local temporary="$resolved_run_root/.camera-authorization-ack.$RANDOM"
    permission_acknowledgment_temporary="$temporary"
    permission_timeout_cap "$deadline" 1 || return 1
    umask 077
    set -o noclobber
    print -rn -- "{\"version\":1,\"token\":\"$permission_launch_token\",\"process_digest\":\"$expected_digest\"}" \
        > "$temporary" || { set +o noclobber; return 1; }
    set +o noclobber
    permission_timeout_cap "$deadline" 2 || return 1
    timeout_command "$REPLY" chmod 0600 "$temporary" || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    timeout_command "$REPLY" ln "$temporary" "$permission_acknowledgment" || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    timeout_command "$REPLY" rm -f -- "$temporary" || return 1
    permission_acknowledgment_temporary=""
}

run_permission_result_parser_self_test() {
    local scenario="${HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST:-}"
    [[ -n "$scenario" ]] || return 1
    [[ "$scenario" == valid || "$scenario" == extra_key || "$scenario" == wrong_digest ]] || exit 64
    [[ "$mode" == "--request-camera-permission" ]] || exit 64
    permission_timeout_seconds="${HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS:-20}"
    [[ "$permission_timeout_seconds" == <-> && "$permission_timeout_seconds" -le 30 ]] || exit 64
    begin_permission_deadline "$permission_timeout_seconds" || exit 124
    permission_launcher_result="$resolved_run_root/camera-authorization-launch.json"
    permission_acknowledgment="$resolved_run_root/camera-authorization-ack.json"
    permission_helper_executable="$resolved_run_root/camera-authorization-launcher"
    permission_launch_token=$(printf '%064d' 0)
    permission_app_pid="$$"
    permission_timeout_cap "$permission_work_deadline" "$permission_timeout_seconds" || exit 124
    timeout_command "$REPLY" xcrun swiftc -D DEBUG -parse-as-library \
        -framework AppKit -framework Foundation \
        "$repository_root/script/DevVlogsPhase0BCameraAuthorizationLauncher.swift" \
        -o "$permission_helper_executable"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    timeout_command "$REPLY" chmod 0700 "$resolved_run_root" "$permission_helper_executable"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    expected_process_digest=$(print -rn -- "$permission_launch_token:$permission_app_pid" |
        timeout_command "$REPLY" shasum -a 256 | awk '{ print $1 }')
    local extra=""
    local digest="$expected_process_digest"
    [[ "$scenario" == extra_key ]] && extra=',"private":"rejected"'
    [[ "$scenario" == wrong_digest ]] && digest=$(printf '%064d' 1)
    umask 077
    print -rn -- "{\"version\":1,\"category\":\"launched\",\"bundle_url_matches\":true," \
        "\"executable_url_matches\":true,\"bundle_identifier_matches\":true," \
        "\"launch_monotonic_ms\":1,\"process_digest\":\"$digest\"$extra}" \
        > "$permission_launcher_result"
    permission_timeout_cap "$permission_work_deadline" 5 || exit 124
    set +e
    verified_result=$(timeout_command "$REPLY" env \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN="$permission_launch_token" \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_EXPECTED_PID="$permission_app_pid" \
        "$permission_helper_executable" --verify-result)
    local verify_status=$?
    set -e
    if (( verify_status != 0 )) || ! parse_permission_verified_result "$verified_result"; then
        [[ ! -e "$permission_acknowledgment" ]] || exit 1
        print -r -- "permission_result_parser_test=rejected acknowledgment=absent"
        exit 65
    fi
    publish_permission_acknowledgment "$expected_process_digest" "$permission_work_deadline" || exit 1
    [[ -f "$permission_acknowledgment" ]] || exit 1
    print -r -- "permission_result_parser_test=pass acknowledgment=published"
    exit 0
}

run_permission_cleanup_self_test() {
    local scenario="${HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST:-}"
    case "$scenario" in
        cleanup_normal|cleanup_uncertain|cleanup_scrub_timeout|cleanup_scrub_failure|\
        cleanup_root_timeout|cleanup_root_failure|cleanup_deadline_expired|cleanup_term|cleanup_int|\
        cleanup_root_symlink|cleanup_root_replaced|cleanup_parent_replaced|cleanup_swap_after_open|\
        cleanup_tombstone_collision|cleanup_post_rename_mismatch|cleanup_sensitive_symlink|\
        cleanup_sensitive_hardlink|cleanup_sensitive_type|cleanup_unexpected_name|\
        cleanup_hard_timeout_matrix) ;;
        *) exit 64 ;;
    esac
    permission_timeout_seconds="${HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS:-14}"
    [[ "$permission_timeout_seconds" == <-> &&
        "$permission_timeout_seconds" -gt "$permission_cleanup_reserve_seconds" &&
        "$permission_timeout_seconds" -le 30 ]] || exit 64
    begin_permission_deadline "$permission_timeout_seconds" || exit 124
    permission_launcher_result="$resolved_run_root/camera-authorization-launch.json"
    permission_acknowledgment="$resolved_run_root/camera-authorization-ack.json"
    permission_acknowledgment_temporary="$resolved_run_root/.camera-authorization-ack.test"
    permission_operator_log="$resolved_run_root/permission-launcher.log"
    permission_launch_token=$(printf '%064d' 0)
    umask 077
    print -rn -- "$permission_launch_token" > "$permission_launcher_result"
    print -rn -- "$permission_launch_token" > "$permission_acknowledgment"
    print -rn -- "$permission_launch_token" > "$permission_acknowledgment_temporary"
    print -rn -- "$permission_launch_token" > "$permission_operator_log"

    case "$scenario" in
        cleanup_uncertain)
            permission_supervision_uncertain=1
            permission_preserve_root=1
            ;;
        cleanup_scrub_timeout) permission_root_guard_test_action="scrub_timeout" ;;
        cleanup_scrub_failure) permission_root_guard_test_action="scrub_failure" ;;
        cleanup_root_timeout) permission_root_guard_test_action="remove_timeout" ;;
        cleanup_root_failure) permission_root_guard_test_action="remove_failure" ;;
        cleanup_deadline_expired) permission_deadline="$SECONDS" ;;
        cleanup_root_symlink) permission_root_guard_test_action="root_symlink" ;;
        cleanup_root_replaced) permission_root_guard_test_action="root_replaced" ;;
        cleanup_parent_replaced) permission_root_guard_test_action="parent_replaced" ;;
        cleanup_swap_after_open) permission_root_guard_test_action="swap_after_open" ;;
        cleanup_tombstone_collision) permission_root_guard_test_action="tombstone_collision" ;;
        cleanup_post_rename_mismatch) permission_root_guard_test_action="post_rename_mismatch" ;;
        cleanup_sensitive_symlink) permission_root_guard_test_action="sensitive_symlink" ;;
        cleanup_sensitive_hardlink) permission_root_guard_test_action="sensitive_hardlink" ;;
        cleanup_sensitive_type) permission_root_guard_test_action="sensitive_type" ;;
        cleanup_unexpected_name) permission_root_guard_test_action="unexpected_name" ;;
        cleanup_hard_timeout_matrix)
            permission_root_guard_test_action="timeout_fixture"
            run_permission_hard_timeout_self_test
            exit 0
            ;;
    esac
    print -r -- "permission_cleanup_test=$scenario"
    case "$scenario" in
        cleanup_term) kill -TERM $$ ;;
        cleanup_int) kill -INT $$ ;;
        *) exit 0 ;;
    esac
}

run_permission_hard_timeout_self_test() {
    local worker="$resolved_run_root/timeout-worker"
    print -r -- '#!/bin/zsh' > "$worker"
    print -r -- 'trap "" TERM' >> "$worker"
    print -r -- 'print -r -- "$$" > "$1"' >> "$worker"
    print -r -- '( trap "" TERM; while true; do sleep 10; done ) &' >> "$worker"
    print -r -- 'print -r -- "$!" > "$2"' >> "$worker"
    print -r -- 'wait' >> "$worker"
    permission_timeout_cap "$permission_work_deadline" 1 || exit 124
    timeout_command "$REPLY" chmod 0700 "$worker" || exit 1
    local attempt parent_record child_record timeout_status=1
    for attempt in 1 2 3; do
        parent_record="$resolved_run_root/timeout-parent-$attempt"
        child_record="$resolved_run_root/timeout-child-$attempt"
        set +e
        permission_hard_timeout_command 1.000000 "$worker" "$parent_record" "$child_record"
        timeout_status=$?
        set -e
        (( timeout_status == 124 )) || {
            print -r -- "permission_hard_timeout_test=failed_timeout"
            exit 1
        }
        [[ -s "$parent_record" && -s "$child_record" ]] && break
    done
    [[ -s "$parent_record" && -s "$child_record" ]] || {
        print -r -- "permission_hard_timeout_test=failed_records"
        exit 1
    }
    [[ "$(<"$parent_record")" == <-> && "$(<"$child_record")" == <-> ]] || {
        print -r -- "permission_hard_timeout_test=failed_record"
        exit 1
    }
    permission_hard_timeout_command 0.500000 /usr/bin/true || {
        print -r -- "permission_hard_timeout_test=failed_normal"
        exit 1
    }
    local original_timeout="$timeout_executable"
    timeout_executable="/usr/bin/false"
    set +e
    permission_hard_timeout_command 0.500000 /usr/bin/true
    local wrapper_status=$?
    set -e
    timeout_executable="$original_timeout"
    (( wrapper_status != 0 && wrapper_status != 124 )) || {
        print -r -- "permission_hard_timeout_test=failed_wrapper"
        exit 1
    }
    print -r -- "permission_hard_timeout_test=pass"
}

permission_sensitive_names() {
    local -a names=()
    local artifact name
    for artifact in "$permission_launcher_result" "$permission_acknowledgment" \
        "$permission_acknowledgment_temporary" "$permission_operator_log"; do
        [[ -n "$artifact" ]] || continue
        [[ "${artifact:h}" == "$resolved_run_root" ]] || return 1
        name="${artifact:t}"
        [[ "$name" != *:* && "$name" != */* ]] || return 1
        names+=("$name")
    done
    REPLY="${(j.:.)names}"
}

permission_run_root_guard() {
    local operation="$1"
    local deadline="$2"
    local maximum_seconds="$3"
    [[ "$operation" == retain || "$operation" == remove ]] || return 1
    [[ -n "$permission_parent_identity" && -n "$permission_root_identity" ]] || return 1
    permission_sensitive_names || return 1
    local sensitive="$REPLY"
    permission_timeout_cap "$deadline" "$maximum_seconds" || return 1
    local output
    output=$(permission_hard_timeout_command "$REPLY" env \
        DV_ROOT_PARENT="$permission_root_parent" \
        DV_ROOT_NAME="$permission_root_name" \
        DV_ROOT_PARENT_IDENTITY="$permission_parent_identity" \
        DV_ROOT_IDENTITY="$permission_root_identity" \
        DV_ROOT_SENSITIVE="$sensitive" \
        DV_ROOT_TEST_ACTION="$permission_root_guard_test_action" \
        "$permission_root_guard_executable" -c "$permission_root_guard_source" "$operation") || return 1
    [[ "$output" == "root_guard=scrubbed_retained" && "$operation" == retain ||
       "$output" == "root_guard=removed" && "$operation" == remove ]] || return 1
}

permission_scrub_sensitive_artifacts() {
    local deadline="$1"
    permission_run_root_guard retain "$deadline" $((
        permission_cleanup_root_probe_seconds + permission_cleanup_sensitive_delete_seconds
    )) || return 1
    permission_launch_token=""
}

permission_remove_run_root() {
    local deadline="$1"
    permission_run_root_guard remove "$deadline" $((
        permission_cleanup_root_probe_seconds + permission_cleanup_root_delete_seconds
    ))
}

cleanup_permission_mode() {
    local cleanup_status=0
    permission_cleanup_active=1
    if [[ -n "$permission_deadline" &&
          ( "$permission_helper_pid" == <-> || ${#permission_registry_pids} > 0 ) ]]; then
        if [[ -z "$permission_helper_pid" && "$permission_quiet_rescan_complete" == 1 ]]; then
            :
        else
            local process_deadline=$(( SECONDS + permission_cleanup_process_seconds ))
            (( process_deadline < permission_deadline )) || process_deadline="$permission_deadline"
            terminate_permission_processes "$process_deadline" || {
                cleanup_status=1
                permission_preserve_root=1
            }
        fi
    fi
    permission_scrub_sensitive_artifacts "$permission_deadline" || {
        print -u2 -r -- "cleanup failed: sensitive Camera permission artifacts remain in a private run root"
        permission_preserve_root=1
        return 1
    }
    (( permission_supervision_uncertain == 0 && permission_preserve_root == 0 )) || {
        print -u2 -r -- "cleanup retained: Camera permission process ownership was inconclusive"
        return 1
    }
    (( cleanup_status == 0 )) || return 1
    if [[ "$permission_supervision_started" == 1 ]]; then
        (( permission_quiet_rescan_complete == 1 )) || return 1
        [[ -z "$permission_helper_pid" ]] || return 1
    fi
    permission_remove_run_root "$permission_deadline" || {
        print -u2 -r -- "cleanup failed: private Camera permission run root could not be removed"
        return 1
    }
}

cleanup_nonpermission_mode() {
    terminate_capture_supervisor
    if [[ "$resolved_run_root" == "$resolved_temp_root"/holdtype-dv-p0b.* && -d "$resolved_run_root" ]]; then
        rm -rf -- "$resolved_run_root"
    fi
}

cleanup() {
    if [[ "$mode" == "--request-camera-permission" ]]; then
        cleanup_permission_mode
    else
        cleanup_nonpermission_mode
    fi
}
finish_cleanup() {
    local prior_status=$?
    trap - EXIT
    cleanup || prior_status=70
    exit "$prior_status"
}
trap finish_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$mode" == "--request-camera-permission" ]]; then
    if [[ -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST:-}" ]]; then
        case "$HOLDTYPE_DEV_VLOGS_PHASE_0B_SCRIPT_RESULT_TEST" in
            valid|extra_key|wrong_digest) run_permission_result_parser_self_test ;;
            cleanup_*) run_permission_cleanup_self_test ;;
            *) exit 64 ;;
        esac
    fi
fi

cd "$repository_root"
current_build_timeout="$build_timeout_seconds"
if [[ "$mode" == "--request-camera-permission" ]]; then
    permission_timeout_cap "$permission_work_deadline" "$build_timeout_seconds" || exit 124
    current_build_timeout="$REPLY"
fi
timeout_command "$current_build_timeout" xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    build

if [[ "$mode" == "--build-only" ]]; then
    print -r -- "build_only=pass hardware=not_run"
    exit 0
fi

current_build_timeout="$build_timeout_seconds"
if [[ "$mode" == "--request-camera-permission" ]]; then
    permission_timeout_cap "$permission_work_deadline" "$build_timeout_seconds" || exit 124
    current_build_timeout="$REPLY"
fi
build_settings=$(timeout_command "$current_build_timeout" xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    -showBuildSettings)
target_build_directory=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')
full_product_name=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')
product_bundle_identifier=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }')
app_bundle="$target_build_directory/$full_product_name"
app_binary="$app_bundle/Contents/MacOS/HoldType"
[[ -x "$app_binary" ]] || { print -u2 -r -- "error: Debug app binary is unavailable"; exit 1; }
[[ -d "$app_bundle" && -n "$product_bundle_identifier" ]] || exit 1
app_bundle=${app_bundle:A}
app_binary=${app_binary:A}

if [[ "$mode" == "--request-camera-permission" ]]; then
    if [[ -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS:-}" ]]; then
        [[ "$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS" == <-> ]] &&
            (( HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS >
                    permission_cleanup_reserve_seconds &&
               HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS <= 420 )) || {
            print -u2 -r -- "error: Camera permission timeout must preserve the cleanup reserve and not exceed 420 seconds"
            exit 64
        }
        permission_timeout_seconds="$HOLDTYPE_DEV_VLOGS_PHASE_0B_PERMISSION_TIMEOUT_SECONDS"
    fi
    begin_permission_deadline "$permission_timeout_seconds" || exit 124
    umask 077
    sanitized_home="$resolved_run_root/home"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    timeout_command "$REPLY" mkdir -p -- "$sanitized_home" || exit 1
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    timeout_command "$REPLY" chmod 0700 "$resolved_run_root" "$sanitized_home" || exit 1
    permission_operator_log="$resolved_run_root/permission-launcher.log"
    permission_launcher_result="$resolved_run_root/camera-authorization-launch.json"
    permission_acknowledgment="$resolved_run_root/camera-authorization-ack.json"
    permission_helper_executable="$resolved_run_root/camera-authorization-launcher"
    permission_timeout_cap "$permission_work_deadline" "$permission_timeout_seconds" || exit 124
    timeout_command "$REPLY" xcrun swiftc -D DEBUG -parse-as-library \
        -framework AppKit -framework Foundation \
        "$repository_root/script/DevVlogsPhase0BCameraAuthorizationLauncher.swift" \
        -o "$permission_helper_executable"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    timeout_command "$REPLY" chmod 0700 "$permission_helper_executable" || exit 1
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    [[ "$(timeout_command "$REPLY" stat -f '%Lp' "$permission_helper_executable")" == 700 ]] || exit 1
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    if timeout_command "$REPLY" xattr -p com.apple.quarantine \
        "$permission_helper_executable" >/dev/null 2>&1; then
        print -u2 -r -- "error: Camera permission launcher is quarantined"
        exit 1
    fi
    permission_helper_executable=${permission_helper_executable:A}
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    permission_helper_inode=$(timeout_command "$REPLY" stat -f '%i' "$permission_helper_executable")
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    permission_launch_token=$(timeout_command "$REPLY" /bin/sh -c \
        "LC_ALL=C od -An -N32 -tx1 /dev/urandom | tr -d '[:space:]'")
    [[ "$permission_launch_token" =~ '^[0-9a-f]{64}$' ]] || exit 1
    permission_marker="HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT=$resolved_run_root"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    permission_app_inode=$(timeout_command "$REPLY" stat -f '%i' "$app_binary") || exit 1
    [[ "$permission_app_inode" == <-> ]] || exit 1
    capture_permission_baseline "$permission_work_deadline" || {
        print -u2 -r -- "error: Camera permission process baseline was inconclusive"
        permission_preserve_root=1
        exit 1
    }
    permission_timeout_cap "$permission_work_deadline" 1 || exit 124
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
        HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN="$permission_launch_token" \
        "$permission_helper_executable" \
        --app-url "$app_bundle" \
        --executable-url "$app_binary" \
        --bundle-id "$product_bundle_identifier" \
        --timeout 120 >"$permission_operator_log" 2>&1 &
    permission_helper_pid=$!
    permission_supervision_started=1
    capture_permission_helper_identity "$permission_work_deadline" || {
        print -u2 -r -- "error: Camera permission launcher identity could not be established"
        exit 1
    }
    while [[ ! -f "$permission_launcher_result" ]]; do
        scan_permission_processes "$permission_work_deadline" || exit 1
        if ! kill -0 "$permission_helper_pid" 2>/dev/null; then
            reap_permission_app "$permission_work_deadline" || true
            print -u2 -r -- "error: Camera permission launcher exited without a result"
            exit 1
        fi
        permission_sleep "$permission_work_deadline" || exit 124
    done
    while (( ${#permission_registry_pids} == 0 )); do
        scan_permission_processes "$permission_work_deadline" || exit 1
        (( ${#permission_registry_pids} <= 1 )) || {
            print -u2 -r -- "error: Camera permission ownership was not unique"
            exit 1
        }
        (( ${#permission_registry_pids} == 1 )) && break
        permission_sleep "$permission_work_deadline" || exit 124
    done
    (( ${#permission_registry_pids} == 1 )) || exit 1
    permission_app_pid="${permission_registry_pids[1]}"
    permission_timeout_cap "$permission_work_deadline" 5 || exit 124
    verified_result=$(timeout_command "$REPLY" env \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_LAUNCH_TOKEN="$permission_launch_token" \
        HOLDTYPE_DEV_VLOGS_PHASE_0B_EXPECTED_PID="$permission_app_pid" \
        "$permission_helper_executable" --verify-result) || {
        print -u2 -r -- "error: Camera permission launcher result was invalid"
        exit 1
    }
    parse_permission_verified_result "$verified_result" || {
        print -u2 -r -- "error: Camera permission launcher result was rejected"
        exit 1
    }
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    expected_process_digest=$(print -rn -- "$permission_launch_token:$permission_app_pid" |
        timeout_command "$REPLY" shasum -a 256 |
        awk '{ print $1 }')
    publish_permission_acknowledgment "$expected_process_digest" "$permission_work_deadline" || exit 1
    wait_for_permission_helper_exit "$permission_work_deadline" || exit 1
    reap_permission_app "$permission_work_deadline" || exit 1
    while ! permission_terminal_observed "$permission_work_deadline"; do
        scan_permission_processes "$permission_work_deadline" || {
            print -u2 -r -- "error: Camera permission process ownership was inconclusive"
            exit 1
        }
        if ! kill -0 "$permission_app_pid" 2>/dev/null; then
            print -u2 -r -- "error: Camera permission process exited before terminal evidence"
            exit 1
        fi
        (( SECONDS < permission_work_deadline )) || {
            print -u2 -r -- "error: Camera permission request exceeded its bounded deadline"
            exit 124
        }
        permission_sleep "$permission_work_deadline" || exit 124
    done
    if ! wait_for_permission_exit "$permission_work_deadline" 5; then
        print -u2 -r -- "error: Camera permission processes did not exit naturally"
        terminate_permission_processes "$permission_work_deadline" || true
        exit 1
    fi
    permission_quiet_rescan "$permission_work_deadline" || {
        print -u2 -r -- "error: Camera permission process set did not become quiet"
        terminate_permission_processes "$permission_work_deadline" || true
        exit 1
    }
    (( permission_app_exit_status == 0 )) || exit "$permission_app_exit_status"
    permission_timeout_cap "$permission_work_deadline" 2 || exit 124
    timeout_command "$REPLY" grep -hoE '"category":"[^"]+"' \
        "$resolved_run_root"/dv-p0b-camera-authorization-*/evidence/events.jsonl | tail -1
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
