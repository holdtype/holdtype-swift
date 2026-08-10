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
run_root=""
resolved_temp_root=""
resolved_run_root=""
capture_supervisor_pid=""
hardware_preparation_pid=""
hardware_event_source=""
hardware_event_handoff=""
hardware_configuration_output=""
hardware_configuration_output_identity=""
hardware_configuration_descriptor_open=0
hardware_handoff_root=""
hardware_handoff_root_name=""
hardware_handoff_root_identity=""
hardware_snapshot_identity=""
hardware_snapshot_digest=""
hardware_handoff_retained=0
hardware_handoff_cleanup_forbidden=0
hardware_raw_cleanup_forbidden=0
hardware_raw_root_identity=""
hardware_evidence_worker_pid=""
hardware_evidence_worker_kind=""
hardware_publisher_output=""
consumer_root_token=""
consumer_root_device=""
consumer_root_inode=""
consumer_snapshot_device=""
consumer_snapshot_inode=""
consumer_snapshot_digest=""
termination_signal_status=""
termination_cleanup_completed=0
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
    print -r -- "usage: $program_name [--help|--build-only|--request-camera-permission|--hardware --camera-id ID [--duration SECONDS] [--case-id ID]|--consume-hardware-evidence --root-token TOKEN --root-device N --root-inode N --snapshot-device N --snapshot-inode N --snapshot-sha256 HEX --case-id ID]"
    print -r -- ""
    print -r -- "--build-only  compile the Debug harness without launching camera or microphone"
    print -r -- "--request-camera-permission  explicitly request Camera access without starting capture"
    print -r -- "--hardware    explicit future hardware mode; never implied by another option"
    print -r -- "--consume-hardware-evidence  validate, consume once, and clean one retained Debug snapshot"
}

hardware_evidence_handoff_source=$(cat <<'PY'
import json
import hashlib
import math
import os
import re
import stat
import sys
import time

MAX_BYTES = 262_144
OPEN_DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
BASE_KEYS = {"runID", "caseID", "attemptID", "monotonicMilliseconds", "action", "result", "metrics"}
CONFIGURATION_KEYS = {"schema", "caseID", "result", "category", "configuration_stage"}
CONFIGURATION_STAGES = {
    "isolation_not_enabled", "automation_not_enabled", "keychain_ui_not_suppressed",
    "run_root_missing", "event_log_missing", "camera_id_missing",
    "run_root_outside_temporary_root", "event_log_path_mismatch", "duration_invalid",
    "case_id_invalid", "run_paths_unavailable", "unknown",
}
STAGE_KEYS = {
    "cameraProbePassed", "passthroughCompleted", "finalProbePassed", "cameraMediaSubtype",
    "finalizedMediaSubtype", "finalizedAudioMediaSubtype", "cameraFormat", "finalizedFormat",
}
VIDEO_KEYS = {
    "cameraMediaSubtype", "finalizedMediaSubtype", "finalizedAudioMediaSubtype", "cameraFormat",
    "finalizedFormat", "preservationMethod", "preservedSampleCount", "preservedEncodedByteCount",
    "matched",
}
HARDWARE_FAILURES = {
    "audio_start", "camera_permission_required", "camera_permission_denied",
    "camera_selection_disconnected", "camera_start_device_unavailable", "camera_selection_busy",
    "camera_configuration_video_input", "camera_configuration_movie_output",
    "camera_configuration_sample_output", "camera_start_timed_out", "camera_first_frame_unavailable",
    "camera_recording_failed", "camera_interruption_disconnected", "camera_session_runtime_failure",
    "camera_session_not_capturing", "camera_unknown", "capture_stop", "camera_probe",
    "passthrough_incompatible", "passthrough_export_failed", "finalization", "final_probe",
}
PRESERVATION_DIMENSIONS = {
    "expected_one_video_track", "reader_unavailable", "reading_failed", "sample_count_mismatch",
    "sample_boundary_mismatch", "encoded_payload_mismatch", "sample_duration_mismatch",
    "presentation_timestamp_mismatch", "decode_timestamp_mismatch", "format_description_mismatch",
    "dimensions_mismatch", "transform_mismatch", "cancelled", "timed_out", "unknown",
}
CASE_IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,64}")
UUID_IDENTIFIER = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
)
FORMAT = re.compile(
    r"[ -~]{4}:[1-9][0-9]{0,5}x[1-9][0-9]{0,5}:descriptions_[1-9][0-9]{0,3}"
)
SUBTYPE = re.compile(r"[ -~]{4}")
ROOT_NAME = re.compile(r"holdtype-dv-p0b\.[A-Za-z0-9]{6,32}")
HANDOFF_NAME = re.compile(r"holdtype-dv-p0b-handoff\.[A-Za-z0-9]{6,32}")

def fail():
    raise RuntimeError("invalid")

def identity(value):
    return (value.st_dev, value.st_ino, value.st_uid, stat.S_IFMT(value.st_mode),
            stat.S_IMODE(value.st_mode))

def exact_keys(value, keys):
    if not isinstance(value, dict) or set(value) != keys:
        fail()

def integer(value, minimum=0, maximum=(1 << 63) - 1):
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        fail()
    return value

def safe_string(value, pattern):
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        fail()
    return value

def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            fail()
        value[key] = item
    return value

def parse_event(line):
    try:
        return json.loads(line, object_pairs_hook=unique_object, parse_constant=lambda _: fail())
    except (UnicodeDecodeError, json.JSONDecodeError, RuntimeError, ValueError):
        fail()

def validate_configuration(payload, expected_case):
    if not payload.endswith(b"\n") or payload.count(b"\n") != 1:
        fail()
    value = parse_event(payload[:-1])
    exact_keys(value, CONFIGURATION_KEYS)
    safe_string(value["caseID"], CASE_IDENTIFIER)
    if (value["schema"] != "dev_vlogs_phase_0b_configuration_v1"
            or value["caseID"] != expected_case or value["result"] != "failed"
            or value["category"] != "invalid_configuration"
            or value["configuration_stage"] not in CONFIGURATION_STAGES):
        fail()
    return value["result"], value["category"], value["configuration_stage"]

def metric_rules():
    rules = {
        "camera_video_duration": ("s", "evidence_only", 1e-12, 86400.0, False),
        "final_video_duration": ("s", "evidence_only", 1e-12, 86400.0, False),
        "audio_duration": ("s", "evidence_only", 1e-12, 86400.0, False),
        "camera_request_to_first_frame": ("ms", "evidence_only", 0.0, 1_000_000.0, False),
        "preserved_sample_count": ("samples", "functional", 1.0, 1_000_000_000.0, True),
        "preserved_encoded_bytes": ("bytes", "functional", 1.0, 1_000_000_000_000_000.0, True),
    }
    for prefix in ("camera", "final", "audio"):
        for suffix in ("width", "height", "display_width", "display_height"):
            rules[f"{prefix}_{suffix}"] = ("px", "evidence_only", 1e-12, 100_000.0, False)
        rules[f"{prefix}_nominal_fps"] = ("fps", "evidence_only", 0.0, 1_000.0, False)
        rules[f"{prefix}_derived_fps"] = ("fps", "evidence_only", 1e-12, 1_000.0, False)
        for suffix in ("start_timestamp", "end_timestamp"):
            rules[f"{prefix}_{suffix}"] = ("s", "evidence_only", -86_400.0, 86_400.0, False)
        rules[f"{prefix}_estimated_data_rate"] = ("bps", "evidence_only", 0.0, 1e15, False)
        for suffix in ("transform_a", "transform_b", "transform_c", "transform_d"):
            rules[f"{prefix}_{suffix}"] = ("coefficient", "evidence_only", -100.0, 100.0, False)
    return rules

METRIC_RULES = metric_rules()

def validate_metrics(metrics, result_kind):
    if not isinstance(metrics, list) or len(metrics) > 80:
        fail()
    seen = {}
    for metric in metrics:
        exact_keys(metric, {"name", "value", "unit", "disposition"})
        name = metric["name"]
        if name not in METRIC_RULES or name in seen:
            fail()
        unit, disposition, minimum, maximum, integral = METRIC_RULES[name]
        value = metric["value"]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            fail()
        if not minimum <= value <= maximum or (integral and int(value) != value):
            fail()
        if metric["unit"] != unit or metric["disposition"] != disposition:
            fail()
        seen[name] = value
    if result_kind == "start" and seen:
        fail()
    if result_kind == "ordinary_failure" and seen:
        fail()
    video_required = set()
    for prefix in ("camera", "final"):
        video_required.update({
            f"{prefix}_width", f"{prefix}_height", f"{prefix}_display_width",
            f"{prefix}_display_height", f"{prefix}_start_timestamp",
            f"{prefix}_end_timestamp", f"{prefix}_estimated_data_rate",
            f"{prefix}_transform_a", f"{prefix}_transform_b", f"{prefix}_transform_c",
            f"{prefix}_transform_d",
        })
    audio_required = {"audio_start_timestamp", "audio_end_timestamp", "audio_estimated_data_rate"}
    video_allowed = video_required | {
        "camera_nominal_fps", "camera_derived_fps", "final_nominal_fps", "final_derived_fps",
    }
    if result_kind == "ready":
        for prefix in ("camera", "final"):
            nominal = seen.get(f"{prefix}_nominal_fps")
            derived = seen.get(f"{prefix}_derived_fps")
            if not ((nominal is not None and nominal > 0) or derived is not None):
                fail()
        required = video_required | audio_required | {
            "camera_video_duration", "final_video_duration", "audio_duration",
            "preserved_sample_count", "preserved_encoded_bytes",
        }
        allowed = video_allowed | audio_required | {
            "camera_video_duration", "final_video_duration", "audio_duration",
            "preserved_sample_count", "preserved_encoded_bytes", "camera_request_to_first_frame",
        }
        if not required.issubset(seen) or not set(seen).issubset(allowed):
            fail()
    if result_kind == "preservation":
        for prefix in ("camera", "final"):
            nominal = seen.get(f"{prefix}_nominal_fps")
            derived = seen.get(f"{prefix}_derived_fps")
            if not ((nominal is not None and nominal > 0) or derived is not None):
                fail()
        required = video_required | audio_required
        if (not required.issubset(seen) or not set(seen).issubset(video_allowed | audio_required)
                or any(name.startswith("preserved_") for name in seen)):
            fail()
        if any(name in seen for name in {
            "camera_video_duration", "final_video_duration", "audio_duration",
            "camera_request_to_first_frame",
        }):
            fail()
    for prefix in ("camera", "final", "audio"):
        start = seen.get(f"{prefix}_start_timestamp")
        end = seen.get(f"{prefix}_end_timestamp")
        if start is not None and end is not None and end < start:
            fail()
    return seen

