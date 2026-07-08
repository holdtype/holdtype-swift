#!/usr/bin/env python3
"""Validate the local release automation setup without publishing anything."""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


REQUIRED_SECRET_NAMES = (
    "APPLE_TEAM_ID",
    "DEVELOPER_ID_CERTIFICATE_BASE64",
    "DEVELOPER_ID_CERTIFICATE_PASSWORD",
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_PRIVATE_KEY",
    "SPARKLE_EDDSA_PRIVATE_KEY",
    "HOLDTYPE_UPDATE_FEED_URL",
    "HOLDTYPE_UPDATE_PUBLIC_ED_KEY",
)

REQUIRED_COMMANDS = (
    "xcodebuild",
    "xcrun",
    "codesign",
    "spctl",
    "hdiutil",
    "ditto",
    "shasum",
    "python3",
    "gh",
)

HOMEBREW_TAP_REPOSITORY_NAME = "HOMEBREW_TAP_REPOSITORY"
HOMEBREW_EXPECTED_TAP_NAME = "HOMEBREW_EXPECTED_TAP"
HOMEBREW_TAP_TOKEN_NAME = "HOMEBREW_TAP_TOKEN"
HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED_NAME = "HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED"
HOMEBREW_OFFICIAL_CASK_FORK_ORG_NAME = "HOMEBREW_OFFICIAL_CASK_FORK_ORG"
HOMEBREW_GITHUB_API_TOKEN_NAME = "HOMEBREW_GITHUB_API_TOKEN"
HOMEBREW_MACOS_COMPARISON_PATTERN = re.compile(r"^(>=|>|<=|<|==) :[a-z][a-z0-9_]*$")

