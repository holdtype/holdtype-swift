#!/bin/zsh

set -euo pipefail
zmodload zsh/zselect
typeset -F 3 SECONDS

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
temporary_root_identity=""
bin_root=""
bin_root_identity=""
logs_root=""
logs_root_identity=""
probe=""
probe_identity=""
configured_xctestrun=""
configured_xctestrun_identity=""
host_task_home=""
host_temporary_root=""
deadline=0.000
cleanup_started=false
terminal_class="still_unknown"
terminal_phase="initializing"
terminal_exit_status=70
terminal_finalizing=false
terminal_finalized=false
cleanup_state="incomplete_retained"
evidence_write_state="not_attempted"
evidence_commit_cleanup_state="not_attempted"
success_staging_root=""
evidence_failure_safe_quarantine_root=""
evidence_recovery_staging_root=""
evidence_written_root_identity=""
evidence_written_events_identity=""
build_comparison="uncertain"
hosted_comparison="not_run"
retained_observer_events=""
run_id=""
timeout_executable=""
metadata_timeout_seconds=15
cleanup_reserve_seconds=12
evidence_post_swap_reserve_seconds=30
evidence_commit_helper_status="not_run"
evidence_commit_reconciliation_state="not_run"
outer_timeout_seconds=930
outer_kill_after_seconds=5
controller_pid=""
controller_parent_pid=""
durable_evidence_root=""

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

remaining_budget() {
    local reserve="${1:-0}"
    local -F remaining=$(( deadline - SECONDS - reserve ))
    (( deadline > 0 && remaining > 0.050 )) || return 124
    print -r -- "$remaining"
}

bounded_duration() {
    local requested="$1" reserve="$2" kill_after="$3"
    local -F available duration
    available=$(remaining_budget "$reserve") || return 124
    duration=$(( available - kill_after ))
    (( duration > 0.050 )) || return 124
    (( requested < duration )) && duration=$requested
    print -r -- "$duration"
}

run_timed_command() {
    local requested="$1" reserve="$2" kill_after="$3" duration
    shift 3
    duration=$(bounded_duration "$requested" "$reserve" "$kill_after") || return 124
    "$timeout_executable" --signal=TERM --kill-after="${kill_after}s" "${duration}s" \
        "$@" 2>/dev/null
}

run_metadata_probe() {
    local reserve=$cleanup_reserve_seconds
    [[ "$cleanup_started" == true ]] && reserve=0
    run_timed_command "$metadata_timeout_seconds" "$reserve" 1 "$@"
}

run_cleanup_command() {
    run_timed_command 5 0 1 "$@" >/dev/null
}

pause_tenth() {
    remaining_budget 0 >/dev/null || return 124
    zselect -t 10 2>/dev/null || true
}

identity() {
    local path="$1" expected_mode="$2" value
    [[ -d "$path" && ! -L "$path" && "${path:A}" == "$path" ]] || return 70
    value=$(run_metadata_probe /usr/bin/stat -f '%u|%Lp|%d|%i' "$path" 2>/dev/null) || return 70
    [[ "$value" == "$EUID|$expected_mode|"* ]] || return 70
    print -r -- "$value"
}

evidence_directory_identity() {
    local path="$1" expected_mode="$2" value
    [[ -d "$path" && ! -L "$path" && "${path:A}" == "$path" ]] || return 70
    value=$(run_metadata_probe /usr/bin/stat -f '%u|%Lp|%d|%i|%l' "$path") || return 70
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
    value="${value#"${value%%[![:space:]]*}"}"
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
       -n "$derived_data_identity" && -n "$temporary_root_identity" &&
       -n "$bin_root_identity" && -n "$logs_root_identity" ]] || return 70
    current=$(identity "$run_root" 700) || return 70
    [[ "$current" == "$run_root_identity" ]] || return 70
    [[ "$task_home" == "$run_root/home" && "$derived_data" == "$task_home/DerivedData" &&
       "$temporary_root" == "$task_home/tmp" && "$bin_root" == "$run_root/bin" &&
       "$logs_root" == "$run_root/logs" && "$probe" == "$bin_root/probe" ]] || return 70
    current=$(identity "$task_home" 700) || return 70
    [[ "$current" == "$task_home_identity" ]] || return 70
    current=$(identity "$derived_data" 700) || return 70
    [[ "$current" == "$derived_data_identity" ]] || return 70
    current=$(identity "$temporary_root" 700) || return 70
    [[ "$current" == "$temporary_root_identity" ]] || return 70
    current=$(identity "$bin_root" 700) || return 70
    [[ "$current" == "$bin_root_identity" ]] || return 70
    current=$(identity "$logs_root" 700) || return 70
    [[ "$current" == "$logs_root_identity" ]] || return 70
    if [[ -n "$probe_identity" || -e "$probe" || -L "$probe" ]]; then
        [[ -n "$probe_identity" ]] || return 70
        current=$(regular_file_identity "$probe" 700) || return 70
        [[ "$current" == "$probe_identity" ]] || return 70
    fi
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
    run_cleanup_command /bin/mv -n "$run_root" "$quarantine" || return 70
    [[ ! -e "$run_root" && ! -L "$run_root" ]] || return 70
    current=$(identity "$quarantine" 700) || return 70
    [[ "$current" == "$run_root_identity" ]] || return 70
    run_cleanup_command /bin/rm -rf -- "$quarantine" || return 70
    [[ ! -e "$quarantine" && ! -L "$quarantine" ]] || return 70
    run_root=""; run_root_identity=""; task_home=""; task_home_identity=""
    derived_data=""; derived_data_identity=""; temporary_root=""
    temporary_root_identity=""; bin_root=""; bin_root_identity=""
    logs_root=""; logs_root_identity=""; probe=""; probe_identity=""
    configured_xctestrun=""; configured_xctestrun_identity=""
    host_task_home=""; host_temporary_root=""
}

stop_supervisor() {
    local current checks=50
    [[ "$supervisor_pid" == <-> ]] || return 0
    remaining_budget 0 >/dev/null || return 70
    if kill -0 "$supervisor_pid" 2>/dev/null; then
        current=$(process_identity "$supervisor_pid") || return 70
        [[ "$current" == "$supervisor_identity" ]] || return 70
        kill -TERM "$supervisor_pid" 2>/dev/null || true
        while kill -0 "$supervisor_pid" 2>/dev/null && (( checks-- > 0 )); do
            pause_tenth || return 70
        done
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
    remaining_budget 0 >/dev/null || return 70
    validate_guard || return 70
    kill -TERM "$guard_pid" 2>/dev/null || true
    while kill -0 "$guard_pid" 2>/dev/null && (( checks-- > 0 )); do
        pause_tenth || return 70
    done
    if kill -0 "$guard_pid" 2>/dev/null; then
        current=$(process_identity "$guard_pid") || return 70
        [[ "$current" == "$guard_identity" ]] || return 70
        kill -KILL "$guard_pid" 2>/dev/null || true
    fi
    set +e; wait "$guard_pid" 2>/dev/null; set -e
    guard_pid=""; guard_identity=""
}