def validate_stage(value):
    exact_keys(value, STAGE_KEYS)
    if any(value[name] is not True for name in
           ("cameraProbePassed", "passthroughCompleted", "finalProbePassed")):
        fail()
    safe_string(value["cameraMediaSubtype"], SUBTYPE)
    safe_string(value["finalizedMediaSubtype"], SUBTYPE)
    safe_string(value["finalizedAudioMediaSubtype"], SUBTYPE)
    safe_string(value["cameraFormat"], FORMAT)
    safe_string(value["finalizedFormat"], FORMAT)

def validate_video(value, metrics):
    exact_keys(value, VIDEO_KEYS)
    safe_string(value["cameraMediaSubtype"], SUBTYPE)
    safe_string(value["finalizedMediaSubtype"], SUBTYPE)
    safe_string(value["finalizedAudioMediaSubtype"], SUBTYPE)
    safe_string(value["cameraFormat"], FORMAT)
    safe_string(value["finalizedFormat"], FORMAT)
    if value["preservationMethod"] != "stored_sample_exact_v1" or value["matched"] is not True:
        fail()
    count = integer(value["preservedSampleCount"], 1, 1_000_000_000)
    encoded = integer(value["preservedEncodedByteCount"], 1, 1_000_000_000_000_000)
    if metrics["preserved_sample_count"] != count or metrics["preserved_encoded_bytes"] != encoded:
        fail()

def validate_events(payload, expected_case):
    if not payload.endswith(b"\n") or payload.count(b"\n") != 2:
        fail()
    events = [parse_event(line) for line in payload.splitlines()]
    start, terminal = events
    exact_keys(start, BASE_KEYS)
    safe_string(start["runID"], UUID_IDENTIFIER)
    safe_string(start["attemptID"], UUID_IDENTIFIER)
    safe_string(start["caseID"], CASE_IDENTIFIER)
    if start["caseID"] != expected_case or start["action"] != "attempt" or start["result"] != "started":
        fail()
    started_at = integer(start["monotonicMilliseconds"])
    validate_metrics(start["metrics"], "start")
    if not BASE_KEYS.issubset(terminal):
        fail()
    for key in ("runID", "attemptID"):
        safe_string(terminal[key], UUID_IDENTIFIER)
        if terminal[key] != start[key]:
            fail()
    safe_string(terminal["caseID"], CASE_IDENTIFIER)
    if terminal["caseID"] != start["caseID"]:
        fail()
    if terminal["action"] != "attempt_terminal":
        fail()
    if integer(terminal["monotonicMilliseconds"]) < started_at:
        fail()
    result = terminal["result"]
    if result == "ready":
        exact_keys(terminal, BASE_KEYS | {"deviceClass", "redactedDeviceLabel", "videoEvidence"})
        if terminal["deviceClass"] not in {"built_in", "external", "continuity", "unknown"}:
            fail()
        if terminal["redactedDeviceLabel"] != terminal["deviceClass"] + "_camera":
            fail()
        metrics = validate_metrics(terminal["metrics"], "ready")
        validate_video(terminal["videoEvidence"], metrics)
        return result, "none", "none"
    if terminal.get("category") == "video_preservation_failed":
        exact_keys(terminal, BASE_KEYS | {
            "category", "preservation_failure_dimension", "failure_stage_evidence"})
        dimension = terminal["preservation_failure_dimension"]
        if dimension not in PRESERVATION_DIMENSIONS:
            fail()
        expected_result = "cancelled" if dimension == "cancelled" else (
            "timed_out" if dimension == "timed_out" else "failed")
        if result != expected_result:
            fail()
        validate_metrics(terminal["metrics"], "preservation")
        validate_stage(terminal["failure_stage_evidence"])
        return result, terminal["category"], dimension
    exact_keys(terminal, BASE_KEYS | {"category"})
    category = terminal["category"]
    if category not in HARDWARE_FAILURES:
        fail()
    if result != "failed" and not (result == "cancelled" and category == "capture_stop"):
        fail()
    validate_metrics(terminal["metrics"], "ordinary_failure")
    return result, terminal["category"], "none"

def walk_absolute(path):
    if not os.path.isabs(path) or os.path.normpath(path) != path:
        fail()
    descriptor = os.open("/", OPEN_DIRECTORY)
    identities = [identity(os.fstat(descriptor))]
    try:
        for component in [part for part in path.split("/") if part]:
            next_descriptor = os.open(component, OPEN_DIRECTORY, dir_fd=descriptor)
            value = os.fstat(next_descriptor)
            if not stat.S_ISDIR(value.st_mode):
                os.close(next_descriptor)
                fail()
            os.close(descriptor)
            descriptor = next_descriptor
            identities.append(identity(value))
        return descriptor, tuple(identities)
    except Exception:
        os.close(descriptor)
        raise

def open_owned_directory(parent, name, expected_uid=None):
    if expected_uid is None:
        expected_uid = os.getuid()
    descriptor = os.open(name, OPEN_DIRECTORY, dir_fd=parent)
    value = os.fstat(descriptor)
    if (not stat.S_ISDIR(value.st_mode) or value.st_uid != expected_uid
            or stat.S_IMODE(value.st_mode) != 0o700):
        os.close(descriptor)
        fail()
    return descriptor, identity(value)

def reopen_matches(parent, name, wanted):
    descriptor, observed = open_owned_directory(parent, name)
    os.close(descriptor)
    if observed != wanted:
        fail()

def apply_mutation(name, base, raw_root, raw_name, raw_media, source, handoff, handoff_name):
    if name == "add_after_list":
        fd = os.open("unexpected.jsonl", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=source)
        os.close(fd)
    elif name == "remove_after_list":
        os.unlink("events.jsonl", dir_fd=source)
    elif name == "source_replacement":
        os.rename("events.jsonl", "events-old", src_dir_fd=source, dst_dir_fd=source)
        fd = os.open("events.jsonl", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=source)
        os.write(fd, b"{}\n")
        os.close(fd)
        os.unlink("events-old", dir_fd=source)
    elif name == "source_parent_swap":
        os.rename("evidence", "evidence-old", src_dir_fd=raw_media, dst_dir_fd=raw_media)
        os.mkdir("evidence", 0o700, dir_fd=raw_media)
    elif name == "raw_root_swap":
        os.rename(raw_name, raw_name + "original", src_dir_fd=base, dst_dir_fd=base)
        os.mkdir(raw_name, 0o700, dir_fd=base)
    elif name == "destination_parent_swap":
        os.rename(handoff_name, handoff_name + "original", src_dir_fd=base, dst_dir_fd=base)
        os.mkdir(handoff_name, 0o700, dir_fd=base)
    elif name == "slow_validator":
        time.sleep(10)
    elif name == "slow_publisher_execution":
        print("hardware_evidence_publisher=pinned producer_pid=" + str(os.getpid()), flush=True)
        time.sleep(10)

def verify_bindings(base_path, base_identities, base, raw_name, raw_identity, raw_root,
                    media_identity, raw_media, source_identity, handoff_name, handoff_identity):
    check, observed = walk_absolute(base_path)
    os.close(check)
    if observed != base_identities:
        fail()
    reopen_matches(base, raw_name, raw_identity)
    reopen_matches(raw_root, "hardware-raw", media_identity)
    reopen_matches(raw_media, "evidence", source_identity)
    reopen_matches(base, handoff_name, handoff_identity)

def read_snapshot(descriptor):
    payload = b""
    while len(payload) <= MAX_BYTES:
        chunk = os.read(descriptor, min(65_536, MAX_BYTES + 1 - len(payload)))
        if not chunk:
            break
        payload += chunk
    if len(payload) > MAX_BYTES:
        fail()
    return payload

def digest(payload):
    return hashlib.sha256(payload).hexdigest()

def tokens_with_identity(parent, pattern, wanted):
    matches = []
    for name in os.listdir(parent):
        if pattern.fullmatch(name) is None:
            continue
        try:
            value = os.stat(name, dir_fd=parent, follow_symlinks=False)
        except OSError:
            continue
        if identity(value)[:2] == wanted:
            matches.append(name)
    return matches