REQUIRED_PATHS = (
    "Config/ExportOptions.DeveloperID.plist",
    "Config/HoldTypeSigning.xcconfig",
    "HoldType/Info.plist",
    "HoldType.xcodeproj/project.pbxproj",
    ".github/workflows/release.yml",
    "homebrew/Casks/holdtype.rb.template",
    "scripts/release/bump_official_homebrew_cask_pr.sh",
    "scripts/release/build_release.sh",
    "scripts/release/build_preview_dmg.sh",
    "scripts/release/create_official_homebrew_cask_pr.sh",
    "scripts/release/fetch_existing_appcast.py",
    "scripts/release/generate_appcast.sh",
    "scripts/release/open_official_homebrew_cask_pr_from_bundle.sh",
    "scripts/release/prepare_official_homebrew_cask.sh",
    "scripts/release/preflight.py",
    "scripts/release/prune_github_release_assets.py",
    "scripts/release/render_homebrew_cask.sh",
    "scripts/release/update_homebrew_tap.sh",
    "scripts/release/validate_release_inputs.py",
    "scripts/release/verify_app_update_settings.py",
    "scripts/release/verify_dmg_install.sh",
    "scripts/release/verify_dmg_layout.sh",
    "scripts/release/verify_homebrew_cask.py",
    "scripts/release/verify_homebrew_tap_release.py",
    "scripts/release/verify_github_release_setup.py",
    "scripts/release/verify_install_channels.py",
    "scripts/release/verify_published_release.py",
    "scripts/release/verify_release_manifest.py",
    "scripts/release/verify_release_notes.py",
    "scripts/release/verify_release_workflow.py",
    "scripts/release/verify_release.sh",
    "scripts/release/with_timeout.py",
    "scripts/release/write_homebrew_cask_submission.py",
    "scripts/release/write_release_notes.sh",
)


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str

    def to_json(self) -> dict[str, str]:
        return {"name": self.name, "status": self.status, "message": self.message}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def warn_check(name: str, message: str) -> Check:
    return Check(name=name, status="warn", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def check_required_paths(root: Path) -> list[Check]:
    checks: list[Check] = []
    for relative_path in REQUIRED_PATHS:
        path = root / relative_path
        if path.exists():
            checks.append(pass_check(f"path:{relative_path}", "found"))
        else:
            checks.append(fail_check(f"path:{relative_path}", "missing"))
    return checks


def check_required_commands() -> list[Check]:
    checks: list[Check] = []
    for command in REQUIRED_COMMANDS:
        if shutil.which(command):
            checks.append(pass_check(f"command:{command}", "available"))
        else:
            checks.append(fail_check(f"command:{command}", "not found on PATH"))
    return checks


def check_export_options(root: Path) -> list[Check]:
    path = root / "Config/ExportOptions.DeveloperID.plist"
    if not path.exists():
        return [fail_check("export-options", "Config/ExportOptions.DeveloperID.plist is missing")]

    try:
        with path.open("rb") as handle:
            plist = plistlib.load(handle)
    except Exception as error:  # noqa: BLE001 - surface plist parsing failure to operator
        return [fail_check("export-options", f"could not parse plist: {error}")]

    checks = []
    method = plist.get("method")
    signing_style = plist.get("signingStyle")
    if method == "developer-id":
        checks.append(pass_check("export-options:method", "developer-id"))
    else:
        checks.append(fail_check("export-options:method", f"expected developer-id, got {method!r}"))

    if signing_style == "automatic":
        checks.append(pass_check("export-options:signingStyle", "automatic"))
    else:
        checks.append(
            fail_check("export-options:signingStyle", f"expected automatic, got {signing_style!r}")
        )
    return checks


def check_info_plist(root: Path) -> list[Check]:
    path = root / "HoldType/Info.plist"
    if not path.exists():
        return [fail_check("info-plist", "HoldType/Info.plist is missing")]

    try:
        with path.open("rb") as handle:
            plist = plistlib.load(handle)
    except Exception as error:  # noqa: BLE001
        return [fail_check("info-plist", f"could not parse plist: {error}")]

    checks = []
    expected_values = {
        "SUFeedURL": "$(HOLDTYPE_UPDATE_FEED_URL)",
        "SUPublicEDKey": "$(HOLDTYPE_UPDATE_PUBLIC_ED_KEY)",
    }
    for key, expected in expected_values.items():
        value = plist.get(key)
        if value == expected:
            checks.append(pass_check(f"info-plist:{key}", f"uses {expected}"))
        else:
            checks.append(fail_check(f"info-plist:{key}", f"expected {expected!r}, got {value!r}"))
    return checks


def parse_xcode_build_settings(output: str) -> dict[str, str]:
    settings: dict[str, str] = {}
    for line in output.splitlines():
        match = re.match(r"\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$", line)
        if match:
            settings[match.group(1)] = match.group(2)
    return settings


def check_xcode_release_settings(root: Path, timeout_seconds: int) -> list[Check]:
    command = [
        "xcodebuild",
        "-project",
        "HoldType.xcodeproj",
        "-target",
        "HoldType",
        "-configuration",
        "Release",
        "-showBuildSettings",
    ]
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            check=False,
        )
    except FileNotFoundError:
        return [fail_check("xcode-settings", "xcodebuild is not available")]
    except subprocess.TimeoutExpired:
        return [fail_check("xcode-settings", f"xcodebuild timed out after {timeout_seconds}s")]

    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        message = detail[-1] if detail else f"xcodebuild exited {result.returncode}"
        return [fail_check("xcode-settings", message)]

    settings = parse_xcode_build_settings(result.stdout)
    checks = []
    hardened_runtime = settings.get("ENABLE_HARDENED_RUNTIME")
    if hardened_runtime == "YES":
        checks.append(pass_check("xcode-settings:ENABLE_HARDENED_RUNTIME", "YES"))
    else:
        checks.append(
            fail_check(
                "xcode-settings:ENABLE_HARDENED_RUNTIME",
                f"expected YES, got {hardened_runtime!r}",
            )
        )

    deployment_target = settings.get("MACOSX_DEPLOYMENT_TARGET")
    if deployment_target:
        checks.append(
            warn_check(
                "xcode-settings:MACOSX_DEPLOYMENT_TARGET",
                f"current minimum macOS is {deployment_target}; confirm before public release",
            )
        )
    else:
        checks.append(fail_check("xcode-settings:MACOSX_DEPLOYMENT_TARGET", "missing"))
    return checks


