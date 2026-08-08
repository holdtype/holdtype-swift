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
caffeinate_pid=""
caffeinate_identity=""

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

validate_no_symlink_components() {
    local -a components
    local component current="/"
    components=("${(@s:/:)volume_root}")
    for component in "${components[@]}"; do
        [[ -n "$component" ]] || continue
        current="${current%/}/$component"
        [[ ! -L "$current" ]] || fail "volume root contains a symbolic-link component"
    done
}

plist_value() {
    local key="$1"
    print -rn -- "$disk_info" | run_metadata_probe /usr/bin/plutil -extract "$key" raw -o - - 2>/dev/null
}

validate_volume() {
    validate_no_symlink_components
    [[ -d "$volume_root" && "${volume_root:A}" == "$volume_root" ]] || {
        fail "volume root is unavailable or not exact"
    }
    disk_info=$(run_metadata_probe /usr/sbin/diskutil info -plist "$volume_root" 2>/dev/null) || {
        fail "selected root metadata is unavailable"
    }
    local mount_point internal external_hint writable filesystem solid_state available_kib
    mount_point=$(plist_value MountPoint) || fail "selected root is not mounted"
    internal=$(plist_value Internal) || fail "internal/external hint is unavailable"
    external_hint=$(plist_value RemovableMediaOrExternalDevice) || fail "physical external hint is unavailable"
    writable=$(plist_value WritableVolume) || fail "writable hint is unavailable"
    filesystem=$(plist_value FilesystemType) || fail "filesystem hint is unavailable"
    solid_state=$(plist_value SolidState) || fail "media-class hint is unavailable"
    [[ "$mount_point" == "$volume_root" && "$internal" == false && "$external_hint" == true ]] || {
        fail "selected root is not the exact mounted external volume root"
    }
    [[ "$writable" == true && -w "$volume_root" ]] || fail "selected volume is not writable"
    [[ "${filesystem:l}" == "$expected_filesystem" ]] || fail "filesystem class does not match"
    if [[ "$expected_class" == external-ssd ]]; then
        [[ "$solid_state" == true ]] || fail "destination class does not match"
    else
        [[ "$solid_state" == false ]] || fail "destination class does not match"
    fi
    local capacity_table
    capacity_table=$(run_metadata_probe /bin/df -Pk "$volume_root" 2>/dev/null) || {
        fail "useful capacity probe failed"
    }
    available_kib=$(print -rn -- "$capacity_table" | run_metadata_probe /usr/bin/awk 'END { print $4 }')
    [[ "$available_kib" == <-> && "$available_kib" -gt 0 ]] || fail "useful capacity is unavailable"
    local prefix="$volume_root/.HoldTypeDevVlogsPhase0B"
    [[ ! -e "$prefix" && ! -L "$prefix" ]] || fail "scratch prefix must initially be absent"
}

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
    run_metadata_probe /usr/bin/pgrep -g "$pgid" 2>/dev/null || true
}

group_is_empty() {
    [[ -z "$(group_members "$1")" ]]
}

capture_group_identities() {
    local pgid="$1" member identity
    supervisor_member_identities=()
    for member in "${(@f)$(group_members "$pgid")}"; do
        [[ "$member" == <-> ]] || continue
        identity=$(process_identity "$member") || continue
        [[ "$identity" == "$member|$pgid "* ]] || return 1
        supervisor_member_identities+=("$identity")
    done
    (( ${#supervisor_member_identities} > 0 )) || group_is_empty "$pgid"
}

terminate_supervisor() {
    local pid="$supervisor_pid" pgid="$supervisor_pgid" checks=$termination_checks current
    [[ "$pid" == <-> ]] || return 0
    [[ "$pgid" == "$pid" ]] || return 1
    current=$(process_identity "$pid" 2>/dev/null || true)
    [[ -z "$current" || "$current" == "$supervisor_identity" ]] || return 1
    if group_is_empty "$pgid"; then
        wait "$pid" 2>/dev/null || true
        supervisor_pid=""; supervisor_pgid=""; supervisor_identity=""; supervisor_member_identities=()
        return 0
    fi
    capture_group_identities "$pgid" || return 1
    kill -TERM -- -"$pgid" 2>/dev/null || true
    while ! group_is_empty "$pgid" && (( checks > 0 )); do
        /bin/sleep 0.1; checks=$(( checks - 1 ))
    done
    if ! group_is_empty "$pgid"; then
        kill -KILL -- -"$pgid" 2>/dev/null || true
        checks=$termination_checks
        while ! group_is_empty "$pgid" && (( checks > 0 )); do
            /bin/sleep 0.1; checks=$(( checks - 1 ))
        done
    fi
    group_is_empty "$pgid" || return 1
    wait "$pid" 2>/dev/null || true
    supervisor_pid=""; supervisor_pgid=""; supervisor_identity=""; supervisor_member_identities=()
}

stop_caffeinate() {
    local pid="$caffeinate_pid" checks=$termination_checks
    [[ "$pid" == <-> ]] || return 0
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null || true
        caffeinate_pid=""; caffeinate_identity=""
        return 0
    fi
    [[ "$(process_identity "$pid")" == "$caffeinate_identity" ]] || return 1
    kill -TERM "$pid" 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null && (( checks > 0 )); do
        /bin/sleep 0.1; checks=$(( checks - 1 ))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null || true
        checks=$termination_checks
        while kill -0 "$pid" 2>/dev/null && (( checks > 0 )); do
            /bin/sleep 0.1; checks=$(( checks - 1 ))
        done
    fi
    kill -0 "$pid" 2>/dev/null && return 1
    wait "$pid" 2>/dev/null || true
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
    local seconds="$1"
    shift
    "$timeout_executable" --signal=TERM --kill-after=5s "$seconds" "$@" &
    supervisor_pid=$!
    supervisor_pgid=$supervisor_pid
    supervisor_identity=$(process_identity "$supervisor_pid") || return 70
    [[ "$supervisor_identity" == "$supervisor_pid|$supervisor_pid "* ]] || return 70
    capture_group_identities "$supervisor_pgid" || return 70
    set +e
    wait "$supervisor_pid"
    local exit_code=$?
    set -e
    group_is_empty "$supervisor_pgid" || terminate_supervisor || return 70
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
