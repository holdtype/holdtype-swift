#!/usr/bin/env python3
"""Prune unexpected assets from an existing GitHub Release."""

from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


APP_NAME = "HoldType"


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str


def pass_check(name: str, message: str) -> Check:
    return Check(name=name, status="pass", message=message)


def warn_check(name: str, message: str) -> Check:
    return Check(name=name, status="warn", message=message)


def fail_check(name: str, message: str) -> Check:
    return Check(name=name, status="fail", message=message)


def print_checks(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def request_headers(token: str) -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "holdtype-release-asset-pruner",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def validate_repository_slug(value: str) -> bool:
    parts = value.split("/", 1)
    return (
        len(parts) == 2
        and bool(parts[0])
        and bool(parts[1])
        and " " not in parts[0]
        and " " not in parts[1]
        and "/" not in parts[1]
    )


def release_api_url(api_base_url: str, repository: str, tag: str) -> str:
    base = api_base_url.rstrip("/")
    quoted_repo = "/".join(urllib.parse.quote(part, safe="") for part in repository.split("/", 1))
    return f"{base}/repos/{quoted_repo}/releases/tags/{urllib.parse.quote(tag, safe='')}"


def asset_delete_url(api_base_url: str, repository: str, asset_id: int) -> str:
    base = api_base_url.rstrip("/")
    quoted_repo = "/".join(urllib.parse.quote(part, safe="") for part in repository.split("/", 1))
    return f"{base}/repos/{quoted_repo}/releases/assets/{asset_id}"


def expected_asset_names(version: str) -> set[str]:
    return {
        f"{APP_NAME}-{version}.dmg",
        f"{APP_NAME}-{version}.zip",
        "SHA256SUMS.txt",
        "release-manifest.json",
        "appcast.xml",
    }


def fetch_release(
    *,
    url: str,
    timeout: int,
    token: str,
) -> tuple[dict[str, Any] | None, list[Check]]:
    request = urllib.request.Request(url, headers=request_headers(token))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None, [pass_check("github-release:prune", "release does not exist yet")]
        return None, [fail_check("github-release:prune", f"{url}: HTTP {error.code}")]
    except (OSError, json.JSONDecodeError, UnicodeDecodeError, urllib.error.URLError) as error:
        return None, [fail_check("github-release:prune", f"{url}: {error}")]

    if not isinstance(payload, dict):
        return None, [fail_check("github-release:prune", "API response is not an object")]
    return payload, [pass_check("github-release:prune", url)]


def unexpected_assets(release: dict[str, Any], *, expected_names: set[str]) -> list[dict[str, Any]]:
    assets = release.get("assets", [])
    if not isinstance(assets, list):
        return []
    unexpected: list[dict[str, Any]] = []
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = asset.get("name")
        if isinstance(name, str) and name and name not in expected_names:
            unexpected.append(asset)
    return unexpected


def delete_asset(
    *,
    api_base_url: str,
    repository: str,
    asset: dict[str, Any],
    timeout: int,
    token: str,
) -> Check:
    name = asset.get("name")
    asset_id = asset.get("id")
    if not isinstance(name, str) or not name:
        return fail_check("github-asset-prune", "unexpected asset is missing name")
    if not isinstance(asset_id, int):
        return fail_check(f"github-asset-prune:{name}", "unexpected asset is missing numeric id")
    if not token:
        return fail_check(f"github-asset-prune:{name}", "missing GitHub token for --apply")

    url = asset_delete_url(api_base_url, repository, asset_id)
    request = urllib.request.Request(url, headers=request_headers(token), method="DELETE")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = getattr(response, "status", response.getcode())
    except urllib.error.HTTPError as error:
        return fail_check(f"github-asset-prune:{name}", f"delete failed: HTTP {error.code}")
    except (OSError, urllib.error.URLError) as error:
        return fail_check(f"github-asset-prune:{name}", f"delete failed: {error}")

    if status == 204:
        return pass_check(f"github-asset-prune:{name}", f"deleted asset id {asset_id}")
    return fail_check(f"github-asset-prune:{name}", f"delete returned HTTP {status}")


def check_or_prune_assets(
    release: dict[str, Any],
    *,
    api_base_url: str,
    repository: str,
    expected_names: set[str],
    timeout: int,
    token: str,
    apply: bool,
) -> list[Check]:
    checks: list[Check] = []
    unexpected = unexpected_assets(release, expected_names=expected_names)
    if not unexpected:
        return [pass_check("github-assets:prune-unexpected", "none")]

    names = ", ".join(sorted(str(asset.get("name", "")) for asset in unexpected))
    if not apply:
        return [
            warn_check(
                "github-assets:prune-unexpected",
                f"dry run; would delete unexpected assets: {names}",
            )
        ]

    checks.append(pass_check("github-assets:prune-unexpected", f"deleting {names}"))
    for asset in unexpected:
        checks.append(
            delete_asset(
                api_base_url=api_base_url,
                repository=repository,
                asset=asset,
                timeout=timeout,
                token=token,
            )
        )
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", default="")
    parser.add_argument("--github-api-url", default=os.environ.get("GITHUB_API_URL", "https://api.github.com"))
    parser.add_argument("--github-token-env", default="GITHUB_TOKEN")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    checks: list[Check] = []
    if not args.repository:
        checks.append(fail_check("repository", "missing --repository or GITHUB_REPOSITORY"))
    elif not validate_repository_slug(args.repository):
        checks.append(fail_check("repository", f"expected OWNER/REPO, got {args.repository!r}"))
    if args.version.startswith("v"):
        checks.append(fail_check("version", "must not include leading v"))
    if checks:
        print_checks(checks)
        return 1

    tag = args.tag or f"v{args.version}"
    token = os.environ.get(args.github_token_env, "")
    url = release_api_url(args.github_api_url, args.repository, tag)
    release, release_checks = fetch_release(url=url, timeout=args.timeout, token=token)
    checks.extend(release_checks)
    if release is not None:
        checks.extend(
            check_or_prune_assets(
                release,
                api_base_url=args.github_api_url,
                repository=args.repository,
                expected_names=expected_asset_names(args.version),
                timeout=args.timeout,
                token=token,
                apply=args.apply,
            )
        )

    print_checks(checks)
    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