def check_homebrew_template(root: Path) -> list[Check]:
    path = root / "homebrew/Casks/holdtype.rb.template"
    if not path.exists():
        return [fail_check("homebrew-template", "template is missing")]

    text = path.read_text()
    checks = []
    required_fragments = (
        'cask "holdtype" do',
        'sha256 "{{SHA256}}"',
        "https://github.com/{{REPOSITORY}}/releases/download/v#{version}/HoldType-#{version}.dmg",
        "auto_updates true",
        'app "HoldType.app"',
        'uninstall quit: "app.holdtype.HoldType"',
        "zap trash: [",
        '"~/Library/Caches/HoldType"',
        '"~/Library/Preferences/app.holdtype.HoldType.plist"',
        '"~/Library/Saved Application State/app.holdtype.HoldType.savedState"',
    )
    for fragment in required_fragments:
        if fragment in text:
            checks.append(pass_check(f"homebrew-template:{fragment[:24]}", "present"))
        else:
            checks.append(fail_check("homebrew-template", f"missing fragment: {fragment}"))
    return checks


def check_release_workflow(root: Path) -> list[Check]:
    script_path = root / "scripts/release/verify_release_workflow.py"
    workflow_path = root / ".github/workflows/release.yml"
    if not script_path.exists():
        return [fail_check("release-workflow", f"missing {script_path}")]

    try:
        result = subprocess.run(
            [sys.executable, str(script_path), "--workflow", str(workflow_path), "--json"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return [fail_check("release-workflow", "workflow verifier timed out")]

    detail = (result.stderr or result.stdout).strip()
    if result.returncode == 0:
        return [pass_check("release-workflow", "workflow wiring verified")]
    return [fail_check("release-workflow", detail or f"verifier exited {result.returncode}")]


def check_secret_environment(require_secrets: bool, environment: dict[str, str]) -> list[Check]:
    checks: list[Check] = []
    for name in REQUIRED_SECRET_NAMES:
        value = environment.get(name, "")
        if value:
            checks.append(pass_check(f"secret:{name}", "present"))
        elif require_secrets:
            checks.append(fail_check(f"secret:{name}", "missing"))
        else:
            checks.append(warn_check(f"secret:{name}", "missing; required for notarized release"))
    return checks


def validate_homebrew_tap_repository(repository: str) -> bool:
    parts = repository.split("/", 1)
    return len(parts) == 2 and all(part and " " not in part and "/" not in part for part in parts)


def validate_homebrew_tap_repository_name(repository: str) -> bool:
    if not validate_homebrew_tap_repository(repository):
        return False
    repo_name = repository.split("/", 1)[1]
    return repo_name.startswith("homebrew-") and len(repo_name) > len("homebrew-")


def validate_homebrew_tap_prefix(value: str) -> bool:
    parts = value.split("/", 1)
    return len(parts) == 2 and all(part and " " not in part and "/" not in part for part in parts)


def homebrew_tap_install_prefix(repository: str) -> str:
    owner, repo_name = repository.split("/", 1)
    return f"{owner}/{repo_name.removeprefix('homebrew-')}"


def parse_boolean_flag(value: str) -> bool | None:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off", ""}:
        return False
    return None


def validate_github_owner(value: str) -> bool:
    return bool(value) and "/" not in value and " " not in value


def check_homebrew_tap_environment(
    environment: dict[str, str],
    *,
    require_homebrew_tap: bool = False,
) -> list[Check]:
    repository = environment.get(HOMEBREW_TAP_REPOSITORY_NAME, "")
    expected_tap = environment.get(HOMEBREW_EXPECTED_TAP_NAME, "")
    token = environment.get(HOMEBREW_TAP_TOKEN_NAME, "")

    if not repository and not token and not require_homebrew_tap:
        return [
            warn_check(
                "homebrew-tap",
                "HOMEBREW_TAP_REPOSITORY variable and HOMEBREW_TAP_TOKEN secret are missing; tap PR will be skipped",
            )
        ]

    checks: list[Check] = []
    derived_tap = ""
    if repository:
        if validate_homebrew_tap_repository(repository):
            checks.append(pass_check(f"config:{HOMEBREW_TAP_REPOSITORY_NAME}", repository))
            if validate_homebrew_tap_repository_name(repository):
                derived_tap = homebrew_tap_install_prefix(repository)
                checks.append(
                    pass_check(
                        f"config:{HOMEBREW_TAP_REPOSITORY_NAME}:tap-name",
                        derived_tap,
                    )
                )
            else:
                repo_name = repository.split("/", 1)[1]
                checks.append(
                    fail_check(
                        f"config:{HOMEBREW_TAP_REPOSITORY_NAME}:repository-name",
                        f"expected repository name to start with homebrew-, got {repo_name!r}",
                    )
                )
        else:
            checks.append(
                fail_check(
                    f"config:{HOMEBREW_TAP_REPOSITORY_NAME}",
                    f"expected OWNER/REPO, got {repository!r}",
                )
            )
    else:
        checks.append(
            fail_check(
                f"config:{HOMEBREW_TAP_REPOSITORY_NAME}",
                "missing; required with Homebrew tap automation",
            )
        )

    if expected_tap:
        if not validate_homebrew_tap_prefix(expected_tap):
            checks.append(
                fail_check(
                    f"config:{HOMEBREW_EXPECTED_TAP_NAME}",
                    f"expected OWNER/TAP, got {expected_tap!r}",
                )
            )
        elif derived_tap and expected_tap != derived_tap:
            checks.append(
                fail_check(
                    f"config:{HOMEBREW_EXPECTED_TAP_NAME}",
                    f"expected {expected_tap}, but {repository} installs as {derived_tap}",
                )
            )
        else:
            checks.append(pass_check(f"config:{HOMEBREW_EXPECTED_TAP_NAME}", expected_tap))
    elif require_homebrew_tap or repository or token:
        checks.append(
            fail_check(
                f"config:{HOMEBREW_EXPECTED_TAP_NAME}",
                "missing; set to the public tap prefix such as holdtype/tap",
            )
        )

    if token:
        checks.append(pass_check(f"secret:{HOMEBREW_TAP_TOKEN_NAME}", "present"))
    else:
        checks.append(
            fail_check(
                f"secret:{HOMEBREW_TAP_TOKEN_NAME}",
                "missing; required with Homebrew tap automation",
            )
        )

    minimum_macos = environment.get("HOMEBREW_MINIMUM_MACOS", "")
    if minimum_macos and HOMEBREW_MACOS_COMPARISON_PATTERN.fullmatch(minimum_macos):
        checks.append(pass_check("homebrew:minimum-macos", minimum_macos))
    elif minimum_macos:
        checks.append(
            fail_check(
                "homebrew:minimum-macos",
                'expected Homebrew comparison expression such as ">= :tahoe"',
            )
        )
    else:
        checks.append(
            fail_check(
                "homebrew:minimum-macos",
                "missing; required with Homebrew tap automation",
            )
        )

    if shutil.which("brew"):
        checks.append(pass_check("command:brew", "available for Homebrew tap audit"))
    else:
        checks.append(fail_check("command:brew", "required when Homebrew tap automation is configured"))
    return checks


def check_official_homebrew_cask_bump_environment(environment: dict[str, str]) -> list[Check]:
    enabled_value = environment.get(HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED_NAME, "")
    token = environment.get(HOMEBREW_GITHUB_API_TOKEN_NAME, "")
    fork_org = environment.get(HOMEBREW_OFFICIAL_CASK_FORK_ORG_NAME, "")
    enabled = parse_boolean_flag(enabled_value)

    if enabled is None:
        return [
            fail_check(
                f"config:{HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED_NAME}",
                "expected true or false",
            )
        ]

    if not enabled:
        return [
            warn_check(
                "homebrew-official-cask-bump",
                "disabled; official Homebrew Cask updates stay manual after upstream acceptance",
            )
        ]

    checks: list[Check] = [
        pass_check(f"config:{HOMEBREW_OFFICIAL_CASK_BUMP_ENABLED_NAME}", "true")
    ]
    if token:
        checks.append(pass_check(f"secret:{HOMEBREW_GITHUB_API_TOKEN_NAME}", "present"))
    else:
        checks.append(
            fail_check(
                f"secret:{HOMEBREW_GITHUB_API_TOKEN_NAME}",
                "missing; required to open official Homebrew Cask bump PRs",
            )
        )

    if fork_org:
        if validate_github_owner(fork_org):
            checks.append(pass_check(f"config:{HOMEBREW_OFFICIAL_CASK_FORK_ORG_NAME}", fork_org))
        else:
            checks.append(
                fail_check(
                    f"config:{HOMEBREW_OFFICIAL_CASK_FORK_ORG_NAME}",
                    f"expected a GitHub owner or organization, got {fork_org!r}",
                )
            )

    if shutil.which("brew"):
        checks.append(pass_check("command:brew", "available for official Homebrew Cask bump PRs"))
    else:
        checks.append(
            fail_check(
                "command:brew",
                "required when official Homebrew Cask bump automation is enabled",
            )
        )
    return checks


def check_generate_appcast() -> Check:
    derived_data = Path.home() / "Library/Developer/Xcode/DerivedData"
    candidates = []
    if derived_data.exists():
        candidates = list(
            derived_data.glob("*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast")
        )
    if candidates:
        return pass_check("sparkle:generate_appcast", str(candidates[0]))
    return warn_check(
        "sparkle:generate_appcast",
        "not found yet; xcodebuild -resolvePackageDependencies should fetch Sparkle artifacts",
    )


def collect_checks(
    root: Path,
    *,
    require_secrets: bool,
    require_homebrew_tap: bool,
    skip_xcodebuild: bool,
    timeout_seconds: int,
    environment: dict[str, str],
) -> list[Check]:
    checks: list[Check] = []
    checks.extend(check_required_paths(root))
    checks.extend(check_required_commands())
    checks.extend(check_export_options(root))
    checks.extend(check_info_plist(root))
    checks.extend(check_homebrew_template(root))
    checks.extend(check_release_workflow(root))
    checks.extend(check_secret_environment(require_secrets, environment))
    checks.extend(
        check_homebrew_tap_environment(
            environment,
            require_homebrew_tap=require_homebrew_tap,
        )
    )
    checks.extend(check_official_homebrew_cask_bump_environment(environment))
    checks.append(check_generate_appcast())
    if skip_xcodebuild:
        checks.append(warn_check("xcode-settings", "skipped by --skip-xcodebuild"))
    else:
        checks.extend(check_xcode_release_settings(root, timeout_seconds))
    return checks


def print_text(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-secrets", action="store_true")
    parser.add_argument("--require-homebrew-tap", action="store_true")
    parser.add_argument("--skip-xcodebuild", action="store_true")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args()

    checks = collect_checks(
        repo_root(),
        require_secrets=args.require_secrets,
        require_homebrew_tap=args.require_homebrew_tap,
        skip_xcodebuild=args.skip_xcodebuild,
        timeout_seconds=args.timeout,
        environment=dict(os.environ),
    )
    if args.json:
        print(json.dumps({"checks": [check.to_json() for check in checks]}, indent=2))
    else:
        print_text(checks)

    has_failures = any(check.status == "fail" for check in checks)
    has_warnings = any(check.status == "warn" for check in checks)
    if has_failures or (args.strict and has_warnings):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