def publish():
    base = raw_root = raw_media = source = handoff = event_fd = output_fd = None
    created_identity = None
    raw_identity = handoff_identity = None
    retention_reason = "publisher_validation_mismatch"
    handoff_name = os.environ.get("DV_HARDWARE_HANDOFF_ROOT_NAME", "unknown")
    raw_name = os.environ.get("DV_HARDWARE_RAW_ROOT_NAME", "unknown")
    try:
        base_path = os.environ["DV_HARDWARE_BASE"]
        if ROOT_NAME.fullmatch(raw_name) is None or HANDOFF_NAME.fullmatch(handoff_name) is None:
            fail()
        base, base_identities = walk_absolute(base_path)
        base_value = os.fstat(base)
        if base_value.st_uid != os.getuid() or stat.S_IMODE(base_value.st_mode) != 0o700:
            fail()
        raw_root, raw_identity = open_owned_directory(base, raw_name)
        raw_media, media_identity = open_owned_directory(raw_root, "hardware-raw")
        source, source_identity = open_owned_directory(raw_media, "evidence")
        mutation = os.environ.get("DV_HARDWARE_MUTATION", "")
        expected_handoff_uid = os.getuid() + 1 if mutation == "wrong_owner" else os.getuid()
        handoff, handoff_identity = open_owned_directory(base, handoff_name, expected_handoff_uid)
        if os.listdir(source) != ["events.jsonl"] or os.listdir(handoff):
            fail()
        event_fd = os.open("events.jsonl", os.O_RDONLY | os.O_NOFOLLOW, dir_fd=source)
        event_value = os.fstat(event_fd)
        if (not stat.S_ISREG(event_value.st_mode) or event_value.st_uid != os.getuid()
                or stat.S_IMODE(event_value.st_mode) != 0o600 or event_value.st_nlink != 1
                or not 0 < event_value.st_size <= MAX_BYTES):
            fail()
        apply_mutation(mutation, base, raw_root, raw_name, raw_media, source, handoff, handoff_name)
        payload = read_snapshot(event_fd)
        event_after = os.fstat(event_fd)
        if (len(payload) != event_value.st_size or identity(event_after) != identity(event_value)
                or event_after.st_size != event_value.st_size):
            fail()
        source_digest = digest(payload)
        if os.listdir(source) != ["events.jsonl"] or os.listdir(handoff):
            fail()
        rebound = os.open("events.jsonl", os.O_RDONLY | os.O_NOFOLLOW, dir_fd=source)
        try:
            if identity(os.fstat(rebound)) != identity(event_value):
                fail()
        finally:
            os.close(rebound)
        verify_bindings(base_path, base_identities, base, raw_name, raw_identity, raw_root,
                        media_identity, raw_media, source_identity, handoff_name, handoff_identity)
        retention_reason = "source_schema_mismatch"
        result, category, dimension = validate_events(payload, os.environ["DV_HARDWARE_CASE_ID"])
        if mutation == "same_size_mutation":
            writer = os.open("events.jsonl", os.O_WRONLY | os.O_NOFOLLOW, dir_fd=source)
            try:
                if identity(os.fstat(writer)) != identity(event_value):
                    fail()
                os.pwrite(writer, b" ", 0)
                os.fsync(writer)
            finally:
                os.close(writer)
        os.lseek(event_fd, 0, os.SEEK_SET)
        proof_payload = read_snapshot(event_fd)
        proof_value = os.fstat(event_fd)
        retention_reason = "source_digest_mismatch"
        if (proof_payload != payload or digest(proof_payload) != source_digest
                or identity(proof_value) != identity(event_value)
                or proof_value.st_size != event_value.st_size):
            fail()
        output_fd = os.open("events.jsonl", os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                            0o600, dir_fd=handoff)
        created_identity = identity(os.fstat(output_fd))
        view = memoryview(payload)
        while view:
            written = os.write(output_fd, view)
            if written <= 0:
                fail()
            view = view[written:]
        os.fsync(output_fd)
        os.fchmod(output_fd, 0o400)
        created_identity = identity(os.fstat(output_fd))
        if mutation == "published_digest_mismatch":
            os.pwrite(output_fd, b" ", 0)
            os.fsync(output_fd)
        elif mutation in {"published_identity_mismatch", "failed_output_replacement"}:
            os.rename("events.jsonl", "events-original", src_dir_fd=handoff, dst_dir_fd=handoff)
            replacement = os.open(
                "events.jsonl", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o400, dir_fd=handoff
            )
            os.write(replacement, payload)
            os.close(replacement)
        if mutation == "failed_output_replacement":
            retention_reason = "snapshot_identity_mismatch"
            fail()
        verify_bindings(base_path, base_identities, base, raw_name, raw_identity, raw_root,
                        media_identity, raw_media, source_identity, handoff_name, handoff_identity)
        os.lseek(output_fd, 0, os.SEEK_SET)
        pinned_snapshot = read_snapshot(output_fd)
        pinned_value = os.fstat(output_fd)
        if (identity(pinned_value) != created_identity or stat.S_IMODE(pinned_value.st_mode) != 0o400
                or pinned_value.st_nlink != 1 or pinned_snapshot != payload
                or digest(pinned_snapshot) != source_digest):
            retention_reason = "snapshot_digest_mismatch"
            fail()
        check = os.open("events.jsonl", os.O_RDONLY | os.O_NOFOLLOW, dir_fd=handoff)
        try:
            check_value = os.fstat(check)
            snapshot = read_snapshot(check)
            if (identity(check_value) != created_identity or snapshot != payload
                    or digest(snapshot) != source_digest):
                retention_reason = "snapshot_identity_mismatch"
                fail()
        finally:
            os.close(check)
        if os.listdir(source) != ["events.jsonl"] or os.listdir(handoff) != ["events.jsonl"]:
            fail()
        print("hardware_evidence_handoff=validated result=" + result + " category=" + category +
              " preservation_error=" + dimension + " root_token=" + handoff_name +
              " root_device=" + str(handoff_identity[0]) + " root_inode=" + str(handoff_identity[1]) +
              " snapshot_device=" + str(created_identity[0]) +
              " snapshot_inode=" + str(created_identity[1]) +
              " snapshot_sha256=" + source_digest +
              " file=events.jsonl cleanup=trusted_debug_consumer_once")
    except Exception:
        original_raw = ""
        original_handoff = ""
        if base is not None and raw_identity is not None:
            matches = tokens_with_identity(base, ROOT_NAME, raw_identity[:2])
            if len(matches) == 1 and matches[0] != raw_name:
                original_raw = matches[0]
        if base is not None and handoff_identity is not None:
            matches = tokens_with_identity(base, HANDOFF_NAME, handoff_identity[:2])
            if len(matches) == 1 and matches[0] != handoff_name:
                original_handoff = matches[0]
        print("hardware_evidence_publish=retained reason=" + retention_reason +
              " residual_class=raw_and_handoff raw_root_token=" + raw_name +
              " handoff_root_token=" + handoff_name +
              (" original_raw_root_token=" + original_raw if original_raw else "") +
              (" original_handoff_root_token=" + original_handoff if original_handoff else "") +
              " cleanup=retain_implicated")
        sys.exit(1)
    finally:
        for descriptor in (output_fd, event_fd, source, raw_media, raw_root, handoff, base):
            if descriptor is not None:
                try:
                    os.close(descriptor)
                except OSError:
                    pass

