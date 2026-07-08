#!/usr/bin/env python3
"""Verify the published project-owned Homebrew tap cask after PR merge."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CASK_TOKEN = "holdtype"
TAP_CASK_PATH = f"Casks/{CASK_TOKEN}.rb"
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str

    def to_json(self) -> dict[str, str]:
        return {"name": self.name, "status": self.status, "message": self.message}


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def print_checks(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def validate_repository(value: str, *, check_name: str) -> Check | None:
    parts = value.split("/", 1)
    if (
        len(parts) == 2
        and parts[0]
        and parts[1]
        and " " not in parts[0]
        and " " not in parts[1]
        and "/" not in parts[1]
    ):
        return None
    return fail_check(check_name, f"expected OWNER/REPO, got {value!r}")


def validate_sha256(value: str) -> Check | None:
    if SHA256_PATTERN.fullmatch(value.lower()):
        return None
    return fail_check("sha256", "expected 64 hexadecimal characters")


def validate_homebrew_tap_repository_name(repository: str) -> Check | None:
    repo_name = repository.split("/", 1)[1]
    if repo_name.startswith("homebrew-") and len(repo_name) > len("homebrew-"):
        return None
    return fail_check(
        "homebrew-tap:repository-name",
        f"expected repository name to start with homebrew-, got {repo_name!r}",
    )


def validate_homebrew_tap_prefix(value: str) -> Check | None:
    parts = value.split("/", 1)
    if len(parts) == 2 and all(part and " " not in part and "/" not in part for part in parts):
        return None
    return fail_check("homebrew-tap:expected-prefix", f"expected OWNER/TAP, got {value!r}")


def homebrew_tap_install_prefix(repository: str) -> str:
    owner, repo_name = repository.split("/", 1)
    return f"{owner}/{repo_name.removeprefix('homebrew-')}"


def request_headers(token: str) -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "holdtype-homebrew-tap-release-verifier",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def github_get_json(url: str, *, token: str, timeout: int) -> tuple[Any | None, Check | None]:
    request = urllib.request.Request(url, headers=request_headers(token))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8")), None
    except urllib.error.HTTPError as error:
        try:
            body = error.read().decode("utf-8")
        except Exception:  # noqa: BLE001 - best-effort API error detail
            body = ""
        detail = f"HTTP {error.code}"
        if body:
            try:
                parsed = json.loads(body)
            except json.JSONDecodeError:
                detail = f"{detail}: {body.strip()}"
            else:
                message = parsed.get("message") if isinstance(parsed, dict) else None
                if message:
                    detail = f"{detail}: {message}"
        return None, fail_check("github-api", f"{url}: {detail}")
    except (OSError, json.JSONDecodeError) as error:
        return None, fail_check("github-api", f"{url}: {error}")


def repo_api_url(api_base_url: str, repository: str, suffix: str) -> str:
    base = api_base_url.rstrip("/")
    owner, repo = repository.split("/", 1)
    quoted_owner = urllib.parse.quote(owner, safe="")
    quoted_repo = urllib.parse.quote(repo, safe="")
    repo_url = f"{base}/repos/{quoted_owner}/{quoted_repo}"
    normalized_suffix = suffix.strip("/")
    if normalized_suffix:
        return f"{repo_url}/{normalized_suffix}"
    return repo_url


def check_tap_repository(payload: Any, *, expected_repository: str) -> tuple[str, list[Check]]:
    if not isinstance(payload, dict):
        return "", [fail_check("github-tap-repository", "API response is not an object")]

    checks: list[Check] = []
    full_name = payload.get("full_name")
    if full_name == expected_repository:
        checks.append(pass_check("github-tap-repository:name", expected_repository))
    else:
        checks.append(
            fail_check(
                "github-tap-repository:name",
                f"expected {expected_repository}, got {full_name!r}",
            )
        )

    private = payload.get("private")
    if private is False:
        checks.append(pass_check("github-tap-repository:visibility", "public"))
    else:
        checks.append(
            fail_check(
                "github-tap-repository:visibility",
                f"expected public repository, got private={private!r}",
            )
        )

    archived = payload.get("archived")
    if archived is False:
        checks.append(pass_check("github-tap-repository:archived", "false"))
    else:
        checks.append(
            fail_check(
                "github-tap-repository:archived",
                f"expected false, got {archived!r}",
            )
        )

    default_branch = payload.get("default_branch")
    if isinstance(default_branch, str) and default_branch:
        checks.append(pass_check("github-tap-repository:default-branch", default_branch))
    else:
        checks.append(fail_check("github-tap-repository:default-branch", "missing"))
        default_branch = ""
    return default_branch, checks


def decode_github_content(payload: Any) -> tuple[str, list[Check]]:
    if not isinstance(payload, dict):
        return "", [fail_check("github-tap-cask", "API response is not an object")]

    checks: list[Check] = []
    path = payload.get("path")
    if path == TAP_CASK_PATH:
        checks.append(pass_check("github-tap-cask:path", TAP_CASK_PATH))
    else:
        checks.append(fail_check("github-tap-cask:path", f"expected {TAP_CASK_PATH}, got {path!r}"))

    content_type = payload.get("type")
    if content_type == "file":
        checks.append(pass_check("github-tap-cask:type", "file"))
    else:
        checks.append(fail_check("github-tap-cask:type", f"expected file, got {content_type!r}"))

    encoding = payload.get("encoding")
    content = payload.get("content")
    if encoding != "base64" or not isinstance(content, str) or not content:
        checks.append(fail_check("github-tap-cask:content", "missing base64 file content"))
        return "", checks

    try:
        decoded = base64.b64decode("".join(content.split()), validate=True).decode("utf-8")
    except (binascii.Error, UnicodeDecodeError) as error:
        checks.append(fail_check("github-tap-cask:content", f"could not decode content: {error}"))
        return "", checks

    checks.append(pass_check("github-tap-cask:content", "decoded"))
    return decoded, checks


def verify_cask_text(
    *,
    text: str,
    version: str,
    sha256: str,
    repository: str,
    minimum_macos: str,
    timeout: int,
) -> list[Check]:
    with tempfile.TemporaryDirectory(prefix="holdtype-tap-cask-") as temp_dir:
        cask_path = Path(temp_dir) / TAP_CASK_PATH
        cask_path.parent.mkdir(parents=True, exist_ok=True)
        cask_path.write_text(text)

        command = [
            sys.executable,
            str(repo_root() / "scripts" / "release" / "verify_homebrew_cask.py"),
            "--cask-path",
            str(cask_path),
            "--version",
            version,
            "--sha256",
            sha256.lower(),
            "--repository",
            repository,
            "--minimum-macos",
            minimum_macos,
            "--require-minimum-macos",
            "--json",
        ]
        try:
            result = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return [fail_check("homebrew-cask:verify", f"timed out after {timeout}s")]

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        detail = (result.stderr or result.stdout).strip()
        return [fail_check("homebrew-cask:verify", detail or f"exited {result.returncode}")]

    checks: list[Check] = []
    for raw_check in payload.get("checks", []):
        if not isinstance(raw_check, dict):
            continue
        name = raw_check.get("name")
        status = raw_check.get("status")
        message = raw_check.get("message")
        if isinstance(name, str) and isinstance(status, str) and isinstance(message, str):
            checks.append(Check(name=name, status=status, message=message))
    if not checks:
        checks.append(fail_check("homebrew-cask:verify", "no checks returned"))
    return checks


def collect_checks(args: argparse.Namespace) -> list[Check]:
    checks: list[Check] = []
    for value, check_name in (
        (args.repository, "repository"),
        (args.tap_repository, "homebrew-tap:repository"),
    ):
        error = validate_repository(value, check_name=check_name)
        if error is not None:
            checks.append(error)

    sha_error = validate_sha256(args.sha256)
    if sha_error is not None:
        checks.append(sha_error)
    if not args.version or args.version.startswith("v") or " " in args.version:
        checks.append(fail_check("version", f"expected release version without leading v, got {args.version!r}"))
    if not args.minimum_macos:
        checks.append(fail_check("minimum-macos", "missing"))
    if checks:
        return checks

    tap_name_error = validate_homebrew_tap_repository_name(args.tap_repository)
    if tap_name_error is None:
        checks.append(pass_check("homebrew-tap:repository-name", args.tap_repository.split("/", 1)[1]))
    else:
        checks.append(tap_name_error)

    derived_tap = homebrew_tap_install_prefix(args.tap_repository)
    expected_tap = args.expected_homebrew_tap or derived_tap
    expected_tap_error = validate_homebrew_tap_prefix(expected_tap)
    if expected_tap_error is None:
        if expected_tap == derived_tap:
            checks.append(pass_check("homebrew-tap:expected-prefix", expected_tap))
        else:
            checks.append(
                fail_check(
                    "homebrew-tap:expected-prefix",
                    f"expected {expected_tap}, but {args.tap_repository} installs as {derived_tap}",
                )
            )
    else:
        checks.append(expected_tap_error)
    checks.append(
        pass_check(
            "homebrew-tap:install-command",
            f"brew tap {expected_tap} && brew install --cask {CASK_TOKEN}",
        )
    )
    if any(check.status == "fail" for check in checks):
        return checks

    token = os.environ.get(args.github_token_env, "")
    tap_payload, tap_error = github_get_json(
        repo_api_url(args.github_api_url, args.tap_repository, ""),
        token=token,
        timeout=args.timeout,
    )
    if tap_error is not None:
        checks.append(tap_error)
        return checks
    default_branch, tap_checks = check_tap_repository(tap_payload, expected_repository=args.tap_repository)
    checks.extend(tap_checks)
    ref = args.ref or default_branch
    if not ref:
        return checks

    content_url = repo_api_url(
        args.github_api_url,
        args.tap_repository,
        f"contents/{TAP_CASK_PATH}?ref={urllib.parse.quote(ref, safe='')}",
    )
    cask_payload, cask_error = github_get_json(content_url, token=token, timeout=args.timeout)
    if cask_error is not None:
        checks.append(cask_error)
        return checks
    cask_text, content_checks = decode_github_content(cask_payload)
    checks.extend(content_checks)
    if cask_text:
        checks.extend(
            verify_cask_text(
                text=cask_text,
                version=args.version,
                sha256=args.sha256,
                repository=args.repository,
                minimum_macos=args.minimum_macos,
                timeout=args.timeout,
            )
        )
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--tap-repository", default=os.environ.get("HOMEBREW_TAP_REPOSITORY", ""))
    parser.add_argument("--expected-homebrew-tap", default=os.environ.get("HOMEBREW_EXPECTED_TAP", ""))
    parser.add_argument("--version", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--minimum-macos", default=os.environ.get("HOMEBREW_MINIMUM_MACOS", ""))
    parser.add_argument("--ref", default="")
    parser.add_argument("--github-api-url", default=os.environ.get("GITHUB_API_URL", "https://api.github.com"))
    parser.add_argument("--github-token-env", default="GITHUB_TOKEN")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    checks = collect_checks(args)
    if args.json:
        print(json.dumps({"checks": [check.to_json() for check in checks]}, indent=2))
    else:
        print_checks(checks)
    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
