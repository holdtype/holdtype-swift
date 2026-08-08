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

usage() {
    print -r -- "usage: $program_name [--help|--build-only|--hardware --camera-id ID [--duration SECONDS] [--case-id ID]]"
    print -r -- ""
    print -r -- "--build-only  compile the Debug harness without launching camera or microphone"
    print -r -- "--hardware    explicit future hardware mode; never implied by another option"
}

timeout_command() {
    if command -v timeout >/dev/null 2>&1; then
        command timeout "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        command gtimeout "$@"
    else
        print -u2 -r -- "error: a bounded timeout command is required"
        return 127
    fi
}

case "$mode" in
    --help|-h|help)
        usage
        exit 0
        ;;
    --build-only)
        shift
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
        [[ "$capture_duration" == <1-900> ]] || {
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

run_root=$(mktemp -d "${TMPDIR%/}/holdtype-dv-p0b.XXXXXX")
resolved_temp_root=${TMPDIR:A}
resolved_run_root=${run_root:A}

cleanup() {
    if [[ "$resolved_run_root" != "$resolved_temp_root"/holdtype-dv-p0b.* ]]; then
        print -u2 -r -- "cleanup refused: run root did not match the exact temporary prefix"
        return 1
    fi
    if [[ -d "$resolved_run_root" ]]; then
        rm -rf -- "$resolved_run_root"
    fi
}
trap cleanup EXIT INT TERM

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

build_settings=$(xcodebuild \
    -project HoldType.xcodeproj \
    -scheme HoldType \
    -configuration Debug \
    -destination 'platform=macOS' \
    -showBuildSettings)
target_build_directory=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')
full_product_name=$(print -r -- "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')
app_binary="$target_build_directory/$full_product_name/Contents/MacOS/HoldType"
[[ -x "$app_binary" ]] || { print -u2 -r -- "error: Debug app binary is unavailable"; exit 1; }

hardware_timeout_seconds=$(( capture_duration + 360 ))
HOLDTYPE_AUTOMATION=1 \
HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
HOLDTYPE_DEV_VLOGS_PHASE_0B=1 \
HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT="$resolved_run_root" \
HOLDTYPE_DEV_VLOGS_PHASE_0B_CAMERA_ID="$camera_id" \
HOLDTYPE_DEV_VLOGS_PHASE_0B_DURATION="$capture_duration" \
HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID="$case_id" \
timeout_command "$hardware_timeout_seconds" "$app_binary"

print -r -- "hardware_run=terminal raw_media_cleanup=scheduled"