def publish_configuration():
    base = handoff = output = None
    try:
        base_path = os.environ["DV_HARDWARE_BASE"]
        handoff_name = os.environ["DV_HARDWARE_HANDOFF_ROOT_NAME"]
        case_id = os.environ["DV_HARDWARE_CASE_ID"]
        stage = os.environ["DV_HARDWARE_CONFIGURATION_STAGE"]
        if (HANDOFF_NAME.fullmatch(handoff_name) is None
                or CASE_IDENTIFIER.fullmatch(case_id) is None
                or stage not in CONFIGURATION_STAGES):
            fail()
        base, base_identities = walk_absolute(base_path)
        base_value = os.fstat(base)
        if base_value.st_uid != os.getuid() or stat.S_IMODE(base_value.st_mode) != 0o700:
            fail()
        handoff, handoff_identity = open_owned_directory(base, handoff_name)
        if os.listdir(handoff):
            fail()
        payload = (json.dumps({
            "schema": "dev_vlogs_phase_0b_configuration_v1", "caseID": case_id,
            "result": "failed", "category": "invalid_configuration",
            "configuration_stage": stage,
        }, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
        result, category, dimension = validate_configuration(payload, case_id)
        output = os.open("configuration.json", os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=handoff)
        output_identity = identity(os.fstat(output))
        if os.write(output, payload) != len(payload):
            fail()
        os.fsync(output)
        os.fchmod(output, 0o400)
        output_value = os.fstat(output)
        snapshot_digest = digest(payload)
        if (identity(output_value) != output_identity[:4] + (0o400,)
                or output_value.st_nlink != 1 or os.listdir(handoff) != ["configuration.json"]):
            fail()
        check_base, observed = walk_absolute(base_path)
        os.close(check_base)
        if observed != base_identities:
            fail()
        rebound, rebound_identity = open_owned_directory(base, handoff_name)
        os.close(rebound)
        if rebound_identity != handoff_identity:
            fail()
        check = os.open("configuration.json", os.O_RDONLY | os.O_NOFOLLOW, dir_fd=handoff)
        try:
            if identity(os.fstat(check)) != identity(output_value) or read_snapshot(check) != payload:
                fail()
        finally:
            os.close(check)
        print("hardware_configuration_handoff=validated result=" + result +
              " category=" + category + " configuration_stage=" + dimension +
              " root_token=" + handoff_name + " root_device=" + str(handoff_identity[0]) +
              " root_inode=" + str(handoff_identity[1]) +
              " snapshot_device=" + str(output_value.st_dev) +
              " snapshot_inode=" + str(output_value.st_ino) +
              " snapshot_sha256=" + snapshot_digest +
              " file=configuration.json cleanup=trusted_debug_consumer_once")
    except Exception:
        print("hardware_configuration_publish=failed reason=closed_validation_mismatch " +
              "cleanup=remove_owned")
        sys.exit(1)
    finally:
        for descriptor in (output, handoff, base):
            if descriptor is not None:
                try:
                    os.close(descriptor)
                except OSError:
                    pass

def consume():
    base = root = snapshot = None
    deleted = False
    root_observed = False
    expected_root_token = ""
    token = os.environ.get("DV_HARDWARE_HANDOFF_ROOT_NAME", "unknown")
    reason = "validation_mismatch"
    try:
        if HANDOFF_NAME.fullmatch(token) is None:
            fail()
        expected_root = (
            integer(int(os.environ["DV_HARDWARE_ROOT_DEVICE"])),
            integer(int(os.environ["DV_HARDWARE_ROOT_INODE"])),
        )
        expected_snapshot = (
            integer(int(os.environ["DV_HARDWARE_SNAPSHOT_DEVICE"])),
            integer(int(os.environ["DV_HARDWARE_SNAPSHOT_INODE"])),
        )
        expected_digest = os.environ["DV_HARDWARE_SNAPSHOT_SHA256"]
        if re.fullmatch(r"[0-9a-f]{64}", expected_digest) is None:
            fail()
        base, base_identities = walk_absolute(os.environ["DV_HARDWARE_BASE"])
        base_value = os.fstat(base)
        if base_value.st_uid != os.getuid() or stat.S_IMODE(base_value.st_mode) != 0o700:
            reason = "base_ownership_mismatch"
            fail()
        root, root_identity = open_owned_directory(base, token)
        root_observed = True
        if root_identity[:2] != expected_root:
            matches = tokens_with_identity(base, HANDOFF_NAME, expected_root)
            if len(matches) == 1:
                expected_root_token = matches[0]
            reason = "root_identity_mismatch"
            fail()
        names = os.listdir(root)
        if names not in (["events.jsonl"], ["configuration.json"]):
            reason = "root_schema_mismatch"
            fail()
        snapshot_name = names[0]
        snapshot = os.open(snapshot_name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=root)
        snapshot_value = os.fstat(snapshot)
        if (identity(snapshot_value)[:2] != expected_snapshot
                or not stat.S_ISREG(snapshot_value.st_mode)
                or snapshot_value.st_uid != os.getuid()
                or stat.S_IMODE(snapshot_value.st_mode) != 0o400
                or snapshot_value.st_nlink != 1
                or not 0 < snapshot_value.st_size <= MAX_BYTES):
            reason = "snapshot_identity_mismatch"
            fail()
        payload = read_snapshot(snapshot)
        if len(payload) != snapshot_value.st_size or digest(payload) != expected_digest:
            reason = "snapshot_digest_mismatch"
            fail()
        reason = "snapshot_schema_mismatch"
        if snapshot_name == "events.jsonl":
            result, category, dimension = validate_events(
                payload, os.environ["DV_HARDWARE_CASE_ID"]
            )
            dimension_label = "preservation_error"
        else:
            result, category, dimension = validate_configuration(
                payload, os.environ["DV_HARDWARE_CASE_ID"]
            )
            dimension_label = "configuration_stage"
        os.lseek(snapshot, 0, os.SEEK_SET)
        proof_payload = read_snapshot(snapshot)
        if (proof_payload != payload or digest(proof_payload) != expected_digest
                or identity(os.fstat(snapshot)) != identity(snapshot_value)):
            reason = "snapshot_post_validation_mismatch"
            fail()
        check = os.open(snapshot_name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=root)
        try:
            if identity(os.fstat(check)) != identity(snapshot_value):
                reason = "snapshot_identity_mismatch"
                fail()
        finally:
            os.close(check)
        rebound, rebound_identity = open_owned_directory(base, token)
        os.close(rebound)
        if rebound_identity != root_identity:
            reason = "root_identity_mismatch"
            fail()
        consumer_test = os.environ.get("DV_HARDWARE_CONSUMER_TEST", "")
        if consumer_test == "slow_consumer_execution":
            print("hardware_evidence_consumer=pinned producer_pid=" + str(os.getpid()) +
                  " root_token=" + token, flush=True)
            time.sleep(10)
        if consumer_test == "snapshot_cleanup_mismatch":
            os.link(snapshot_name, "snapshot-retained", src_dir_fd=root, dst_dir_fd=root)
        os.unlink(snapshot_name, dir_fd=root)
        deleted = True
        if os.fstat(snapshot).st_nlink != 0 or os.listdir(root):
            reason = "snapshot_cleanup_mismatch"
            fail()
        rebound, rebound_identity = open_owned_directory(base, token)
        os.close(rebound)
        if rebound_identity != root_identity:
            reason = "root_identity_mismatch_after_snapshot_cleanup"
            fail()
        os.rmdir(token, dir_fd=base)
        print("hardware_evidence_consumer=consumed result=" + result + " category=" + category +
              " " + dimension_label + "=" + dimension + " root_token=" + token +
              " cleanup=trusted_debug_exact_path")
    except Exception:
        outcome = "retained"
        print("hardware_evidence_consumer=" + outcome + " reason=" + reason +
              " residual_class=handoff_root root_token=" + token +
              (" expected_root_token=" + expected_root_token if expected_root_token else "") +
              " cleanup=" + ("partial_snapshot_removed" if deleted else "not_attempted"))
        sys.exit(70)
    finally:
        for descriptor in (snapshot, root, base):
            if descriptor is not None:
                try:
                    os.close(descriptor)
                except OSError:
                    pass

if os.environ.get("DV_HARDWARE_OPERATION") == "consume":
    consume()
elif os.environ.get("DV_HARDWARE_OPERATION") == "publish_configuration":
    publish_configuration()
else:
    publish()
PY
)

prepare_hardware_evidence_handoff() {
    [[ -z "$hardware_handoff_root" ]] || return 0
    local source_directory="${hardware_event_source:h}"
    local raw_root_name="${resolved_run_root:t}"
    local random_suffix="${raw_root_name#holdtype-dv-p0b.}"
    umask 077
    hardware_handoff_root_name="holdtype-dv-p0b-handoff.$random_suffix"
    hardware_handoff_root="$resolved_temp_root/$hardware_handoff_root_name"
    hardware_event_handoff="$hardware_handoff_root/events.jsonl"
    mkdir -m 0700 -- "$hardware_handoff_root"
    hardware_handoff_root_identity=$(/usr/bin/stat -f '%d:%i' "$hardware_handoff_root")
    if [[ "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_PREPARATION_TEST:-}" == slow ]]; then
        print -r -- "hardware_evidence_preparation=owned root_token=$hardware_handoff_root_name"
        sleep 10 &
        hardware_preparation_pid=$!
        wait "$hardware_preparation_pid"
        hardware_preparation_pid=""
    fi
    mkdir -p -- "$source_directory"
    chmod 0700 "$resolved_run_root" "${source_directory:h}" "$source_directory" \
        "$hardware_handoff_root"
}

terminate_hardware_evidence_worker() {
    local child_pid="$hardware_evidence_worker_pid"
    [[ "$child_pid" == <-> ]] || return 0
    if kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
        local checks_remaining=20
        while kill -0 "$child_pid" 2>/dev/null && (( checks_remaining > 0 )); do
            sleep 0.05
            checks_remaining=$(( checks_remaining - 1 ))
        done
        if kill -0 "$child_pid" 2>/dev/null; then
            kill -KILL "$child_pid" 2>/dev/null || true
        fi
    fi
    wait "$child_pid" 2>/dev/null || true
    hardware_evidence_worker_pid=""
    hardware_evidence_worker_kind=""
    if [[ -n "$hardware_publisher_output" &&
          "$hardware_publisher_output" == "$resolved_temp_root"/.holdtype-dv-p0b-publisher.* ]]; then
        rm -f -- "$hardware_publisher_output"
        hardware_publisher_output=""
    fi
}

record_hardware_evidence_signal_retention() {
    case "$hardware_evidence_worker_kind" in
        publisher)
            hardware_raw_cleanup_forbidden=1
            hardware_handoff_cleanup_forbidden=1
            print -r -- "hardware_evidence_publish=retained reason=signal residual_class=raw_and_handoff raw_root_token=${resolved_run_root:t} handoff_root_token=$hardware_handoff_root_name cleanup=retain_implicated"
            ;;
        consumer)
            print -r -- "hardware_evidence_consumer=retained reason=signal residual_class=pinned_snapshot root_token=$consumer_root_token cleanup=not_attempted"
            ;;
    esac
}

validate_and_handoff_hardware_evidence() {
    local operation="${1:-publish}"
    local configuration_stage="${2:-}"
    local output
    local publication_status
    local publisher_suffix="${${resolved_run_root:t}#holdtype-dv-p0b.}"
    hardware_publisher_output="$resolved_temp_root/.holdtype-dv-p0b-publisher.$publisher_suffix"
    : > "$hardware_publisher_output"
    chmod 0600 "$hardware_publisher_output"
    set +e
    DV_HARDWARE_OPERATION="$operation" \
        DV_HARDWARE_BASE="$resolved_temp_root" \
        DV_HARDWARE_RAW_ROOT_NAME="${resolved_run_root:t}" \
        DV_HARDWARE_HANDOFF_ROOT_NAME="$hardware_handoff_root_name" \
        DV_HARDWARE_CASE_ID="$case_id" \
        DV_HARDWARE_CONFIGURATION_STAGE="$configuration_stage" \
        DV_HARDWARE_MUTATION="${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST:-}" \
        "$timeout_executable" --signal=TERM --kill-after=1s 5s \
        /usr/bin/python3 -c "$hardware_evidence_handoff_source" >"$hardware_publisher_output" 2>&1 &
    hardware_evidence_worker_pid=$!
    hardware_evidence_worker_kind=publisher
    if [[ "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST:-}" == \
          slow_publisher_execution ]]; then
        local marker_checks=200
        while kill -0 "$hardware_evidence_worker_pid" 2>/dev/null &&
              ! grep -q 'hardware_evidence_publisher=pinned' "$hardware_publisher_output" &&
              (( marker_checks > 0 )); do
            sleep 0.01
            marker_checks=$(( marker_checks - 1 ))
        done
        if grep -q 'hardware_evidence_publisher=pinned' "$hardware_publisher_output"; then
            local producer_pid=$(grep -o 'producer_pid=[0-9]*' "$hardware_publisher_output" | head -1)
            [[ "$producer_pid" =~ '^producer_pid=[0-9]+$' ]] || producer_pid="producer_pid=unknown"
            print -r -- "hardware_evidence_publisher=pinned worker_pid=$hardware_evidence_worker_pid $producer_pid raw_root_token=${resolved_run_root:t} handoff_root_token=$hardware_handoff_root_name"
        fi
    fi
    wait "$hardware_evidence_worker_pid"
    publication_status=$?
    hardware_evidence_worker_pid=""
    hardware_evidence_worker_kind=""
    set -e
    output=$(<"$hardware_publisher_output")
    rm -f -- "$hardware_publisher_output"
    hardware_publisher_output=""
    [[ -z "$output" ]] || print -r -- "$output"
    if [[ "$output" == *"cleanup=retain_implicated"* ]]; then
        hardware_raw_cleanup_forbidden=1
        hardware_handoff_cleanup_forbidden=1
    fi
    (( publication_status == 0 )) || return "$publication_status"
    local field
    local snapshot_device=""
    local snapshot_inode=""
    for field in ${(z)output}; do
        case "$field" in
            snapshot_device=*) snapshot_device="${field#snapshot_device=}" ;;
            snapshot_inode=*) snapshot_inode="${field#snapshot_inode=}" ;;
            snapshot_sha256=*) hardware_snapshot_digest="${field#snapshot_sha256=}" ;;
        esac
    done
    [[ "$snapshot_device" == <-> && "$snapshot_inode" == <-> &&
       "$hardware_snapshot_digest" =~ '^[0-9a-f]{64}$' ]] || return 1
    hardware_snapshot_identity="$snapshot_device:$snapshot_inode"
    hardware_handoff_retained=1
}

