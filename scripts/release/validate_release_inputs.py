#!/usr/bin/env python3
"""Validate release workflow inputs before expensive build and publish steps."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.parse
from dataclasses import dataclass
from pathlib import Path


APP_NAME = "HoldType"
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$")
BUILD_PATTERN = re.compile(r"^[0-9]+$")


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


def validate_version(version: str) -> list[Check]:
    if not version:
        return [fail_check("version", "missing")]
    if version.startswith("v"):
        return [fail_check("version", "must not include a leading v")]
    if not VERSION_PATTERN.fullmatch(version):
        return [
            fail_check(
                "version",
                "expected numeric public version like 1.0.0 or 1.0.0-beta.1",
            )
        ]
    return [pass_check("version", version)]


def validate_build(build: str) -> list[Check]:
    if not build:
        return [fail_check("build", "missing")]
    if not BUILD_PATTERN.fullmatch(build):
        return [fail_check("build", "must be a positive integer string")]
    if int(build) <= 0:
        return [fail_check("build", "must be greater than zero")]
    return [pass_check("build", build)]


def validate_tag(version: str, tag: str) -> list[Check]:
    normalized_version = version[1:] if version.startswith("v") else version
    expected = f"v{normalized_version}"
    if tag == expected:
        return [pass_check("tag", tag)]
    return [fail_check("tag", f"expected {expected}, got {tag!r}")]


def validate_release_dir(tag: str, release_dir: str) -> list[Check]:
    if not release_dir:
        return [fail_check("release-dir", "missing")]

    parts = Path(release_dir).parts
    if len(parts) >= 3 and parts[-3:] == ("dist", "release", tag):
        return [pass_check("release-dir", release_dir)]
    return [fail_check("release-dir", f"expected path ending in dist/release/{tag}")]


def validate_download_url_prefix(version: str, tag: str, download_url_prefix: str) -> list[Check]:
    if not download_url_prefix:
        return [fail_check("download-url-prefix", "missing")]

    checks: list[Check] = []
    parsed = urllib.parse.urlparse(download_url_prefix)
    if parsed.scheme == "https":
        checks.append(pass_check("download-url-prefix:scheme", "https"))
    else:
        checks.append(
            fail_check("download-url-prefix:scheme", f"expected https, got {parsed.scheme!r}")
        )

    if parsed.netloc == "github.com":
        checks.append(pass_check("download-url-prefix:host", "github.com"))
    else:
        checks.append(
            fail_check("download-url-prefix:host", f"expected github.com, got {parsed.netloc!r}")
        )

    if download_url_prefix.endswith("/"):
        checks.append(pass_check("download-url-prefix:trailing-slash", "present"))
    else:
        checks.append(fail_check("download-url-prefix:trailing-slash", "missing"))

    path_parts = [part for part in parsed.path.split("/") if part]
    if len(path_parts) >= 5 and path_parts[-3:] == ["releases", "download", tag]:
        checks.append(pass_check("download-url-prefix:path", parsed.path))
    else:
        checks.append(
            fail_check(
                "download-url-prefix:path",
                f"expected /<owner>/<repo>/releases/download/{tag}/",
            )
        )

    expected_dmg_name = f"{APP_NAME}-{version}.dmg"
    checks.append(pass_check("download-url-prefix:dmg-name", expected_dmg_name))
    return checks


def collect_checks(
    *,
    version: str,
    build: str,
    tag: str,
    release_dir: str,
    download_url_prefix: str,
) -> list[Check]:
    checks: list[Check] = []
    checks.extend(validate_version(version))
    checks.extend(validate_build(build))
    checks.extend(validate_tag(version, tag))
    checks.extend(validate_release_dir(tag, release_dir))
    checks.extend(validate_download_url_prefix(version, tag, download_url_prefix))
    return checks


def print_text(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--release-dir", required=True)
    parser.add_argument("--download-url-prefix", required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    checks = collect_checks(
        version=args.version,
        build=args.build,
        tag=args.tag,
        release_dir=args.release_dir,
        download_url_prefix=args.download_url_prefix,
    )
    if args.json:
        print(json.dumps({"checks": [check.to_json() for check in checks]}, indent=2))
    else:
        print_text(checks)

    if any(check.status == "fail" for check in checks):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
