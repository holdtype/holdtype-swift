#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="HoldType"
BUNDLE_ID="app.holdtype.HoldType"
PROJECT_NAME="HoldType.xcodeproj"
SCHEME_NAME="HoldType"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/$PROJECT_NAME"
DERIVED_DATA_DIR="${HOLDTYPE_DERIVED_DATA_PATH:-}"
DEBUG_API_KEY_FILE="${HOLDTYPE_DEBUG_API_KEY_FILE:-$ROOT_DIR/Config/HoldTypeDebugAPIKey.local}"
APP_BUNDLE=""
APP_BINARY=""
INFO_PLIST=""

usage() {
    printf 'usage: %s [run|--debug|--logs|--telemetry|--verify|--verify-timeout-prompt|--verify-invalid-api-key-prompt|--live-debug|--reset-accessibility|--reset-input-monitoring]\n' "$0" >&2
}

stop_running_app() {
    local pids
    local pid
    local parent_pid
    local parent_args

    pids="$(/usr/bin/pgrep -x "$APP_NAME" || true)"
    if [[ -z "$pids" ]]; then
        return
    fi

    /bin/kill $pids >/dev/null 2>&1 || true
    sleep 1

    pids="$(/usr/bin/pgrep -x "$APP_NAME" || true)"
    if [[ -n "$pids" ]]; then
        /bin/kill -9 $pids >/dev/null 2>&1 || true
    fi

    sleep 0.5

    pids="$(/usr/bin/pgrep -x "$APP_NAME" || true)"
    while IFS= read -r pid; do
        if [[ -z "$pid" ]]; then
            continue
        fi

        parent_pid="$(/bin/ps -p "$pid" -o ppid= | /usr/bin/tr -d ' ')"
        parent_args="$(/bin/ps -p "$parent_pid" -o args= || true)"
        if [[ "$parent_args" == *"debugserver"* ]]; then
            /bin/kill -9 "$parent_pid" >/dev/null 2>&1 || true
        fi
    done <<< "$pids"
}

make_xcodebuild_args() {
    XCODEBUILD_ARGS=(
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME_NAME" \
        -configuration Debug \
        -destination 'platform=macOS'
    )

    if [[ -n "$DERIVED_DATA_DIR" ]]; then
        XCODEBUILD_ARGS+=(-derivedDataPath "$DERIVED_DATA_DIR")
    fi
}

resolve_build_paths() {
    local build_settings
    local built_products_dir
    local executable_path

    make_xcodebuild_args
    build_settings="$(/usr/bin/xcodebuild "${XCODEBUILD_ARGS[@]}" -showBuildSettings)"
    built_products_dir="$(awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { print $2; exit }' <<< "$build_settings")"
    executable_path="$(awk -F ' = ' '/^[[:space:]]*EXECUTABLE_PATH = / { print $2; exit }' <<< "$build_settings")"

    if [[ -z "$built_products_dir" || -z "$executable_path" ]]; then
        printf 'HoldType run aborted: could not resolve Xcode build product paths\n' >&2
        exit 1
    fi

    APP_BUNDLE="$built_products_dir/$APP_NAME.app"
    APP_BINARY="$built_products_dir/$executable_path"
    INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
}

build_app() {
    make_xcodebuild_args
    /usr/bin/xcodebuild "${XCODEBUILD_ARGS[@]}" build
    resolve_build_paths
}

validate_bundle_identity() {
    local actual_bundle_id

    actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
    if [[ "$actual_bundle_id" != "$BUNDLE_ID" ]]; then
        printf 'HoldType run aborted: expected bundle id %s, got %s\n' "$BUNDLE_ID" "$actual_bundle_id" >&2
        exit 1
    fi
}

ensure_stable_adhoc_tcc_identity() {
    "$ROOT_DIR/script/stabilize_adhoc_tcc_identity.sh" "$APP_BUNDLE" "$BUNDLE_ID"
}

print_signing_notice() {
    local signing_details
    local requirement

    signing_details="$(/usr/bin/codesign -dvvv "$APP_BUNDLE" 2>&1 || true)"
    if [[ "$signing_details" == *"Signature=adhoc"* || "$signing_details" == *"TeamIdentifier=not set"* ]]; then
        requirement="$(/usr/bin/codesign -d -r- "$APP_BUNDLE" 2>&1 || true)"
        if [[ "$requirement" == *"designated => cdhash"* ]]; then
            printf 'HoldType run warning: app is ad-hoc signed with a cdhash-only requirement; macOS may ask for privacy permissions again after rebuilds.\n' >&2
        else
            printf 'HoldType run warning: app is ad-hoc signed with a local stable TCC requirement.\n' >&2
        fi
        printf 'Configure Config/HoldTypeSigning.local.xcconfig with an Apple Development identity for production-like TCC permissions.\n' >&2
        printf 'Input Monitoring row creation may still fail for ad-hoc Debug builds even when Accessibility row recovery works.\n' >&2
    fi

    printf 'HoldType run app: %s\n' "$APP_BUNDLE" >&2
    if [[ -n "$DERIVED_DATA_DIR" ]]; then
        printf 'HoldType run warning: HOLDTYPE_DERIVED_DATA_PATH is set; System Settings may show a separate permission row for this app copy.\n' >&2
    fi
}