prepare_hardware_configuration_diagnostic() {
    [[ "$hardware_configuration_descriptor_open" == 0 ]] || return 1
    hardware_configuration_output="$hardware_handoff_root/.configuration-diagnostic"
    umask 077
    set -o noclobber
    exec 3> "$hardware_configuration_output" || { set +o noclobber; return 1; }
    set +o noclobber
    hardware_configuration_descriptor_open=1
    chmod 0600 "$hardware_configuration_output"
    hardware_configuration_output_identity=$(/usr/bin/stat -f '%d:%i:%u:%Lp:%l' \
        "$hardware_configuration_output")
}

close_hardware_configuration_diagnostic() {
    if [[ "$hardware_configuration_descriptor_open" == 1 ]]; then
        exec 3>&-
        hardware_configuration_descriptor_open=0
    fi
}

discard_hardware_configuration_diagnostic() {
    close_hardware_configuration_diagnostic
    if [[ -n "$hardware_configuration_output" &&
          "$hardware_configuration_output" == "$hardware_handoff_root/.configuration-diagnostic" &&
          -f "$hardware_configuration_output" && ! -L "$hardware_configuration_output" ]]; then
        rm -f -- "$hardware_configuration_output"
    fi
    hardware_configuration_output=""
    hardware_configuration_output_identity=""
}

parse_hardware_configuration_diagnostic() {
    local output="$1"
    local prefix="dev_vlogs_phase_0b_configuration result=failed category=invalid_configuration configuration_stage="
    [[ -n "$output" && "$output" != *$'\n'* && "$output" == "$prefix"* ]] || return 1
    local stage="${output#$prefix}"
    case "$stage" in
        isolation_not_enabled|automation_not_enabled|keychain_ui_not_suppressed|run_root_missing|\
        event_log_missing|camera_id_missing|run_root_outside_temporary_root|event_log_path_mismatch|\
        duration_invalid|case_id_invalid|run_paths_unavailable|unknown) REPLY="$stage" ;;
        *) return 1 ;;
    esac
}

publish_hardware_configuration_diagnostic() {
    close_hardware_configuration_diagnostic
    local observed=$(/usr/bin/stat -f '%d:%i:%u:%Lp:%l' "$hardware_configuration_output") || return 2
    [[ "$observed" == "$hardware_configuration_output_identity" ]] || return 2
    local output=$(<"$hardware_configuration_output")
    rm -f -- "$hardware_configuration_output"
    hardware_configuration_output=""
    hardware_configuration_output_identity=""
    [[ -n "$output" ]] || return 1
    parse_hardware_configuration_diagnostic "$output" || return 2
    validate_and_handoff_hardware_evidence publish_configuration "$REPLY" || return 2
    return 0
}

consume_hardware_evidence() {
    local consumer_status
    set +e
    DV_HARDWARE_OPERATION=consume \
        DV_HARDWARE_BASE="$resolved_temp_root" \
        DV_HARDWARE_HANDOFF_ROOT_NAME="$consumer_root_token" \
        DV_HARDWARE_ROOT_DEVICE="$consumer_root_device" \
        DV_HARDWARE_ROOT_INODE="$consumer_root_inode" \
        DV_HARDWARE_SNAPSHOT_DEVICE="$consumer_snapshot_device" \
        DV_HARDWARE_SNAPSHOT_INODE="$consumer_snapshot_inode" \
        DV_HARDWARE_SNAPSHOT_SHA256="$consumer_snapshot_digest" \
        DV_HARDWARE_CASE_ID="$case_id" \
        DV_HARDWARE_CONSUMER_TEST="${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONSUMER_TEST:-}" \
        "$timeout_executable" --signal=TERM --kill-after=1s 5s \
        /usr/bin/python3 -c "$hardware_evidence_handoff_source" &
    hardware_evidence_worker_pid=$!
    hardware_evidence_worker_kind=consumer
    print -r -- "hardware_evidence_consumer=executing worker_pid=$hardware_evidence_worker_pid root_token=$consumer_root_token"
    wait "$hardware_evidence_worker_pid"
    consumer_status=$?
    hardware_evidence_worker_pid=""
    hardware_evidence_worker_kind=""
    set -e
    return "$consumer_status"
}

create_hardware_evidence_test_fixture() {
    local scenario="$1"
    DV_HARDWARE_EVENT_SOURCE="$hardware_event_source" \
        DV_HARDWARE_EVENT_HANDOFF="$hardware_event_handoff" \
        DV_HARDWARE_HANDOFF_ROOT="$hardware_handoff_root" \
        DV_HARDWARE_CASE_ID="$case_id" \
        DV_HARDWARE_SCENARIO="$scenario" \
        /usr/bin/python3 - <<'PY'
import json
import os

path = os.environ["DV_HARDWARE_EVENT_SOURCE"]
handoff = os.environ["DV_HARDWARE_EVENT_HANDOFF"]
handoff_root = os.environ["DV_HARDWARE_HANDOFF_ROOT"]
case_id = os.environ["DV_HARDWARE_CASE_ID"]
scenario = os.environ["DV_HARDWARE_SCENARIO"]
base = {
    "runID": "11111111-1111-4111-8111-111111111111", "caseID": case_id,
    "attemptID": "22222222-2222-4222-8222-222222222222",
    "monotonicMilliseconds": 1, "action": "attempt", "result": "started",
    "metrics": [],
}
stage = {
    "cameraProbePassed": True, "passthroughCompleted": True, "finalProbePassed": True,
    "cameraMediaSubtype": "hvc1", "finalizedMediaSubtype": "hvc1",
    "finalizedAudioMediaSubtype": "aac ",
    "cameraFormat": "hvc1:1920x1080:descriptions_1",
    "finalizedFormat": "hvc1:1920x1080:descriptions_1",
}
metrics = [
    {"name": "camera_width", "value": 1920, "unit": "px", "disposition": "evidence_only"},
    {"name": "camera_height", "value": 1080, "unit": "px", "disposition": "evidence_only"},
    {"name": "camera_display_width", "value": 1920, "unit": "px", "disposition": "evidence_only"},
    {"name": "camera_display_height", "value": 1080, "unit": "px", "disposition": "evidence_only"},
    {"name": "camera_nominal_fps", "value": 30, "unit": "fps", "disposition": "evidence_only"},
    {"name": "camera_start_timestamp", "value": 0, "unit": "s", "disposition": "evidence_only"},
    {"name": "camera_end_timestamp", "value": 10, "unit": "s", "disposition": "evidence_only"},
    {"name": "camera_estimated_data_rate", "value": 1000000, "unit": "bps", "disposition": "evidence_only"},
    {"name": "camera_transform_a", "value": 1, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "camera_transform_b", "value": 0, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "camera_transform_c", "value": 0, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "camera_transform_d", "value": 1, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "final_width", "value": 1920, "unit": "px", "disposition": "evidence_only"},
    {"name": "final_height", "value": 1080, "unit": "px", "disposition": "evidence_only"},
    {"name": "final_display_width", "value": 1920, "unit": "px", "disposition": "evidence_only"},
    {"name": "final_display_height", "value": 1080, "unit": "px", "disposition": "evidence_only"},
    {"name": "final_derived_fps", "value": 30, "unit": "fps", "disposition": "evidence_only"},
    {"name": "final_start_timestamp", "value": 0, "unit": "s", "disposition": "evidence_only"},
    {"name": "final_end_timestamp", "value": 10, "unit": "s", "disposition": "evidence_only"},
    {"name": "final_estimated_data_rate", "value": 1000000, "unit": "bps", "disposition": "evidence_only"},
    {"name": "final_transform_a", "value": 1, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "final_transform_b", "value": 0, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "final_transform_c", "value": 0, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "final_transform_d", "value": 1, "unit": "coefficient", "disposition": "evidence_only"},
    {"name": "audio_start_timestamp", "value": 0, "unit": "s", "disposition": "evidence_only"},
    {"name": "audio_end_timestamp", "value": 10, "unit": "s", "disposition": "evidence_only"},
    {"name": "audio_estimated_data_rate", "value": 128000, "unit": "bps", "disposition": "evidence_only"},
]
if scenario in {"valid_nominal_zero_derived_positive", "valid_ready_nominal_zero_derived_positive"}:
    next(item for item in metrics if item["name"] == "camera_nominal_fps")["value"] = 0
    metrics.append({"name": "camera_derived_fps", "value": 30, "unit": "fps",
                    "disposition": "evidence_only"})
terminal = dict(base)
terminal.update({
    "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "failed",
    "category": "video_preservation_failed",
    "preservation_failure_dimension": "encoded_payload_mismatch",
    "failure_stage_evidence": stage, "metrics": metrics,
})
ready_metrics = metrics + [
    {"name": "camera_video_duration", "value": 10, "unit": "s",
     "disposition": "evidence_only"},
    {"name": "final_video_duration", "value": 10, "unit": "s",
     "disposition": "evidence_only"},
    {"name": "audio_duration", "value": 10, "unit": "s", "disposition": "evidence_only"},
    {"name": "preserved_sample_count", "value": 600, "unit": "samples",
     "disposition": "functional"},
    {"name": "preserved_encoded_bytes", "value": 1048576, "unit": "bytes",
     "disposition": "functional"},
]
ready_video = {
    "cameraMediaSubtype": "hvc1", "finalizedMediaSubtype": "hvc1",
    "finalizedAudioMediaSubtype": "aac ",
    "cameraFormat": "hvc1:1920x1080:descriptions_1",
    "finalizedFormat": "hvc1:1920x1080:descriptions_1",
    "preservationMethod": "stored_sample_exact_v1", "preservedSampleCount": 600,
    "preservedEncodedByteCount": 1048576, "matched": True,
}
if scenario in {
    "valid_ready", "valid_ready_nominal_zero_derived_positive", "ready_extra_video_key",
    "ready_count_mismatch", "ready_unmatched",
    "ready_wrong_method", "ready_bad_device_label", "ready_bad_device_class",
    "ready_missing_audio_duration", "ready_missing_video_metric", "ready_missing_fps",
    "ready_impossible_audio_metric", "ready_with_failure_category",
}:
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "ready",
        "deviceClass": "continuity", "redactedDeviceLabel": "continuity_camera",
        "videoEvidence": ready_video, "metrics": ready_metrics,
    })
elif scenario == "valid_cancelled":
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "cancelled",
        "category": "capture_stop", "metrics": [],
    })
elif scenario in {"valid_preservation_cancelled", "valid_preservation_timed_out"}:
    terminal["preservation_failure_dimension"] = (
        "cancelled" if scenario.endswith("cancelled") else "timed_out"
    )
    terminal["result"] = (
        "cancelled" if scenario.endswith("cancelled") else "timed_out"
    )
