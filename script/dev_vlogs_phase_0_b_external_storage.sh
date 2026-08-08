#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}
program_name=${0:t}
build_timeout_seconds=600
test_timeout_seconds=180
metadata_timeout_seconds=15
termination_checks=50
volume_root=""
expected_class=""
expected_filesystem=""
case_id=""
execute_enabled=false
timeout_executable=""
supervisor_pid=""
supervisor_pgid=""
supervisor_identity=""
supervisor_member_identities=()
group_member_pids=()
group_state="uncertain"
caffeinate_pid=""
caffeinate_identity=""
reaped_exit_code=70

usage() {
    print -r -- "usage: $program_name --execute --volume-root ABSOLUTE_MOUNT_ROOT --expected-class external-ssd|external-hdd --expected-filesystem apfs|hfs|exfat --case-id ID"
    print -r -- ""
    print -r -- "No volume is discovered or selected automatically. The enabled run writes at most"
    print -r -- "64 KiB per file beneath .HoldTypeDevVlogsPhase0B/<run-id>/ and runs bounded cleanup."
}

fail() {
    print -u2 -r -- "error: $1"
    exit 64
}

set_once() {
    local current_value="$1"
    [[ -z "$current_value" ]] || fail "an option was supplied more than once"
}

while (( $# > 0 )); do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --execute)
            [[ "$execute_enabled" == false ]] || fail "--execute was supplied more than once"
            execute_enabled=true
            shift
            ;;
        --volume-root)
            (( $# >= 2 )) || fail "--volume-root requires a value"
            set_once "$volume_root"
            volume_root="$2"
            shift 2
            ;;
        --expected-class)
            (( $# >= 2 )) || fail "--expected-class requires a value"
            set_once "$expected_class"
            expected_class="$2"
            shift 2
            ;;
        --expected-filesystem)
            (( $# >= 2 )) || fail "--expected-filesystem requires a value"
            set_once "$expected_filesystem"
            expected_filesystem="$2"
            shift 2
            ;;
        --case-id)
            (( $# >= 2 )) || fail "--case-id requires a value"
            set_once "$case_id"
            case_id="$2"
            shift 2
            ;;
        *)
            fail "unknown option"
            ;;
    esac
done

[[ "$execute_enabled" == true ]] || fail "explicit --execute opt-in is required"
[[ -n "$volume_root" && -n "$expected_class" && -n "$expected_filesystem" && -n "$case_id" ]] || {
    fail "all authority arguments are required"
}
[[ "$expected_class" == external-ssd || "$expected_class" == external-hdd ]] || {
    fail "expected class must be external-ssd or external-hdd"
}
[[ "$expected_filesystem" == apfs || "$expected_filesystem" == hfs || "$expected_filesystem" == exfat ]] || {
    fail "expected filesystem must be apfs, hfs, or exfat"
}
[[ "$case_id" =~ '^[A-Za-z0-9_-]{1,64}$' ]] || fail "case ID is invalid"
[[ "$volume_root" == /* && "$volume_root" != / && "$volume_root" != */ &&
   "$volume_root" != *'/../'* && "$volume_root" != *'/./'* && "$volume_root" != *$'\n'* ]] || {
    fail "volume root must be one exact absolute mount root"
}
home_path="${HOME:-}"
home_path="${home_path%/}"
[[ -z "$home_path" || ( "$volume_root" != "$home_path" && "$home_path" != "$volume_root"/* ) ]] || {
    fail "volume root is categorically too broad"
}

external_preflight_program='
set -euo pipefail
volume_root=$1; expected_class=$2; expected_filesystem=$3; awk_program=$4
components=("${(@s:/:)volume_root}"); current="/"
for component in "${components[@]}"; do
    [[ -n "$component" ]] || continue
    current="${current%/}/$component"
    [[ ! -L "$current" ]] || exit 65
done
[[ -d "$volume_root" && "${volume_root:A}" == "$volume_root" ]] || exit 65
disk_info=$(/usr/sbin/diskutil info -plist "$volume_root" 2>/dev/null) || exit 65
plist_value() { print -rn -- "$disk_info" | /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null; }
mount_point=$(plist_value MountPoint); internal=$(plist_value Internal)
external_hint=$(plist_value RemovableMediaOrExternalDevice); writable=$(plist_value WritableVolume)
filesystem=$(plist_value FilesystemType); solid_state=$(plist_value SolidState)
[[ "$mount_point" == "$volume_root" && "$internal" == false && "$external_hint" == true ]] || exit 65
[[ "$writable" == true && -w "$volume_root" ]] || exit 65
[[ "${filesystem:l}" == "$expected_filesystem" ]] || exit 65
[[ ( "$expected_class" == external-ssd && "$solid_state" == true ) ||
   ( "$expected_class" == external-hdd && "$solid_state" == false ) ]] || exit 65
available_kib=$(/bin/df -Pk "$volume_root" 2>/dev/null | /usr/bin/awk "$awk_program")
[[ "$available_kib" == <-> && "$available_kib" -gt 0 ]] || exit 65
prefix="$volume_root/.HoldTypeDevVlogsPhase0B"
[[ ! -e "$prefix" && ! -L "$prefix" ]] || exit 65
'

if command -v timeout >/dev/null 2>&1; then
    timeout_executable=$(command -v timeout)
elif command -v gtimeout >/dev/null 2>&1; then
    timeout_executable=$(command -v gtimeout)
else
    print -u2 -r -- "error: a bounded timeout command is required"
    exit 127
fi

run_metadata_probe() {
    "$timeout_executable" --signal=TERM --kill-after=2s "$metadata_timeout_seconds" "$@"
}

run_external_preflight() {
    run_metadata_probe /bin/zsh -c "$external_preflight_program" external-preflight \
        "$volume_root" "$expected_class" "$expected_filesystem" 'END { print $4 }'
}

validate_volume() {
    run_external_preflight >/dev/null 2>&1 || fail "selected volume preflight failed"
}

process_identity() {
    local pid="$1" details
    [[ "$pid" == <-> ]] || return 1
    details=$(run_metadata_probe /bin/ps -o pgid=,lstart= -p "$pid" 2>/dev/null) || return 1
    details="${details##[[:space:]]#}"
    [[ -n "$details" ]] || return 1
    print -r -- "$pid|$details"
}

group_members() {
    local pgid="$1"
    # Exact captured process-group membership only; never select by command name or broad pattern.
    run_metadata_probe /usr/bin/pgrep -g "$pgid" 2>/dev/null
}

read_group_state() {
    local pgid="$1" output exit_code member
    group_state="uncertain"; group_member_pids=()
    set +e; output=$(group_members "$pgid"); exit_code=$?; set -e
    if (( exit_code == 1 )); then group_state="empty"; return 0; fi
    (( exit_code == 0 )) || return "$exit_code"
    for member in "${(@f)output}"; do
        [[ "$member" == <-> ]] || return 70
        group_member_pids+=("$member")
    done
    (( ${#group_member_pids} > 0 )) || return 70
    group_state="members"
}

capture_group_identities() {
    local pgid="$1" member identity
    supervisor_member_identities=()
    read_group_state "$pgid" || return 1
    [[ "$group_state" == members ]] || return 1
    for member in "${group_member_pids[@]}"; do
        identity=$(process_identity "$member") || continue
        [[ "$identity" == "$member|$pgid "* ]] || return 1
        supervisor_member_identities+=("$identity")
    done
    (( ${#supervisor_member_identities} > 0 ))
}

wait_for_group_empty() {
    local pgid="$1" checks="$2"
    while (( checks > 0 )); do
        read_group_state "$pgid" || return 70
        [[ "$group_state" == empty ]] && return 0
        /bin/sleep 0.1; checks=$(( checks - 1 ))
    done
    return 1
}

wait_for_pid_exit() {
    local pid="$1" checks="$2"
    while kill -0 "$pid" 2>/dev/null && (( checks > 0 )); do
        /bin/sleep 0.1; checks=$(( checks - 1 ))
    done
    ! kill -0 "$pid" 2>/dev/null
}

reap_verified_exited_pid() {
    local pid="$1"
    ! kill -0 "$pid" 2>/dev/null || return 70
    # This wait only reaps an already-verified exited child; running waits use finite polling above.
    set +e; wait "$pid" 2>/dev/null; reaped_exit_code=$?; set -e
    return 0
}

terminate_supervisor() {
    local pid="$supervisor_pid" pgid="$supervisor_pgid" current
    [[ "$pid" == <-> ]] || return 0
    [[ "$pgid" == "$pid" ]] || return 1
    if kill -0 "$pid" 2>/dev/null; then
        current=$(process_identity "$pid" 2>/dev/null) || return 1
        [[ "$current" == "$supervisor_identity" ]] || return 1
    fi
    read_group_state "$pgid" || return 1
    if [[ "$group_state" == empty ]]; then
        reap_verified_exited_pid "$pid" || return 1
        supervisor_pid=""; supervisor_pgid=""; supervisor_identity=""; supervisor_member_identities=()
        return 0
    fi
    capture_group_identities "$pgid" || return 1
    kill -TERM -- -"$pgid" 2>/dev/null || true
    local group_wait
    if wait_for_group_empty "$pgid" "$termination_checks"; then
        group_wait=0
    else
        group_wait=$?
        (( group_wait == 1 )) || return 1
        kill -KILL -- -"$pgid" 2>/dev/null || true
        wait_for_group_empty "$pgid" "$termination_checks" || return 1
    fi
    reap_verified_exited_pid "$pid" || return 1
    supervisor_pid=""; supervisor_pgid=""; supervisor_identity=""; supervisor_member_identities=()
}

stop_caffeinate() {
    local pid="$caffeinate_pid" checks=$termination_checks
    [[ "$pid" == <-> ]] || return 0
    if ! kill -0 "$pid" 2>/dev/null; then
        reap_verified_exited_pid "$pid" || return 1
        caffeinate_pid=""; caffeinate_identity=""
        return 0
    fi
    [[ "$(process_identity "$pid")" == "$caffeinate_identity" ]] || return 1
    kill -TERM "$pid" 2>/dev/null || true
    if ! wait_for_pid_exit "$pid" "$checks"; then
        kill -KILL "$pid" 2>/dev/null || true
        wait_for_pid_exit "$pid" "$termination_checks" || return 1
    fi
    reap_verified_exited_pid "$pid" || return 1
    caffeinate_pid=""; caffeinate_identity=""
}

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM
    terminate_supervisor || exit_code=70
    stop_caffeinate || exit_code=70
    exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_bounded() {
    local seconds="$1" wait_checks
    shift
    "$timeout_executable" --signal=TERM --kill-after=5s "$seconds" "$@" &
    supervisor_pid=$!
    supervisor_pgid=$supervisor_pid
    supervisor_identity=$(process_identity "$supervisor_pid") || return 70
    [[ "$supervisor_identity" == "$supervisor_pid|$supervisor_pid "* ]] || return 70
    capture_group_identities "$supervisor_pgid" || return 70
    wait_checks=$(( (seconds + 7) * 10 ))
    if ! wait_for_pid_exit "$supervisor_pid" "$wait_checks"; then
        terminate_supervisor || return 70
        return 70
    fi
    read_group_state "$supervisor_pgid" || return 70
    if [[ "$group_state" != empty ]]; then
        terminate_supervisor || return 70
        return 70
    fi
    reap_verified_exited_pid "$supervisor_pid" || return 70
    local exit_code=$reaped_exit_code
    supervisor_pid=""; supervisor_pgid=""; supervisor_identity=""; supervisor_member_identities=()
    return "$exit_code"
}

validate_volume
run_id=$(run_metadata_probe /usr/bin/uuidgen | run_metadata_probe /usr/bin/tr '[:upper:]' '[:lower:]')
/usr/bin/caffeinate -dimsu -w $$ &
caffeinate_pid=$!
caffeinate_identity=$(process_identity "$caffeinate_pid") || fail "caffeinate identity unavailable"
cd "$repository_root"

run_bounded "$build_timeout_seconds" /usr/bin/xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    build-for-testing

validate_volume
run_bounded "$test_timeout_seconds" /usr/bin/env \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_ENABLE=execute \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_VOLUME_ROOT="$volume_root" \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_DESTINATION_CLASS="$expected_class" \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_FILESYSTEM_CLASS="$expected_filesystem" \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_CASE_ID="$case_id" \
    HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_RUN_ID="$run_id" \
    /usr/bin/xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    test-without-building \
    -only-testing:HoldTypeTests/DevVlogsExternalStorageRuntimeTests

print -r -- "external_storage_case=$case_id result=pass cleanup=complete"