launch_app() {
    /usr/bin/env -i /usr/bin/open -n "$APP_BUNDLE" "$@"
}

open_app() {
    launch_app
}

open_app_for_automation() {
    printf 'HoldType run: launching with non-interactive Keychain policy for automation.\n' >&2
    launch_app \
        --env HOLDTYPE_AUTOMATION=1 \
        --env HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip
}

open_app_for_transcription_failure_prompt_verification() {
    local reason="$1"

    printf 'HoldType run: launching %s recovery prompt verification.\n' "$reason" >&2
    launch_app \
        --env HOLDTYPE_AUTOMATION=1 \
        --env HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
        --env HOLDTYPE_DEBUG_TRANSCRIPTION_FAILURE="$reason"
}

open_app_for_live_debug() {
    if [[ ! -f "$DEBUG_API_KEY_FILE" ]]; then
        printf 'HoldType live debug aborted: expected debug API key file at %s\n' "$DEBUG_API_KEY_FILE" >&2
        printf 'Create it from Config/HoldTypeDebugAPIKey.local.example, or set HOLDTYPE_DEBUG_API_KEY_FILE.\n' >&2
        exit 1
    fi

    printf 'HoldType run: launching with explicit Debug API key file source.\n' >&2
    launch_app \
        --env HOLDTYPE_KEY_SOURCE=debug-file \
        --env HOLDTYPE_DEBUG_API_KEY_FILE="$DEBUG_API_KEY_FILE"
}

open_app_requesting_accessibility() {
    launch_app \
        --env HOLDTYPE_AUTOMATION=1 \
        --env HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
        --env HOLDTYPE_DEBUG_REQUEST_ACCESSIBILITY=1
    verify_running_app
    sleep 2
}

open_app_requesting_input_monitoring() {
    launch_app \
        --env HOLDTYPE_AUTOMATION=1 \
        --env HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip \
        --env HOLDTYPE_REQUEST_INPUT_MONITORING_ON_LAUNCH=1 \
        --env HOLDTYPE_OPEN_INPUT_MONITORING_SETTINGS_ON_LAUNCH=1 \
        --env HOLDTYPE_EXIT_AFTER_INPUT_MONITORING_REQUEST=1 \
        --env HOLDTYPE_DEBUG_PERMISSIONS=1
    verify_running_app
    sleep 2
    stop_running_app
}

open_accessibility_settings() {
    /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
}

open_input_monitoring_settings() {
    /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'
}

reset_accessibility_permission() {
    printf 'HoldType run: resetting Accessibility permission for %s\n' "$BUNDLE_ID" >&2
    /usr/bin/tccutil reset Accessibility "$BUNDLE_ID"
}

reset_input_monitoring_permission() {
    printf 'HoldType run: resetting Input Monitoring permission for %s\n' "$BUNDLE_ID" >&2
    /usr/bin/tccutil reset ListenEvent "$BUNDLE_ID"
}

verify_running_app() {
    local pid
    local process_args

    for _ in {1..20}; do
        while IFS= read -r pid; do
            process_args="$(/bin/ps -p "$pid" -o args= || true)"
            if [[ "$process_args" == *"$APP_BINARY"* ]]; then
                return
            fi
        done < <(/usr/bin/pgrep -x "$APP_NAME" || true)

        sleep 0.25
    done

    printf 'HoldType run verification failed: %s did not launch from %s\n' "$APP_NAME" "$APP_BINARY" >&2
    exit 1
}

stop_running_app
build_app
ensure_stable_adhoc_tcc_identity
validate_bundle_identity
print_signing_notice

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        /usr/bin/lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app_for_automation
        verify_running_app
        ;;
    --verify-timeout-prompt|verify-timeout-prompt)
        open_app_for_transcription_failure_prompt_verification timeout
        verify_running_app
        ;;
    --verify-invalid-api-key-prompt|verify-invalid-api-key-prompt)
        open_app_for_transcription_failure_prompt_verification invalid-api-key
        verify_running_app
        ;;
    --live-debug|live-debug)
        open_app_for_live_debug
        verify_running_app
        ;;
    --reset-accessibility|reset-accessibility)
        reset_accessibility_permission
        open_app_requesting_accessibility
        open_accessibility_settings
        verify_running_app
        ;;
    --reset-input-monitoring|reset-input-monitoring)
        reset_input_monitoring_permission
        open_app_requesting_input_monitoring
        open_input_monitoring_settings
        open_app
        verify_running_app
        ;;
    *)
        usage
        exit 2
        ;;
esac