elif scenario.startswith("valid_failure_"):
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "failed",
        "category": scenario.removeprefix("valid_failure_"), "metrics": [],
    })
events = [base, terminal]
if scenario == "zero":
    raise SystemExit(0)
if scenario == "wrong_case":
    terminal["caseID"] = "other-case"
elif scenario == "wrong_ids":
    terminal["attemptID"] = "other-attempt"
elif scenario == "invalid_run_id":
    base["runID"] = terminal["runID"] = "run-1"
elif scenario == "invalid_attempt_id":
    base["attemptID"] = terminal["attemptID"] = "attempt-1"
elif scenario == "wrong_order":
    terminal["monotonicMilliseconds"] = 0
elif scenario == "missing_start":
    events = [terminal]
elif scenario == "missing_terminal":
    events = [base]
elif scenario == "duplicate_terminal":
    events.append(dict(terminal))
elif scenario == "ready_plus_failure":
    terminal["result"] = "ready"
elif scenario == "unexpected_schema":
    terminal["unexpected"] = True
elif scenario == "extra_nested":
    stage["unexpected"] = True
elif scenario == "missing_stage_key":
    stage.pop("cameraFormat")
elif scenario == "false_stage":
    stage["passthroughCompleted"] = False
elif scenario == "unexpected_event":
    terminal["action"] = "probe"
elif scenario == "arbitrary_category":
    terminal["category"] = "raw_platform_error"
elif scenario == "impossible_failure_category":
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "failed",
        "category": "event_log", "metrics": [],
    })
    events[1] = terminal
elif scenario == "arbitrary_dimension":
    terminal["preservation_failure_dimension"] = "secret_sample_mismatch"
elif scenario == "wrong_result_dimension":
    terminal["preservation_failure_dimension"] = "timed_out"
elif scenario == "arbitrary_device":
    terminal["deviceClass"] = "serial-device"
elif scenario == "identifier_too_long":
    terminal["runID"] = "x" * 65
elif scenario == "private_data":
    stage["cameraFormat"] = "/Users/private/sample.mov"
elif scenario == "private_subtype":
    stage["cameraMediaSubtype"] = "secret-device"
elif scenario == "nonfinite_metric":
    metrics[0]["value"] = float("nan")
elif scenario == "out_of_range_metric":
    metrics[0]["value"] = 1e100
elif scenario == "unexpected_metric":
    metrics[0]["name"] = "raw_private_metric"
elif scenario == "wrong_unit":
    metrics[0]["unit"] = "path"
elif scenario == "wrong_disposition":
    metrics[0]["disposition"] = "private"
elif scenario == "wrong_metric_value":
    metrics[0]["value"] = "1920"
elif scenario == "duplicate_metric":
    metrics.append(dict(metrics[0]))
elif scenario == "missing_required_metric":
    metrics.pop()
elif scenario == "preservation_extra_duration":
    metrics.append({"name": "camera_video_duration", "value": 10, "unit": "s",
                    "disposition": "evidence_only"})
elif scenario == "backward_timestamp":
    next(item for item in metrics if item["name"] == "camera_end_timestamp")["value"] = -1
elif scenario == "ready_extra_video_key":
    ready_video["unexpected"] = True
elif scenario == "ready_count_mismatch":
    ready_video["preservedSampleCount"] = 599
elif scenario == "ready_unmatched":
    ready_video["matched"] = False
elif scenario == "ready_wrong_method":
    ready_video["preservationMethod"] = "codec_only"
elif scenario == "ready_bad_device_label":
    terminal["redactedDeviceLabel"] = "private-camera"
elif scenario == "ready_bad_device_class":
    terminal["deviceClass"] = "serial-device"
elif scenario == "ready_missing_audio_duration":
    ready_metrics[:] = [item for item in ready_metrics if item["name"] != "audio_duration"]
elif scenario == "ready_missing_video_metric":
    ready_metrics[:] = [item for item in ready_metrics if item["name"] != "camera_display_width"]
elif scenario == "ready_missing_fps":
    ready_metrics[:] = [item for item in ready_metrics if not item["name"].startswith("camera_")
                       or not item["name"].endswith("_fps")]
elif scenario == "ready_impossible_audio_metric":
    ready_metrics.append({"name": "audio_width", "value": 1920, "unit": "px",
                          "disposition": "evidence_only"})
elif scenario == "ready_with_failure_category":
    terminal["category"] = "camera_probe"
elif scenario == "ordinary_failure_metrics":
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "failed",
        "category": "camera_probe", "metrics": [metrics[0]],
    })
    events[1] = terminal
elif scenario == "ordinary_failure_device":
    terminal = dict(base)
    terminal.update({
        "monotonicMilliseconds": 2, "action": "attempt_terminal", "result": "failed",
        "category": "camera_probe", "deviceClass": "continuity", "metrics": [],
    })
    events[1] = terminal
directory = os.path.dirname(path)
if scenario == "symlink":
    target = os.path.join(os.path.dirname(directory), "event-target")
    with open(target, "w", encoding="utf-8") as output:
        output.write("\n".join(json.dumps(event, separators=(",", ":")) for event in events) + "\n")
    os.symlink(target, path)
    raise SystemExit(0)
if scenario == "source_ancestor_symlink":
    source_parent = os.path.dirname(directory)
    target = os.path.join(os.path.dirname(source_parent), "evidence-target")
    os.rmdir(directory)
    os.mkdir(target, 0o700)
    with open(os.path.join(target, "events.jsonl"), "w", encoding="utf-8") as output:
        output.write("\n".join(json.dumps(event, separators=(",", ":")) for event in events) + "\n")
    os.chmod(os.path.join(target, "events.jsonl"), 0o600)
    os.symlink(target, directory)
    raise SystemExit(0)
if scenario == "destination_ancestor_symlink":
    os.rmdir(handoff_root)
    raw_root = os.path.dirname(os.path.dirname(os.path.dirname(path)))
    os.symlink(raw_root, handoff_root)
    raise SystemExit(0)
if scenario == "oversize":
    with open(path, "wb") as output:
        output.write(b"x" * 262_145)
    os.chmod(path, 0o600)
    raise SystemExit(0)
if scenario == "malformed":
    with open(path, "w", encoding="utf-8") as output:
        output.write("{malformed}\n")
else:
    lines = [json.dumps(event, separators=(",", ":")) for event in events]
    if scenario == "duplicate_top":
        lines[1] = lines[1].replace('"category":', '"category":"video_preservation_failed","category":', 1)
    elif scenario == "duplicate_nested":
        lines[1] = lines[1].replace('"cameraProbePassed":true',
                                    '"cameraProbePassed":true,"cameraProbePassed":true', 1)
    with open(path, "w", encoding="utf-8") as output:
        output.write("\n".join(lines) + "\n")
os.chmod(path, 0o600)
if scenario == "multiple":
    with open(os.path.join(directory, "unexpected.jsonl"), "w", encoding="utf-8") as output:
        output.write("{}\n")
elif scenario == "hardlink":
    os.link(path, os.path.join(directory, "linked.jsonl"))
elif scenario == "wrong_source_mode":
    os.chmod(path, 0o644)
elif scenario == "wrong_source_type":
    os.unlink(path)
    os.mkdir(path, 0o700)
elif scenario == "wrong_source_parent_mode":
    os.chmod(directory, 0o755)
elif scenario == "wrong_destination_mode":
    os.chmod(handoff_root, 0o755)
elif scenario == "destination_collision":
    with open(handoff, "w", encoding="utf-8") as output:
        output.write("untrusted\n")
    os.chmod(handoff, 0o600)
PY
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

permission_pipeline_capture() {
    local total_seconds="$1"
    local pipeline="$2"
    shift 2
    timeout_command "$total_seconds" /bin/zsh -c "$pipeline" permission-pipeline "$@"
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

def same_entry(value, wanted):
    return identity(value) == identity(wanted) and stat.S_IFMT(value.st_mode) == stat.S_IFMT(wanted.st_mode)

def preserve_and_replace(parent, name, value, label):
    preserved = ".dv-p0b-preserved-" + label + "-" + secrets.token_hex(8)
    rename_exclusive(parent, name, preserved)
    if stat.S_ISDIR(value.st_mode):
        os.mkdir(name, stat.S_IMODE(value.st_mode), dir_fd=parent)
    elif stat.S_ISREG(value.st_mode):
        descriptor = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                             stat.S_IMODE(value.st_mode), dir_fd=parent)
        os.close(descriptor)
    else:
        raise ValueError("replacement")

def quarantine(parent, name, wanted, label):
    destination = ".dv-p0b-" + label + "-" + secrets.token_hex(12)
    rename_exclusive(parent, name, destination)
    moved = os.stat(destination, dir_fd=parent, follow_symlinks=False)
    if not same_entry(moved, wanted):
        raise ValueError("replacement")
    return destination

def quarantine_identity(parent, name, wanted, label):
    destination = ".dv-p0b-" + label + "-" + secrets.token_hex(12)
    rename_exclusive(parent, name, destination)
    if path_identity(parent, destination) != wanted:
        raise ValueError("replacement")
    return destination