record_terminal() {
    terminal_class="$1"
    terminal_phase="$2"
    terminal_exit_status="$3"
}

run_bounded() {
    local seconds="$1" exit_code duration; shift
    duration=$(bounded_duration "$seconds" "$cleanup_reserve_seconds" 5) || return 124
    validate_roots || return 70
    "$timeout_executable" --signal=TERM --kill-after=5s "${duration}s" "$@" 2>/dev/null &
    supervisor_pid=$!
    supervisor_identity=$(process_identity "$supervisor_pid") || return 70
    [[ "$supervisor_identity" == "$supervisor_pid|$$ "* ]] || return 70
    set +e; wait "$supervisor_pid"; exit_code=$?; set -e
    supervisor_pid=""; supervisor_identity=""
    return "$exit_code"
}

run_bounded_to_log() {
    local seconds="$1" log="$2"; shift 2
    validate_roots || return 70
    { run_bounded "$seconds" "$@" >"$log" 2>&1 } 2>/dev/null
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

write_evidence_file() {
    local evidence_root="$1" root_identity="$2" events_identity="$3"
    local relative="$4" content="$5" current
    remaining_budget 0 >/dev/null || return 124
    if (( $+functions[observer_evidence_write_test_hook] )); then
        observer_evidence_write_test_hook "$relative" || return 70
    fi
    current=$(HTDV_EVIDENCE_CONTENT="$content" run_metadata_probe /usr/bin/python3 - \
        "$evidence_root" "$root_identity" "$events_identity" "$relative" <<'PY'
import os, stat, sys
root, root_identity, events_identity, relative = sys.argv[1:]
def expected(value):
    uid, mode, device, inode, links = value.split("|")
    return int(uid), int(mode, 8), int(device), int(inode), int(links)
def exact(value, identity, directory):
    uid, mode, device, inode, links = expected(identity)
    kind = stat.S_ISDIR(value.st_mode) if directory else stat.S_ISREG(value.st_mode)
    return (kind and value.st_uid == uid and stat.S_IMODE(value.st_mode) == mode and
            value.st_dev == device and value.st_ino == inode and value.st_nlink == links)
if relative.startswith("/") or relative in {"", ".", ".."} or "//" in relative:
    raise SystemExit(70)
parts = relative.split("/")
if len(parts) == 1:
    directory_identity, name = root_identity, parts[0]
elif len(parts) == 2 and parts[0] == "events":
    directory_identity, name = events_identity, parts[1]
else:
    raise SystemExit(70)
flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
root_fd = events_fd = file_fd = None
try:
    root_fd = os.open(root, flags)
    if not exact(os.fstat(root_fd), root_identity, True): raise OSError()
    events_fd = os.open("events", flags, dir_fd=root_fd)
    if not exact(os.fstat(events_fd), events_identity, True): raise OSError()
    directory_fd = events_fd if len(parts) == 2 else root_fd
    file_fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                      0o600, dir_fd=directory_fd)
    os.fchmod(file_fd, 0o600)
    content = os.environ.pop("HTDV_EVIDENCE_CONTENT").encode()
    offset = 0
    while offset < len(content):
        written = os.write(file_fd, content[offset:])
        if written <= 0: raise OSError()
        offset += written
    value = os.fstat(file_fd)
    if (not stat.S_ISREG(value.st_mode) or value.st_uid != os.geteuid() or
            stat.S_IMODE(value.st_mode) != 0o600 or value.st_nlink != 1):
        raise OSError()
    root_value, events_value = os.fstat(root_fd), os.fstat(events_fd)
    for directory_value in (root_value, events_value):
        if (not stat.S_ISDIR(directory_value.st_mode) or
                directory_value.st_uid != os.geteuid() or
                stat.S_IMODE(directory_value.st_mode) != 0o755): raise OSError()
    print(f"{value.st_uid}|600|{value.st_dev}|{value.st_ino}|{value.st_nlink}")
    print(f"{root_value.st_uid}|755|{root_value.st_dev}|{root_value.st_ino}|{root_value.st_nlink}")
    print(f"{events_value.st_uid}|755|{events_value.st_dev}|{events_value.st_ino}|{events_value.st_nlink}")
except (OSError, ValueError):
    raise SystemExit(70)
finally:
    for descriptor in (file_fd, events_fd, root_fd):
        if descriptor is not None:
            try: os.close(descriptor)
            except OSError: pass
PY
    ) || return $?
    local -a identities=("${(@f)current}")
    (( ${#identities} == 3 )) || return 70
    current="${identities[1]}"
    [[ "$current" == "$EUID|600|"*'|1' ]] || return 70
    evidence_written_root_identity="${identities[2]}"
    evidence_written_events_identity="${identities[3]}"
    if [[ "${capture_evidence_identities:-false}" == true ]]; then
        captured_evidence_identities+="$relative"$'\t'"$current"$'\n'
    fi
}

render_failure_safe_evidence() {
    local evidence_root="$1" root_identity="$2" events_identity="$3" writer="$4"
    local relative artifacts_content
    typeset -A contents
    artifacts_content="path,status"$'\n'
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        artifacts_content+="$relative,incomplete_retained"$'\n'
    done
    contents=(
        summary.md $'# Phase 0B protected-storage observer R01\n\nterminal_class: evidence_write_failed\nterminal_phase: evidence\nbuild_window: uncertain\nhosted_window: not_run\ncleanup: incomplete_retained\nevidence_state: uncommitted\n'
        source-feasibility.md $'# Source feasibility\n\ncontroller: script/dev_vlogs_phase_0_b_protected_storage_observer.sh\nprobe: script/dev_vlogs_phase_0_b_protected_storage_probe.c\nobserver: HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BProtectedStorageObserver.swift\nroute_schema: stderr-json-v1\nterminal_class: evidence_write_failed\n'
        environment.json $'{"schema_version":1,"mode":"nonexternal","private_home":true,"cleanup":"incomplete_retained"}\n'
        matrix.csv $'case_id,terminal_class,terminal_phase,cleanup\nprotected_metadata,evidence_write_failed,evidence,incomplete_retained\n'
        measurements.csv $'phase,result\nbuild,uncertain\nhosted,not_run\n'
        artifacts.csv "$artifacts_content"
        residuals.md $'# Residuals\n\nArbitrary non-run-owned writers remain unattributed and classify as still_unknown.\n'
        events/storage-observer-r01.jsonl ""
    )
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        "$writer" "$evidence_root" "$root_identity" "$events_identity" \
            "$relative" "${contents[$relative]}" || return $?
        root_identity="$evidence_written_root_identity"
        events_identity="$evidence_written_events_identity"
    done
}

stage_evidence_file() {
    local relative="$4"
    if (( $+functions[observer_evidence_promotion_test_hook] )); then
        observer_evidence_promotion_test_hook "$relative" || return 70
    fi
    write_evidence_file "$@"
}

pin_evidence_files() {
    local evidence_root="$1" relative current pins=""
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        current=$(regular_file_identity "$evidence_root/$relative" 600) || return 70
        pins+="$relative"$'\t'"$current"$'\n'
    done
    print -rn -- "$pins"
}

validate_evidence_file_identities() {
    local evidence_root="$1" expected="$2" current
    current=$(pin_evidence_files "$evidence_root") || return 70
    [[ "$current" == "$expected" ]] || return 70
}

cleanup_pinned_evidence_tree() {
    local tree="$1" tree_identity="$2" events_identity="$3" file_identities="$4"
    local parent="${tree:h}" name="${tree:t}" parent_mode parent_identity
    [[ "${parent:A}" == "$parent" && "$name" != */* ]] || return 70
    parent_mode=$(run_metadata_probe /usr/bin/stat -f '%Lp' "$parent") || return 70
    parent_identity=$(evidence_directory_identity "$parent" "$parent_mode") || return 70
    if (( $+functions[observer_evidence_cleanup_boundary_test_hook] )); then
        observer_evidence_cleanup_boundary_test_hook "$tree" || return 70
    fi
    HTDV_EVIDENCE_IDENTITIES="$file_identities" \
        HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER="${HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER:-}" \
        run_metadata_probe /usr/bin/python3 - "$parent" \
        "$parent_identity" "$name" "$tree_identity" "$events_identity" <<'PY' || return $?
import os, stat, sys
parent, parent_identity, tree_name, tree_identity, events_identity = sys.argv[1:]
def expected(value):
    uid, mode, device, inode, links = value.split("|")
    return int(uid), int(mode, 8), int(device), int(inode), int(links)
def exact(value, identity, directory):
    uid, mode, device, inode, links = expected(identity)
    kind = stat.S_ISDIR(value.st_mode) if directory else stat.S_ISREG(value.st_mode)
    return (kind and value.st_uid == uid and stat.S_IMODE(value.st_mode) == mode and
            value.st_dev == device and value.st_ino == inode and value.st_nlink == links)
flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
parent_fd = tree_fd = events_fd = None
try:
    identities = {}
    for line in os.environ.pop("HTDV_EVIDENCE_IDENTITIES").splitlines():
        relative, identity = line.split("\t", 1)
        if relative in identities: raise ValueError()
        identities[relative] = identity
    parent_fd = os.open(parent, flags)
    if not exact(os.fstat(parent_fd), parent_identity, True): raise OSError()
    tree_fd = os.open(tree_name, flags, dir_fd=parent_fd)
    if not exact(os.fstat(tree_fd), tree_identity, True): raise OSError()
    events_fd = os.open("events", flags, dir_fd=tree_fd)
    if not exact(os.fstat(events_fd), events_identity, True): raise OSError()
    expected_paths = {"summary.md", "source-feasibility.md", "environment.json", "matrix.csv",
                      "measurements.csv", "artifacts.csv", "residuals.md",
                      "events/storage-observer-r01.jsonl"}
    if set(identities) != expected_paths: raise OSError()
    for relative, identity in identities.items():
        descriptor = events_fd if relative.startswith("events/") else tree_fd
        name = relative.split("/")[-1]
        if not exact(os.stat(name, dir_fd=descriptor, follow_symlinks=False), identity, False):
            raise OSError()
    fail_after = os.environ.pop("HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER", "")
    fail_after = int(fail_after) if fail_after else 0
    removed = 0
    for relative in identities:
        descriptor = events_fd if relative.startswith("events/") else tree_fd
        os.unlink(relative.split("/")[-1], dir_fd=descriptor)
        removed += 1
        if fail_after and removed == fail_after: raise OSError()
    os.rmdir("events", dir_fd=tree_fd)
    os.rmdir(tree_name, dir_fd=parent_fd)
except (OSError, ValueError):
    raise SystemExit(70)
finally:
    for descriptor in (events_fd, tree_fd, parent_fd):
        if descriptor is not None:
            try: os.close(descriptor)
            except OSError: pass
PY
}

move_pinned_evidence_tree_to_absent_name() {
    local parent="$1" parent_identity="$2" source_name="$3" source_identity="$4"
    local events_identity="$5" file_identities="$6" destination_name="$7" stage="$8"
    local source="$parent/$source_name" destination="$parent/$destination_name" current
    [[ "$source_name" != */* && "$destination_name" != */* && "$source_name" != "$destination_name" ]] \
        || return 70
    current=$(evidence_directory_identity "$parent" "${parent_identity[(ws:|:)2]}") || return 70
    [[ "$current" == "$parent_identity" ]] || return 70
    current=$(evidence_directory_identity "$source" 755) || return 70
    [[ "$current" == "$source_identity" ]] || return 70
    current=$(evidence_directory_identity "$source/events" 755) || return 70
    [[ "$current" == "$events_identity" ]] || return 70
    validate_evidence_file_identities "$source" "$file_identities" || return 70
    validate_runtime_evidence "$source" "$stage" || return $?
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 70
    remaining_budget 0 >/dev/null || return 124
    zmodload -F zsh/files b:zf_mv || return 70
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 70
    zf_mv -i "$source" "$destination" </dev/null 2>/dev/null
}

reconcile_unpublished_evidence() {
    local parent="$1" parent_identity="$2" retained_name="$3" staged_name="$4"
    local staged_identity="$5" staged_events_identity="$6" staged_file_identities="$7"
    if [[ "${HTDV_OBSERVER_TEST_POST_SWAP_RECONCILE:-}" == sleep ]]; then
        run_timed_command "$metadata_timeout_seconds" 0 1 /bin/zsh -c \
            'trap "" TERM; while true; do :; done' || return $?
    fi
    [[ $(evidence_directory_identity "$parent" "${parent_identity[(ws:|:)2]}") == \
        "$parent_identity" ]] || return 70
    [[ ! -e "$parent/$retained_name" && ! -L "$parent/$retained_name" ]] || return 70
    [[ $(evidence_directory_identity "$parent/$staged_name" 755) == \
        "$staged_identity" ]] || return 70
    [[ $(evidence_directory_identity "$parent/$staged_name/events" 755) == \
        "$staged_events_identity" ]] || return 70
    validate_evidence_file_identities "$parent/$staged_name" "$staged_file_identities" || return 70
    validate_runtime_evidence "$parent/$staged_name" || return $?
}

run_final_publication_test_hook() {
    local reserve="$1" hook_status=0
    case "${HTDV_OBSERVER_TEST_POST_SWAP:-}" in
        "") return 0 ;;
        exit70) return 70 ;;
        sleep)
            run_timed_command "$metadata_timeout_seconds" "$reserve" 1 /bin/zsh -c \
                'trap "" TERM; while true; do :; done' || hook_status=$?
            return "$hook_status"
            ;;
        *) return 70 ;;
    esac
}

recover_failure_safe_authority() {
    local parent="$1" parent_identity="$2" evidence_root="$3"
    local recovery_identity recovery_events_identity recovery_file_identities current
    local capture_evidence_identities=true captured_evidence_identities=""
    evidence_recovery_staging_root=$(run_metadata_probe /usr/bin/mktemp -d \
        "$parent/.${evidence_root:t}.failure.XXXXXXXX") || return 70
    [[ "${evidence_recovery_staging_root:h}" == "$parent" ]] || return 70
    run_metadata_probe /bin/chmod 755 "$evidence_recovery_staging_root" >/dev/null || return 70
    run_metadata_probe /bin/mkdir -m 755 "$evidence_recovery_staging_root/events" >/dev/null \
        || return 70
    recovery_identity=$(evidence_directory_identity "$evidence_recovery_staging_root" 755) \
        || return 70
    recovery_events_identity=$(evidence_directory_identity \
        "$evidence_recovery_staging_root/events" 755) || return 70
    render_failure_safe_evidence "$evidence_recovery_staging_root" "$recovery_identity" \
        "$recovery_events_identity" write_evidence_file || return $?
    capture_evidence_identities=false
    recovery_identity=$(evidence_directory_identity "$evidence_recovery_staging_root" 755) \
        || return 70
    recovery_events_identity=$(evidence_directory_identity \
        "$evidence_recovery_staging_root/events" 755) || return 70
    recovery_file_identities=$(pin_evidence_files "$evidence_recovery_staging_root") || return 70
    current=$(evidence_directory_identity "$parent" "${parent_identity[(ws:|:)2]}") || return 70
    [[ "${current%|*}" == "${parent_identity%|*}" ]] || return 70
    parent_identity="$current"
    move_pinned_evidence_tree_to_absent_name "$parent" "$parent_identity" \
        "${evidence_recovery_staging_root:t}" "$recovery_identity" "$recovery_events_identity" \
        "$recovery_file_identities" "${evidence_root:t}" pending || return $?
    evidence_recovery_staging_root=""
}

validate_runtime_evidence() {
    local evidence_root="$1" stage="${2:-complete}"
    run_metadata_probe /usr/bin/python3 - "$evidence_root" "$EUID" "$terminal_class" \
        "$terminal_phase" "$build_comparison" "$hosted_comparison" "$cleanup_state" "$stage" \
        <<'PY' || return $?
import csv, io, json, os, pathlib, stat, sys
root = pathlib.Path(sys.argv[1])
uid = int(sys.argv[2])
terminal, phase, build, hosted, cleanup, stage = sys.argv[3:]
paths = ["summary.md", "source-feasibility.md", "environment.json", "matrix.csv",
         "measurements.csv", "artifacts.csv", "residuals.md",
         "events/storage-observer-r01.jsonl"]
allowed_terminal = {"environment_conflict", "guard_discontinuity", "build_failed",
 "build_window_change_correlated", "run_owned_canonical_recovery_write_correlated",
 "still_unknown", "evidence_conflict", "observer_invalid", "metadata_uncertain",
 "hosted_test_failed", "pass_unchanged", "owner_exposed_no_mutation", "cleanup_uncertain",
 "evidence_write_failed"}
allowed_phase = {"initializing", "baseline", "guard", "setup", "probe_build", "build",
 "hosted_setup", "hosted", "cleanup", "signal", "controller", "evidence"}
allowed_compare = {"uncertain", "not_run", "unchanged", "changed", "missing_unchanged"}
if stage not in {"pending", "complete"}:
    raise SystemExit(65)
if stage == "pending":
    terminal, phase, build, hosted, cleanup = ("evidence_write_failed", "evidence",
                                               "uncertain", "not_run", "incomplete_retained")
if terminal not in allowed_terminal or phase not in allowed_phase:
    raise SystemExit(65)
if build not in allowed_compare or hosted not in allowed_compare:
    raise SystemExit(65)
if cleanup not in {"complete", "incomplete_retained"}:
    raise SystemExit(65)
try:
    entries = list(os.scandir(root))
    event_entries = list(os.scandir(root / "events"))
except OSError:
    raise SystemExit(65)
root_names = paths[:7] + ["events"]
if sorted(entry.name for entry in entries) != sorted(root_names):
    raise SystemExit(65)
if [entry.name for entry in event_entries] != ["storage-observer-r01.jsonl"]:
    raise SystemExit(65)
checked_paths = paths
for relative in checked_paths:
    value = os.lstat(root / relative)
    if not stat.S_ISREG(value.st_mode) or stat.S_IMODE(value.st_mode) != 0o600:
        raise SystemExit(65)
    if value.st_uid != uid or value.st_nlink != 1:
        raise SystemExit(65)
summary = (root / "summary.md").read_text()
expected_summary = f"""# Phase 0B protected-storage observer R01

terminal_class: {terminal}
terminal_phase: {phase}
build_window: {build}
hosted_window: {hosted}
cleanup: {cleanup}
"""
if stage == "pending": expected_summary += "evidence_state: uncommitted\n"
if summary != expected_summary:
    raise SystemExit(65)
source = (root / "source-feasibility.md").read_text()
expected_source = f"""# Source feasibility

controller: script/dev_vlogs_phase_0_b_protected_storage_observer.sh
probe: script/dev_vlogs_phase_0_b_protected_storage_probe.c
observer: HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BProtectedStorageObserver.swift
route_schema: stderr-json-v1
terminal_class: {terminal}
"""
if source != expected_source:
    raise SystemExit(65)
environment = json.loads((root / "environment.json").read_text())
if environment != {"schema_version": 1, "mode": "nonexternal", "private_home": True,
                   "cleanup": cleanup} or type(environment["schema_version"]) is not int:
    raise SystemExit(65)
def rows(name):
    with (root / name).open(newline="") as value:
        return list(csv.reader(value))
if rows("matrix.csv") != [["case_id", "terminal_class", "terminal_phase", "cleanup"],
                           ["protected_metadata", terminal, phase, cleanup]]:
    raise SystemExit(65)
if rows("measurements.csv") != [["phase", "result"], ["build", build], ["hosted", hosted]]:
    raise SystemExit(65)
expected_artifacts = [["path", "status"]] + [[relative, cleanup] for relative in paths]
if rows("artifacts.csv") != expected_artifacts:
    raise SystemExit(65)
if (root / "residuals.md").read_text() != """# Residuals

Arbitrary non-run-owned writers remain unattributed and classify as still_unknown.
""":
    raise SystemExit(65)
for line in (root / paths[-1]).read_text().splitlines():
    if not line.startswith("HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "):
        raise SystemExit(65)
    try: json.loads(line.split(" ", 1)[1])
    except (json.JSONDecodeError, IndexError): raise SystemExit(65)
if stage == "pending" and (root / paths[-1]).read_text(): raise SystemExit(65)
PY
    if [[ "$stage" == complete && -s "$evidence_root/events/storage-observer-r01.jsonl" ]]; then
        [[ -n "${run_id:-}" ]] || return 70
        validate_observer_stream "$evidence_root/events/storage-observer-r01.jsonl" \
            "${run_id:-}" facts >/dev/null || return 70
    fi
}

write_runtime_evidence() {
    local evidence_root="${1:-$repository_root/docs/qa/runs/dev-vlogs-phase-0b-storage-observer-r01}"
    local relative root_identity events_identity artifacts_content validation_status=0 current
    local parent parent_mode parent_identity retained_name staged_name staged_identity
    local quarantine_name hook_status=0
    local staged_events_identity retained_file_identities staged_file_identities
    local summary_content source_content environment_content matrix_content measurements_content
    local capture_evidence_identities=false captured_evidence_identities=""
    typeset -A final_contents
    evidence_commit_helper_status="not_run"; evidence_commit_reconciliation_state="not_run"
    evidence_failure_safe_quarantine_root=""; evidence_recovery_staging_root=""
    remaining_budget 0 >/dev/null || return 124
    parent="${evidence_root:h}"; retained_name="${evidence_root:t}"
    [[ "${parent:A}" == "$parent" && "$retained_name" != */* ]] || return 70
    parent_mode=$(run_metadata_probe /usr/bin/stat -f '%Lp' "$parent" 2>/dev/null) || return 70
    parent_identity=$(identity "$parent" "$parent_mode") || return 70
    [[ ! -e "$evidence_root" && ! -L "$evidence_root" ]] || return 70
    run_metadata_probe /bin/mkdir -m 755 "$evidence_root" >/dev/null || return 70
    run_metadata_probe /bin/mkdir -m 755 "$evidence_root/events" >/dev/null || return 70
    root_identity=$(evidence_directory_identity "$evidence_root" 755) || return 70
    events_identity=$(evidence_directory_identity "$evidence_root/events" 755) || return 70
    summary_content="# Phase 0B protected-storage observer R01

terminal_class: $terminal_class
terminal_phase: $terminal_phase
build_window: $build_comparison
hosted_window: $hosted_comparison
cleanup: $cleanup_state
"
    source_content="# Source feasibility

controller: script/dev_vlogs_phase_0_b_protected_storage_observer.sh
probe: script/dev_vlogs_phase_0_b_protected_storage_probe.c
observer: HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BProtectedStorageObserver.swift
route_schema: stderr-json-v1
terminal_class: $terminal_class
"
    environment_content="{\"schema_version\":1,\"mode\":\"nonexternal\",\"private_home\":true,\"cleanup\":\"$cleanup_state\"}"$'\n'
    matrix_content="case_id,terminal_class,terminal_phase,cleanup
protected_metadata,$terminal_class,$terminal_phase,$cleanup_state
"
    measurements_content="phase,result
build,$build_comparison
hosted,$hosted_comparison
"
    artifacts_content="path,status"$'\n'
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        artifacts_content+="$relative,$cleanup_state"$'\n'
    done
    render_failure_safe_evidence "$evidence_root" "$root_identity" "$events_identity" \
        write_evidence_file || return $?
    root_identity=$(evidence_directory_identity "$evidence_root" 755) || return 70
    events_identity=$(evidence_directory_identity "$evidence_root/events" 755) || return 70
    if (( $+functions[observer_evidence_postcondition_test_hook] )); then
        observer_evidence_postcondition_test_hook "$evidence_root" || return 70
    fi
    validate_runtime_evidence "$evidence_root" pending || return $?
    retained_file_identities=$(pin_evidence_files "$evidence_root") || return 70
    success_staging_root=$(run_metadata_probe /usr/bin/mktemp -d \
        "$parent/.${retained_name}.success.XXXXXXXX") || return 70
    [[ "${success_staging_root:h}" == "$parent" ]] || return 70
    run_metadata_probe /bin/chmod 755 "$success_staging_root" >/dev/null || return 70
    run_metadata_probe /bin/mkdir -m 755 "$success_staging_root/events" >/dev/null || return 70
    staged_identity=$(evidence_directory_identity "$success_staging_root" 755) || return 70
    staged_events_identity=$(evidence_directory_identity "$success_staging_root/events" 755) || return 70
    parent_identity=$(evidence_directory_identity "$parent" "$parent_mode") || return 70
    staged_name="${success_staging_root:t}"
    final_contents=(
        summary.md "$summary_content"
        source-feasibility.md "$source_content"
        environment.json "$environment_content"
        matrix.csv "$matrix_content"
        measurements.csv "$measurements_content"
        artifacts.csv "$artifacts_content"
        residuals.md $'# Residuals\n\nArbitrary non-run-owned writers remain unattributed and classify as still_unknown.\n'
        events/storage-observer-r01.jsonl "$retained_observer_events"
    )
    capture_evidence_identities=true
    for relative in "${(@f)$(evidence_relative_paths)}"; do
        stage_evidence_file "$success_staging_root" "$staged_identity" \
            "$staged_events_identity" "$relative" "${final_contents[$relative]}" || {
            validation_status=$?; break
        }
        staged_identity="$evidence_written_root_identity"
        staged_events_identity="$evidence_written_events_identity"
    done
    capture_evidence_identities=false
    staged_file_identities="${captured_evidence_identities%$'\n'}"
    if (( validation_status != 0 )); then
        return "$validation_status"
    fi
    staged_identity=$(evidence_directory_identity "$success_staging_root" 755) || return 70
    staged_events_identity=$(evidence_directory_identity "$success_staging_root/events" 755) || return 70
    validate_runtime_evidence "$success_staging_root" || return $?
    validate_evidence_file_identities "$success_staging_root" "$staged_file_identities" \
        || return 70
    if (( $+functions[observer_evidence_final_postcondition_test_hook] )); then
        observer_evidence_final_postcondition_test_hook "$success_staging_root" || return 70
    fi
    if (( $+functions[observer_evidence_before_commit_test_hook] )); then
        observer_evidence_before_commit_test_hook "$evidence_root" "$success_staging_root"
    fi
    current=$(evidence_directory_identity "$parent" "$parent_mode") || return 70
    [[ "$current" == "$parent_identity" ]] || return 70
    current=$(evidence_directory_identity "$evidence_root" 755) || return 70
    [[ "$current" == "$root_identity" ]] || return 70
    current=$(evidence_directory_identity "$evidence_root/events" 755) || return 70
    [[ "$current" == "$events_identity" ]] || return 70
    current=$(evidence_directory_identity "$success_staging_root" 755) || return 70
    [[ "$current" == "$staged_identity" ]] || return 70
    current=$(evidence_directory_identity "$success_staging_root/events" 755) || return 70
    [[ "$current" == "$staged_events_identity" ]] || return 70
    validate_evidence_file_identities "$evidence_root" "$retained_file_identities" || return 70
    validate_evidence_file_identities "$success_staging_root" "$staged_file_identities" || return 70
    validate_runtime_evidence "$evidence_root" pending || return $?
    validate_runtime_evidence "$success_staging_root" || return $?
    if (( $+functions[observer_evidence_commit_test_hook] )); then
        observer_evidence_commit_test_hook "$parent" "$retained_name" "$staged_name" || return 70
    fi
    quarantine_name=".${retained_name}.pending.${staged_name##*.}"
    evidence_failure_safe_quarantine_root="$parent/$quarantine_name"
    move_pinned_evidence_tree_to_absent_name "$parent" "$parent_identity" "$retained_name" \
        "$root_identity" "$events_identity" "$retained_file_identities" \
        "$quarantine_name" pending || return $?
    evidence_commit_reconciliation_state=absent_authority
    evidence_commit_cleanup_state=retained_failure_safe
    if (( $+functions[observer_evidence_cleanup_test_hook] )); then
        observer_evidence_cleanup_test_hook "$evidence_failure_safe_quarantine_root" || {
            recover_failure_safe_authority "$parent" "$parent_identity" "$evidence_root" || true
            return 70
        }
    fi
    cleanup_pinned_evidence_tree "$evidence_failure_safe_quarantine_root" \
        "$root_identity" "$events_identity" \
        "$retained_file_identities" || {
        recover_failure_safe_authority "$parent" "$parent_identity" "$evidence_root" || true
        return 70
    }
    evidence_failure_safe_quarantine_root=""
    current=$(evidence_directory_identity "$parent" "$parent_mode") || return 70
    [[ "${current%|*}" == "${parent_identity%|*}" ]] || return 70
    parent_identity="$current"
    run_final_publication_test_hook "$evidence_post_swap_reserve_seconds" || hook_status=$?
    evidence_commit_helper_status="$hook_status"
    if (( hook_status != 0 )); then
        reconcile_unpublished_evidence "$parent" "$parent_identity" "$retained_name" \
            "$staged_name" "$staged_identity" "$staged_events_identity" \
            "$staged_file_identities" || true
        return "$hook_status"
    fi
    reconcile_unpublished_evidence "$parent" "$parent_identity" "$retained_name" \
        "$staged_name" "$staged_identity" "$staged_events_identity" \
        "$staged_file_identities" || return $?
    if (( $+functions[observer_evidence_final_move_test_hook] )); then
        observer_evidence_final_move_test_hook "$parent" "$retained_name" "$staged_name" \
            || return 70
    fi
    move_pinned_evidence_tree_to_absent_name "$parent" "$parent_identity" "$staged_name" \
        "$staged_identity" "$staged_events_identity" "$staged_file_identities" \
        "$retained_name" complete || return $?
    evidence_commit_reconciliation_state=published
    evidence_commit_cleanup_state=complete
    success_staging_root=""
}

finalize_controller() {
    local evidence_root="$1" cleanup_failed=false
    [[ "$terminal_finalizing" == false && "$terminal_finalized" == false ]] || return 70
    terminal_finalizing=true
    cleanup_started=true
    stop_supervisor || cleanup_failed=true
    cleanup_run_root || cleanup_failed=true
    stop_guard || cleanup_failed=true
    if [[ "$cleanup_failed" == true ]]; then
        cleanup_state=incomplete_retained
        record_terminal cleanup_uncertain cleanup 70
    else
        cleanup_state=complete
    fi
    if write_runtime_evidence "$evidence_root"; then
        evidence_write_state=complete
    else
        evidence_write_state=failed_retained
        record_terminal evidence_write_failed evidence 74
    fi
    terminal_finalized=true
    terminal_finalizing=false
    run_id=""; task_home=""; task_home_identity=""; derived_data=""
    derived_data_identity=""; temporary_root=""
    return "$terminal_exit_status"
}

finalize_unexpected_exit() {
    local incoming_status=$?
    trap - EXIT INT TERM
    (( incoming_status != 0 )) || incoming_status=70
    if [[ "$terminal_finalized" == false && "$terminal_finalizing" == false ]]; then
        [[ "$terminal_class" != still_unknown ]] || \
            record_terminal metadata_uncertain controller "$incoming_status"
        finalize_controller "$durable_evidence_root" || incoming_status=$?
    fi
    exit "$incoming_status"
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
    run_metadata_probe /bin/cp -p "$source" "$configured_xctestrun" >/dev/null || return 70
    run_metadata_probe /bin/chmod 600 "$configured_xctestrun" >/dev/null || return 70
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
    local hosted="$5" hosted_compare="$6" stream="$7" results="$8"
    local owner="$9" scopes="${10}" cleanup_state="${11}" concurrent="${12}"
    if [[ "$preexisting" != clear ]]; then print -r -- environment_conflict
    elif [[ "$guard" != continuous ]]; then print -r -- guard_discontinuity
    elif [[ "$build" != passed ]]; then print -r -- build_failed
    elif [[ "$build_compare" == uncertain ]]; then print -r -- metadata_uncertain
    elif [[ "$build_compare" == changed && "$concurrent" != clear ]]; then print -r -- still_unknown
    elif [[ "$build_compare" == changed ]]; then print -r -- build_window_change_correlated
    elif [[ "$hosted_compare" == uncertain ]]; then print -r -- metadata_uncertain
    elif [[ "$hosted_compare" == changed && "$concurrent" != clear ]]; then print -r -- still_unknown
    elif [[ "$hosted_compare" == changed && "$stream" == valid && "$results" == all_succeeded &&
            "$scopes" == outside_only ]]; then
        print -r -- run_owned_canonical_recovery_write_correlated
    elif [[ "$hosted_compare" == changed ]]; then print -r -- still_unknown
    elif [[ "$concurrent" != clear ]]; then print -r -- environment_conflict
    elif [[ "$stream" != valid ]]; then print -r -- observer_invalid
    elif [[ "$results" == all_succeeded &&
            ( "$scopes" == outside_only || "$scopes" == outside_or_indeterminate ) ]]; then
        print -r -- evidence_conflict
    elif [[ "$results" != none ]]; then print -r -- hosted_test_failed
    elif [[ "$hosted" != passed ]]; then print -r -- hosted_test_failed
    elif [[ "$cleanup_state" != certain ]]; then print -r -- cleanup_uncertain
    elif [[ "$owner" == observed ]]; then print -r -- owner_exposed_no_mutation
    else print -r -- pass_unchanged
    fi
}

validate_observer_stream() {
    local stream="$1" expected_run_id="$2" output_mode="${3:-facts}"
    run_metadata_probe /usr/bin/python3 - "$stream" "$expected_run_id" "$output_mode" <<'PY'
import json, pathlib, sys, uuid
prefix = "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "
path = pathlib.Path(sys.argv[1])
expected_run_id = sys.argv[2]
output_mode = sys.argv[3]
if output_mode not in {"facts", "events"}: raise SystemExit(65)
try: expected_uuid = uuid.UUID(expected_run_id)
except (ValueError, TypeError, AttributeError): raise SystemExit(65)
if str(expected_uuid) != expected_run_id: raise SystemExit(65)
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
def closed_object(pairs):
    names = [key for key, _ in pairs]
    if len(names) != len(set(names)): raise ValueError("duplicate")
    return dict(pairs)
for number, line in enumerate(lines, 1):
    if len(line.encode()) > 512: raise SystemExit(65)
    try:
        pairs = json.loads(line[len(prefix):], object_pairs_hook=lambda value: value)
        if not isinstance(pairs, list) or [key for key, _ in pairs] != keys: raise SystemExit(65)
        value = closed_object(pairs)
    except (json.JSONDecodeError, ValueError, TypeError): raise SystemExit(65)
    if type(value["schema_version"]) is not int or value["schema_version"] != 1: raise SystemExit(65)
    if type(value["sequence"]) is not int or value["sequence"] != number: raise SystemExit(65)
    if value["case_id"] != "protected_metadata": raise SystemExit(65)
    try: parsed = uuid.UUID(value["run_id"])
    except (ValueError, TypeError, AttributeError): raise SystemExit(65)
    if str(parsed) != value["run_id"] or value["run_id"] != expected_run_id: raise SystemExit(65)
    if value["event"] not in allowed_events or value["action"] not in allowed_actions or value["category"] not in allowed_categories or value["target_scope"] not in allowed_scopes or value["result"] not in allowed_results: raise SystemExit(65)
    values.append(value)
ready = values[0]
if sum(value["event"] == "observer_ready" for value in values) != 1: raise SystemExit(65)
if (ready["event"], ready["action"], ready["category"], ready["target_scope"], ready["result"]) != ("observer_ready", "none", "observer", "not_applicable", "ready"): raise SystemExit(65)
category_by_action = {
 "ensure_recovery_directory": "recovery_directory", "copy_recovery_audio": "recovery_audio",
 "replace_recovery_index": "recovery_index", "write_saved_state_marker": "recovery_marker",
 "write_processing_checkpoint_marker": "recovery_marker", "write_provider_dispatch_marker": "recovery_marker",
 "delete_saved_state_marker": "recovery_marker", "delete_processing_checkpoint_marker": "recovery_marker",
 "delete_provider_dispatch_marker": "recovery_marker", "delete_recovery_audio": "recovery_audio"}
owner_count = 0
pairs = []
index = 1
while index < len(values):
    value = values[index]
    if value["event"] in {"observer_ready", "observer_overflow", "mutation_end"}: raise SystemExit(65)
    if value["event"] == "owner_initialized":
        owner_count += 1
        if owner_count != 1 or pairs: raise SystemExit(65)
        if value["action"] != "none" or value["category"] != "recovery_directory" or value["target_scope"] == "not_applicable" or value["result"] != "observed": raise SystemExit(65)
        index += 1
        continue
    if value["event"] != "mutation_begin" or owner_count != 1: raise SystemExit(65)
    if value["action"] == "none" or category_by_action.get(value["action"]) != value["category"] or value["target_scope"] == "not_applicable" or value["result"] != "attempted": raise SystemExit(65)
    if index + 1 >= len(values): raise SystemExit(65)
    ending = values[index + 1]
    if ending["event"] != "mutation_end" or ending["result"] not in {"succeeded", "failed"}: raise SystemExit(65)
    if any(ending[key] != value[key] for key in ("action", "category", "target_scope")): raise SystemExit(65)
    pairs.append((ending["result"], ending["target_scope"]))
    index += 2
results = "none" if not pairs else ("all_succeeded" if all(result == "succeeded" for result, _ in pairs) else "failed")
scopes = "none"
if pairs:
    scope_values = {scope for _, scope in pairs}
    if scope_values == {"outside_private_task_home"}: scopes = "outside_only"
    elif scope_values == {"private_task_home"}: scopes = "private_only"
    else: scopes = "outside_or_indeterminate"
owner = "observed" if owner_count == 1 else "absent"
if output_mode == "facts": print("valid", results, owner, scopes)
else:
    for value in values:
        print(prefix + json.dumps(value, separators=(",", ":"), ensure_ascii=True))
PY
}

classify_observer_stream_result() {
    local stream="$1" expected_run_id="$2" build_compare="$3"
    local hosted_state="$4" hosted_compare="$5" concurrent_state="$6" parser_output
    local stream_state=invalid mutation_results=none owner_state=absent scope_state=none
    local -a facts
    parser_output=$(validate_observer_stream "$stream" "$expected_run_id" 2>/dev/null) || true
    facts=(${=parser_output})
    if (( ${#facts} == 4 )); then
        stream_state="${facts[1]}"; mutation_results="${facts[2]}"
        owner_state="${facts[3]}"; scope_state="${facts[4]}"
    fi
    classify_observer_result clear continuous passed "$build_compare" "$hosted_state" \
        "$hosted_compare" "$stream_state" "$mutation_results" "$owner_state" \
        "$scope_state" certain "$concurrent_state"
}

run_controller() {
    local baseline after_build after_hosted build_compare hosted_compare
    local hosted_state=passed concurrent_state=clear
    validate_controller || { record_terminal guard_discontinuity controller 70; return 0; }
    /usr/bin/caffeinate -dimsu -w $$ &
    guard_pid=$!
    guard_identity=$(process_identity "$guard_pid") || {
        record_terminal guard_discontinuity guard 70; return 0
    }
    validate_guard || { record_terminal guard_discontinuity guard 70; return 0; }
    run_root=$(run_metadata_probe /usr/bin/mktemp -d \
        /private/tmp/holdtype-dev-vlogs-observer.XXXXXXXX) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    run_metadata_probe /bin/chmod 700 "$run_root" >/dev/null || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    run_root_identity=$(identity "$run_root" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    task_home="$run_root/home"; temporary_root="$task_home/tmp"; derived_data="$task_home/DerivedData"
    bin_root="$run_root/bin"; logs_root="$run_root/logs"; probe="$bin_root/probe"
    run_metadata_probe /bin/mkdir -m 700 "$task_home" "$temporary_root" "$derived_data" \
        "$bin_root" "$logs_root" >/dev/null || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    run_root_identity=$(identity "$run_root" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    task_home_identity=$(identity "$task_home" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    derived_data_identity=$(identity "$derived_data" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    temporary_root_identity=$(identity "$temporary_root" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    bin_root_identity=$(identity "$bin_root" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    logs_root_identity=$(identity "$logs_root" 700) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    run_id=$(run_metadata_probe /usr/bin/uuidgen) || {
        record_terminal metadata_uncertain setup 70; return 0
    }
    run_id="${run_id:l}"
    run_bounded_to_log 60 "$logs_root/probe-build.log" \
        /usr/bin/clang -std=c11 -Wall -Wextra -Werror -O2 \
        "$script_directory/dev_vlogs_phase_0_b_protected_storage_probe.c" -o "$probe" \
        || {
        record_terminal build_failed probe_build 70; return 0
    }
    run_metadata_probe /bin/chmod 700 "$probe" >/dev/null || {
        record_terminal metadata_uncertain probe_build 70; return 0
    }
    probe_identity=$(regular_file_identity "$probe" 700) || {
        record_terminal metadata_uncertain probe_build 70; return 0
    }
    validate_roots || { record_terminal metadata_uncertain setup 70; return 0; }
    product_census_clear || { record_terminal environment_conflict baseline 70; return 0; }
    baseline=$(probe_snapshot) || { record_terminal metadata_uncertain baseline 70; return 0; }
    run_bounded_to_log 600 "$logs_root/build.log" \
        /usr/bin/xcodebuild -project "$repository_root/HoldType.xcodeproj" \
        -scheme HoldType -configuration Debug -destination 'platform=macOS' \
        -derivedDataPath "$derived_data" build-for-testing \
        || {
        record_terminal build_failed build 70; return 0
    }
    product_census_clear || concurrent_state=uncertain
    after_build=$(probe_snapshot) || { record_terminal metadata_uncertain build 70; return 0; }
    build_compare=$(compare_snapshot "$baseline" "$after_build"); build_comparison="$build_compare"
    [[ "$build_compare" == unchanged || "$build_compare" == missing_unchanged ]] || {
        local build_terminal
        build_terminal=$(classify_observer_result clear continuous passed "$build_compare" \
            passed unchanged valid none absent none certain "$concurrent_state")
        record_terminal "$build_terminal" build 70
        return 0
    }
    [[ "$concurrent_state" == clear ]] || {
        record_terminal environment_conflict build 70; return 0
    }
    if (( $+functions[observer_before_hosted_validation_test_hook] )); then
        observer_before_hosted_validation_test_hook
    fi
    validate_roots || { record_terminal metadata_uncertain hosted_setup 70; return 0; }
    configure_hosted_xctestrun || {
        record_terminal hosted_test_failed hosted_setup 70; return 0
    }
    run_bounded_to_log 180 "$logs_root/hosted.log" \
        /usr/bin/xcodebuild -xctestrun "$configured_xctestrun" \
        -destination 'platform=macOS' -parallel-testing-enabled NO \
        -resultBundlePath "$logs_root/hosted.xcresult" test-without-building \
        -only-testing:HoldTypeTests/DevVlogsPhase0BProtectedStorageObserverHostedTests \
        || hosted_state=failed
    product_census_clear || concurrent_state=uncertain
    after_hosted=$(probe_snapshot) || {
        record_terminal metadata_uncertain hosted 70; return 0
    }
    hosted_compare=$(compare_snapshot "$after_build" "$after_hosted"); hosted_comparison="$hosted_compare"
    retained_observer_events=""
    if retained_observer_events=$(validate_observer_stream "$logs_root/hosted.log" \
        "$run_id" events 2>/dev/null); then
        [[ -z "$retained_observer_events" ]] || retained_observer_events+=$'\n'
    else
        retained_observer_events=""
    fi
    local hosted_terminal hosted_status=70
    hosted_terminal=$(classify_observer_stream_result "$logs_root/hosted.log" "$run_id" \
        "$build_compare" "$hosted_state" "$hosted_compare" "$concurrent_state")
    unset baseline after_build after_hosted
    [[ "$hosted_terminal" == pass_unchanged || \
       "$hosted_terminal" == owner_exposed_no_mutation ]] && hosted_status=0
    record_terminal "$hosted_terminal" hosted "$hosted_status"
    return 0
}

outer_supervise() {
    "$timeout_executable" --foreground --signal=TERM \
        --kill-after="${outer_kill_after_seconds}s" "${outer_timeout_seconds}s" "$@" 2>/dev/null
}

emit_controller_terminal() {
    local terminal_status="$1"
    if (( terminal_status == 0 )) && [[ "$cleanup_state" == complete &&
          "$evidence_write_state" == complete &&
          "$evidence_commit_cleanup_state" == complete && -z "$success_staging_root" &&
          -z "$evidence_failure_safe_quarantine_root" &&
          -z "$evidence_recovery_staging_root" ]]; then
        print -r -- "protected_storage_observer result=$terminal_class cleanup=complete"
        return 0
    fi
    (( terminal_status != 0 )) && return "$terminal_status"
    return 74
}

run_inner_controller() {
    deadline=$(( SECONDS + 900 ))
    durable_evidence_root="$repository_root/docs/qa/runs/dev-vlogs-phase-0b-storage-observer-r01"
    trap finalize_unexpected_exit EXIT
    trap 'record_terminal guard_discontinuity signal 130; exit 130' INT
    trap 'record_terminal guard_discontinuity signal 143; exit 143' TERM
    if ! pin_controller; then
        record_terminal guard_discontinuity controller 70
    elif ! cd "$repository_root"; then
        record_terminal metadata_uncertain controller 70
    else
        run_controller
    fi
    local final_status=0
    finalize_controller "$durable_evidence_root" || final_status=$?
    trap - EXIT INT TERM
    emit_controller_terminal "$final_status"
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
    unset HTDV_OBSERVER_TEST_POST_SWAP HTDV_OBSERVER_TEST_POST_SWAP_RECONCILE \
        HTDV_OBSERVER_TEST_CLEANUP_FAIL_AFTER \
        HTDV_EVIDENCE_CONTENT HTDV_EVIDENCE_IDENTITIES
    if command -v timeout >/dev/null 2>&1; then timeout_executable=$(command -v timeout)
    elif command -v gtimeout >/dev/null 2>&1; then timeout_executable=$(command -v gtimeout)
    else fail "a bounded timeout command is required"
    fi
    set +e
    outer_supervise /bin/zsh -c '
        source "$1"
        script_directory="${1:A:h}"
        repository_root="${script_directory:h}"
        program_name="${1:t}"
        timeout_executable="$2"
        run_inner_controller
    ' protected-storage-observer-inner "$script_directory/$program_name" "$timeout_executable"
    controller_status=$?
    set -e
    if (( controller_status != 0 )); then
        print -u2 -r -- "error: protected storage observer controller failed"
    fi
    exit "$controller_status"
fi