def scrub(root, names, test_action):
    for name in names:
        try:
            value = os.stat(name, dir_fd=root, follow_symlinks=False)
        except FileNotFoundError:
            continue
        if (not stat.S_ISREG(value.st_mode) or value.st_uid != os.getuid() or
                stat.S_IMODE(value.st_mode) != 0o600 or value.st_nlink != 1):
            raise ValueError("sensitive")
        if test_action == "sensitive_replaced":
            preserve_and_replace(root, name, value, "sensitive")
            test_action = ""
        quarantined = quarantine(root, name, value, "sensitive")
        os.unlink(quarantined, dir_fd=root)
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
                        re.fullmatch(r"timeout-(?:worker|parent-[1-3]|child-[1-3]|pipeline-[a-z-]+)",
                                     name) is not None))
            if not allowed:
                raise ValueError("name")
        value = os.stat(name, dir_fd=directory, follow_symlinks=False)
        if value.st_uid != os.getuid() or stat.S_IMODE(value.st_mode) & 0o022:
            raise ValueError("ownership")
        if stat.S_ISDIR(value.st_mode):
            quarantined = quarantine(directory, name, value, "directory")
            child = os.open(quarantined, OPEN_DIRECTORY, dir_fd=directory)
            try:
                if identity(os.fstat(child)) != identity(value):
                    raise ValueError("replacement")
                remove_contents(child)
                if test_action == "directory_replaced":
                    preserve_and_replace(directory, quarantined, value, "directory")
                    test_action = ""
                final_name = quarantine(directory, quarantined, value, "directory-final")
                os.rmdir(final_name, dir_fd=directory)
            finally:
                os.close(child)
        elif stat.S_ISREG(value.st_mode) and value.st_nlink == 1:
            if test_action == "regular_replaced":
                preserve_and_replace(directory, name, value, "regular")
                test_action = ""
            quarantined = quarantine(directory, name, value, "regular")
            os.unlink(quarantined, dir_fd=directory)
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
                rename_exclusive(root, name, ".dv-p0b-fixture-sensitive-" + secrets.token_hex(8))
                if test_action == "sensitive_symlink":
                    os.symlink("permission-launcher.log", name, dir_fd=root)
                elif test_action == "sensitive_hardlink":
                    os.link("permission-launcher.log", name, src_dir_fd=root, dst_dir_fd=root)
                else:
                    os.mkdir(name, 0o700, dir_fd=root)
            scrub(root, names, test_action)
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
            if test_action == "final_tombstone_replaced":
                preserved = ".dv-p0b-preserved-root-" + secrets.token_hex(8)
                rename_exclusive(parent, tombstone, preserved)
                os.mkdir(tombstone, 0o700, dir_fd=parent)
            final_tombstone = quarantine_identity(
                parent, tombstone, root_wanted, "root-final")
            os.rmdir(final_tombstone, dir_fd=parent)
        finally:
            os.close(tombstone_fd)
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
    --consume-hardware-evidence)
        shift
        while (( $# > 0 )); do
            (( $# >= 2 )) || { print -u2 -r -- "error: consumer option requires a value"; exit 64; }
            case "$1" in
                --root-token) consumer_root_token="$2" ;;
                --root-device) consumer_root_device="$2" ;;
                --root-inode) consumer_root_inode="$2" ;;
                --snapshot-device) consumer_snapshot_device="$2" ;;
                --snapshot-inode) consumer_snapshot_inode="$2" ;;
                --snapshot-sha256) consumer_snapshot_digest="$2" ;;
                --case-id) case_id="$2" ;;
                *) print -u2 -r -- "error: unknown consumer option $1"; exit 64 ;;
            esac
            shift 2
        done
        [[ "$consumer_root_token" =~ '^holdtype-dv-p0b-handoff\.[A-Za-z0-9]{6,32}$' &&
           "$consumer_root_device" == <-> && "$consumer_root_inode" == <-> &&
           "$consumer_snapshot_device" == <-> && "$consumer_snapshot_inode" == <-> &&
           "$consumer_snapshot_digest" =~ '^[0-9a-f]{64}$' &&
           "$case_id" =~ '^[A-Za-z0-9_-]{1,64}$' ]] || {
            print -u2 -r -- "error: incomplete or invalid hardware evidence consumer authority"
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

# Install cleanup ownership before any run-owned root is created. Paths are
# predeclared before mkdir, so a preparation signal cannot create an orphan.
cleanup() {
    terminate_hardware_evidence_worker
    if [[ "$hardware_raw_cleanup_forbidden" != 1 &&
          -n "$resolved_run_root" && -n "$resolved_temp_root" &&
          "$resolved_run_root" == "$resolved_temp_root"/holdtype-dv-p0b.* &&
          -d "$resolved_run_root" ]]; then
        "$timeout_executable" --signal=TERM --kill-after=1s 5s rm -rf -- "$resolved_run_root" || return 1
    fi
    if [[ -n "$hardware_handoff_root" && "$hardware_handoff_retained" != 1 &&
          "$hardware_handoff_cleanup_forbidden" != 1 &&
          "$hardware_handoff_root" == "$resolved_temp_root"/holdtype-dv-p0b-handoff.* &&
          -d "$hardware_handoff_root" ]]; then
        "$timeout_executable" --signal=TERM --kill-after=1s 5s rm -rf -- "$hardware_handoff_root" || return 1
    fi
}
finish_cleanup() {
    local prior_status=$?
    trap - EXIT
    if [[ "$termination_signal_status" == <-> ]]; then
        if [[ "$termination_cleanup_completed" != 1 ]]; then
            cleanup || true
        fi
        prior_status="$termination_signal_status"
    else
        cleanup || prior_status=70
    fi
    exit "$prior_status"
}
finish_signal() {
    termination_signal_status="$1"
    trap - INT TERM
    record_hardware_evidence_signal_retention
    cleanup || true
    termination_cleanup_completed=1
    exit "$termination_signal_status"
}
trap finish_cleanup EXIT
trap 'finish_signal 130' INT
trap 'finish_signal 143' TERM

resolved_temp_root=${TMPDIR:A}
if [[ "$mode" == "--consume-hardware-evidence" ]]; then
    consume_hardware_evidence
    exit $?
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
random_run_suffix=$(/usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:upper:]' '[:lower:]')
random_run_suffix=${random_run_suffix[1,12]}
run_root="$resolved_temp_root/holdtype-dv-p0b.$random_run_suffix"
resolved_run_root="$run_root"
mkdir -m 0700 -- "$resolved_run_root"
hardware_raw_root_identity=$(/usr/bin/stat -f '%d:%i' "$resolved_run_root")
hardware_event_source="$resolved_run_root/hardware-raw/evidence/events.jsonl"
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

terminate_hardware_preparation() {
    local child_pid="$hardware_preparation_pid"
    [[ "$child_pid" == <-> ]] || return 0
    if kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
        local checks_remaining=20
        while kill -0 "$child_pid" 2>/dev/null && (( checks_remaining > 0 )); do
            sleep 0.05
            checks_remaining=$(( checks_remaining - 1 ))
        done
        if kill -0 "$child_pid" 2>/dev/null; then
            kill -KILL "$child_pid" 2>/dev/null || true
        fi
    fi
    wait "$child_pid" 2>/dev/null || true
    hardware_preparation_pid=""
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
    observed_permission_ppid=$(permission_pipeline_capture "$REPLY" \
        '/bin/ps -p "$1" -o ppid= | /usr/bin/tr -d "[:space:]"' "$child_pid") || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    text_identity=$(permission_pipeline_capture "$REPLY" '
        /usr/sbin/lsof -a -p "$1" -d txt -Ffin 2>/dev/null | /usr/bin/awk '\''
            /^ftxt$/ { in_text = 1; next }
            in_text && /^i/ && inode == "" { inode = substr($0, 2); next }
            in_text && /^n/ { print inode "\t" substr($0, 2); exit }
        '\''' "$child_pid") || return 1
    observed_permission_inode="${text_identity%%$'\t'*}"
    observed_permission_executable="${text_identity#*$'\t'}"
    permission_timeout_cap "$deadline" 2 || return 1
    observed_permission_command=$(permission_pipeline_capture "$REPLY" \
        '/bin/ps -ww -p "$1" -o command= | /usr/bin/sed '\''s/^[[:space:]]*//;s/[[:space:]]*$//'\''' \
        "$child_pid") || return 1
    permission_timeout_cap "$deadline" 2 || return 1
    observed_permission_start=$(permission_pipeline_capture "$REPLY" \
        '/bin/ps -p "$1" -o lstart= | /usr/bin/sed '\''s/^[[:space:]]*//;s/[[:space:]]*$//'\''' \
        "$child_pid") || return 1
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
    if ! process_state=$(permission_pipeline_capture "$REPLY" \
        '/bin/ps -p "$1" -o state= | /usr/bin/tr -d "[:space:]"' "$child_pid"); then
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
    permission_pipeline_capture "$REPLY" '
        /bin/ps -E -ww -p "$1" -o command= | /usr/bin/awk -v marker="$2" '\''
            {
                for (field = 1; field <= NF; field += 1) {
                    if ($field == marker) {
                        found = 1
                    }
                }
            }
            END { exit(found ? 0 : 1) }
        '\''' "$child_pid" "$permission_marker" >/dev/null
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
        next_parent=$(permission_pipeline_capture "$REPLY" \
            '/bin/ps -p "$1" -o ppid= | /usr/bin/tr -d "[:space:]"' "$ancestor") || {
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
        permission_pipeline_capture "$REPLY" \
            "/usr/bin/shasum -a 256 | /usr/bin/awk '{ print \$1 }'")
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
        cleanup_sensitive_hardlink|cleanup_sensitive_type|cleanup_sensitive_replaced|\
        cleanup_regular_replaced|cleanup_directory_replaced|cleanup_final_tombstone_replaced|\
        cleanup_unexpected_name|\
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
        cleanup_sensitive_replaced) permission_root_guard_test_action="sensitive_replaced" ;;
        cleanup_regular_replaced)
            permission_root_guard_test_action="regular_replaced"
            print -rn -- fixture > "$resolved_run_root/dv-p0b-camera-authorization-fixture"
            ;;
        cleanup_directory_replaced)
            permission_root_guard_test_action="directory_replaced"
            mkdir "$resolved_run_root/home"
            ;;
        cleanup_final_tombstone_replaced)
            permission_root_guard_test_action="final_tombstone_replaced"
            ;;
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
    local producer="$resolved_run_root/timeout-pipeline-producer"
    local consumer="$resolved_run_root/timeout-pipeline-consumer"
    local consumer_record="$resolved_run_root/timeout-pipeline-consumer-pid"
    local pipeline_child_record="$resolved_run_root/timeout-pipeline-child-pid"
    print -rl -- '#!/bin/zsh' 'trap "" TERM' \
        'while true; do print -r -- value; sleep 10; done' > "$producer"
    print -rl -- '#!/bin/zsh' 'trap "" TERM' 'print -r -- "$$" > "$1"' \
        '( trap "" TERM; while true; do sleep 10; done ) &' \
        'print -r -- "$!" > "$2"' 'while IFS= read -r value; do :; done' 'wait' > "$consumer"
    chmod 0700 "$producer" "$consumer"
    local pipeline_attempt pipeline_status=1
    for pipeline_attempt in 1 2 3; do
        : > "$consumer_record"
        : > "$pipeline_child_record"
        set +e
        permission_hard_timeout_command 1.000000 /bin/zsh -c \
            '"$1" | "$2" "$3" "$4"' permission-pipeline "$producer" "$consumer" \
            "$consumer_record" "$pipeline_child_record"
        pipeline_status=$?
        set -e
        (( pipeline_status == 124 )) && \
            [[ -s "$consumer_record" && -s "$pipeline_child_record" ]] && break
    done
    (( pipeline_status == 124 )) && [[ -s "$consumer_record" && -s "$pipeline_child_record" ]] || {
        print -r -- "permission_hard_timeout_test=failed_pipeline"
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

hardware_trusted_root_cleanup_source=$(cat <<'PY'
import os
import re
import shutil
import stat
import sys

ROOT = re.compile(r"holdtype-dv-p0b\.[A-Za-z0-9]{6,32}")
HANDOFF = re.compile(r"holdtype-dv-p0b-handoff\.[A-Za-z0-9]{6,32}")

def identity(value):
    return (value.st_dev, value.st_ino)

base = os.environ["DV_CLEANUP_BASE"]
token = os.environ["DV_CLEANUP_TOKEN"]
kind = os.environ["DV_CLEANUP_KIND"]
expected_text = os.environ.get("DV_CLEANUP_IDENTITY", "")
pattern = ROOT if kind == "raw" else HANDOFF
reason = "root_validation_mismatch"
original_token = ""
try:
    if pattern.fullmatch(token) is None:
        raise ValueError("token")
    base_value = os.stat(base, follow_symlinks=False)
    if (not stat.S_ISDIR(base_value.st_mode) or base_value.st_uid != os.getuid()
            or stat.S_IMODE(base_value.st_mode) != 0o700):
        reason = "base_ownership_mismatch"
        raise ValueError("base")
    root_path = os.path.join(base, token)
    try:
        root_value = os.stat(root_path, follow_symlinks=False)
    except FileNotFoundError:
        print("trusted_debug_cleanup=absent kind=" + kind + " root_token=" + token)
        raise SystemExit(0)
    if (not stat.S_ISDIR(root_value.st_mode) or root_value.st_uid != os.getuid()
            or stat.S_IMODE(root_value.st_mode) != 0o700):
        reason = "root_ownership_mismatch"
        raise ValueError("root")
    if expected_text:
        expected = tuple(int(value) for value in expected_text.split(":"))
        if len(expected) != 2 or identity(root_value) != expected:
            candidates = []
            for candidate in os.listdir(base):
                if pattern.fullmatch(candidate) is None or candidate == token:
                    continue
                try:
                    candidate_value = os.stat(
                        os.path.join(base, candidate), follow_symlinks=False
                    )
                except OSError:
                    continue
                if identity(candidate_value) == expected:
                    candidates.append(candidate)
            if len(candidates) == 1:
                original_token = candidates[0]
            reason = "root_identity_mismatch"
            raise ValueError("identity")
    for directory, directories, files in os.walk(root_path, topdown=True, followlinks=False):
        for name in directories + files:
            value = os.stat(os.path.join(directory, name), follow_symlinks=False)
            if value.st_uid != os.getuid() or stat.S_IMODE(value.st_mode) & 0o022:
                reason = "descendant_ownership_mismatch"
                raise ValueError("owner")
            if stat.S_ISLNK(value.st_mode):
                reason = "descendant_type_mismatch"
                raise ValueError("symlink")
            if not stat.S_ISDIR(value.st_mode) and not (
                stat.S_ISREG(value.st_mode) and value.st_nlink == 1
            ):
                reason = "descendant_type_mismatch"
                raise ValueError("type")
    rebound = os.stat(root_path, follow_symlinks=False)
    if identity(rebound) != identity(root_value):
        reason = "root_identity_mismatch"
        raise ValueError("rebound")
    # Under the accepted Phase 0B Debug trust boundary only, the private root
    # is trusted against an undetected same-UID namespace replacement here.
    shutil.rmtree(root_path)
    if os.path.lexists(root_path):
        reason = "root_cleanup_incomplete"
        raise ValueError("remaining")
    print("trusted_debug_cleanup=removed kind=" + kind + " root_token=" + token)
except SystemExit:
    raise
except Exception:
    print("trusted_debug_cleanup=retained kind=" + kind + " reason=" + reason +
          " root_token=" + token +
          (" original_root_token=" + original_token if original_token else ""))
    sys.exit(70)
PY
)

cleanup_trusted_debug_root() {
    local kind="$1"
    local token="$2"
    local expected_identity="$3"
    [[ -n "$token" ]] || return 0
    DV_CLEANUP_BASE="$resolved_temp_root" \
        DV_CLEANUP_TOKEN="$token" \
        DV_CLEANUP_KIND="$kind" \
        DV_CLEANUP_IDENTITY="$expected_identity" \
        "$timeout_executable" --signal=TERM --kill-after=1s 5s \
        /usr/bin/python3 -c "$hardware_trusted_root_cleanup_source"
}

cleanup_nonpermission_mode() {
    local cleanup_status=0
    terminate_hardware_evidence_worker
    terminate_hardware_preparation
    terminate_capture_supervisor
    discard_hardware_configuration_diagnostic
    if [[ -n "$resolved_run_root" ]]; then
        if [[ "$hardware_raw_cleanup_forbidden" == 1 ]]; then
            print -u2 -r -- "hardware_evidence_raw=retained root_token=${resolved_run_root:t} cleanup=retention_required"
            cleanup_status=1
        else
            cleanup_trusted_debug_root raw "${resolved_run_root:t}" "$hardware_raw_root_identity" || \
                cleanup_status=1
        fi
    fi
    if [[ "$mode" == "--hardware" && -n "$hardware_handoff_root_name" &&
          "$hardware_handoff_retained" != 1 ]]; then
        if [[ "$hardware_handoff_cleanup_forbidden" == 1 ]]; then
            print -u2 -r -- "hardware_evidence_handoff=retained root_token=$hardware_handoff_root_name cleanup=retention_required"
            cleanup_status=1
        else
            cleanup_trusted_debug_root handoff "$hardware_handoff_root_name" \
                "$hardware_handoff_root_identity" || cleanup_status=1
        fi
    fi
    (( cleanup_status == 0 ))
}

cleanup() {
    if [[ "$mode" == "--request-camera-permission" ]]; then
        cleanup_permission_mode
    else
        cleanup_nonpermission_mode
    fi
}
if [[ -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONFIGURATION_TEST:-}" &&
      -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST:-}" ]]; then
    exit 64
fi
if [[ "$mode" == "--hardware" &&
      -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONFIGURATION_TEST:-}" ]]; then
    prepare_hardware_evidence_handoff
    prepare_hardware_configuration_diagnostic
    configuration_fixture="$HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_CONFIGURATION_TEST"
    configuration_prefix="dev_vlogs_phase_0b_configuration result=failed category=invalid_configuration configuration_stage="
    case "$configuration_fixture" in
        invalid_duplicate)
            print -r -- "${configuration_prefix}unknown" >&3
            print -r -- "${configuration_prefix}unknown" >&3
            ;;
        invalid_extra) print -r -- "${configuration_prefix}unknown private=blocked" >&3 ;;
        invalid_private) print -r -- "${configuration_prefix}/Users/private" >&3 ;;
        invalid_category)
            print -r -- "dev_vlogs_phase_0b_configuration result=failed category=private configuration_stage=unknown" >&3
            ;;
        invalid_empty) ;;
        *) print -r -- "${configuration_prefix}${configuration_fixture}" >&3 ;;
    esac
    set +e
    publish_hardware_configuration_diagnostic
    configuration_status=$?
    set -e
    if [[ "$configuration_fixture" == invalid_* ]]; then
        (( configuration_status != 0 && hardware_handoff_retained == 0 )) || exit 1
        print -r -- "hardware_configuration_test=rejected attempt=zero ready=zero"
        exit 65
    fi
    (( configuration_status == 0 && hardware_handoff_retained == 1 )) || exit 1
    print -r -- "hardware_configuration_test=retained attempt=zero ready=zero"
    exit 65
fi
if [[ "$mode" == "--hardware" && -n "${HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST:-}" ]]; then
    prepare_hardware_evidence_handoff
    create_hardware_evidence_test_fixture \
        "$HOLDTYPE_DEV_VLOGS_PHASE_0B_HARDWARE_EVIDENCE_TEST"
    validate_and_handoff_hardware_evidence || {
        fixture_status=$?
        exit "$fixture_status"
    }
    [[ -f "$hardware_event_handoff" ]]
    print -r -- "hardware_evidence_test=pass raw_cleanup=pending"
    exit 0
fi

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
        permission_pipeline_capture "$REPLY" \
            "/usr/bin/shasum -a 256 | /usr/bin/awk '{ print \$1 }'")
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

prepare_hardware_evidence_handoff
prepare_hardware_configuration_diagnostic
hardware_timeout_seconds=$(( capture_duration + 300 ))
"$timeout_executable" --signal=TERM --kill-after=5s "$hardware_timeout_seconds" env \
    HOLDTYPE_AUTOMATION=1 \
    HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
    HOLDTYPE_DEV_VLOGS_PHASE_0B=1 \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_CAMERA_ID="$camera_id" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_DURATION="$capture_duration" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID="$case_id" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_EVENT_LOG="$hardware_event_source" \
    HOLDTYPE_DEV_VLOGS_PHASE_0B_CONFIGURATION_DIAGNOSTIC_FD=3 \
    "$app_binary" &
capture_supervisor_pid=$!
set +e
wait "$capture_supervisor_pid"
capture_status=$?
set -e
capture_supervisor_pid=""
set +e
publish_hardware_configuration_diagnostic
configuration_status=$?
set -e
case "$configuration_status" in
    0)
        print -u2 -r -- "error: hardware configuration failed before attempt; retained closed diagnostic"
        exit 65
        ;;
    1) ;;
    *) print -u2 -r -- "error: hardware configuration diagnostic was invalid"; exit 1 ;;
esac
(( capture_status == 0 )) || exit "$capture_status"

validate_and_handoff_hardware_evidence || {
    print -u2 -r -- "error: hardware event evidence handoff was invalid"
    exit 1
}
print -r -- "hardware_run=terminal raw_media_cleanup=scheduled"
