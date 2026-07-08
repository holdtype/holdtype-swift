#!/usr/bin/env python3
"""Verify local release or preview manifest metadata and artifact checksums."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


APP_NAME = "HoldType"
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$")
BUILD_PATTERN = re.compile(r"^[0-9]+$")
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


def parse_expected_bool(value: str) -> bool | None:
    if value == "":
        return None
    if value == "true":
        return True
    if value == "false":
        return False
    raise argparse.ArgumentTypeError("expected true or false")


def sha256_for_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_manifest(path: Path) -> tuple[dict[str, Any] | None, list[Check]]:
    if not path.exists():
        return None, [fail_check("manifest:file", f"missing {path}")]
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        return None, [fail_check("manifest:json", f"invalid JSON: {error}")]
    if not isinstance(data, dict):
        return None, [fail_check("manifest:json", "expected JSON object")]
    return data, [pass_check("manifest:file", str(path))]


def resolve_artifact_path(raw_path: str, artifact_root: Path) -> Path:
    path = Path(raw_path)
    candidates = []
    if path.is_absolute():
        candidates.append(path)
    else:
        candidates.extend(
            [
                artifact_root / path,
                artifact_root / path.name,
                Path.cwd() / path,
            ]
        )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0] if candidates else artifact_root / raw_path


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def check_string_field(data: dict[str, Any], key: str, expected: str | None = None) -> list[Check]:
    value = data.get(key)
    if not isinstance(value, str) or not value:
        return [fail_check(f"manifest:{key}", f"missing string value: {value!r}")]
    if expected is not None and value != expected:
        return [fail_check(f"manifest:{key}", f"expected {expected!r}, got {value!r}")]
    return [pass_check(f"manifest:{key}", value)]


def check_bool_field(data: dict[str, Any], key: str, expected: bool | None) -> list[Check]:
    if expected is None:
        return []
    value = data.get(key)
    if value is expected:
        return [pass_check(f"manifest:{key}", str(value).lower())]
    return [fail_check(f"manifest:{key}", f"expected {expected}, got {value!r}")]


def check_version_and_build(data: dict[str, Any]) -> tuple[str, list[Check]]:
    checks: list[Check] = []
    version = data.get("version")
    if isinstance(version, str) and VERSION_PATTERN.fullmatch(version):
        checks.append(pass_check("manifest:version", version))
    else:
        checks.append(
            fail_check(
                "manifest:version",
                f"expected numeric version without leading v, got {version!r}",
            )
        )
        version = version if isinstance(version, str) else ""

    build = data.get("build")
    if isinstance(build, str) and BUILD_PATTERN.fullmatch(build) and int(build) > 0:
        checks.append(pass_check("manifest:build", build))
    else:
        checks.append(fail_check("manifest:build", f"expected positive integer string, got {build!r}"))

    tag = data.get("tag")
    normalized_version = version[1:] if version.startswith("v") else version
    expected_tag = f"v{normalized_version}" if normalized_version else ""
    if isinstance(tag, str) and tag == expected_tag:
        checks.append(pass_check("manifest:tag", tag))
    else:
        checks.append(fail_check("manifest:tag", f"expected {expected_tag!r}, got {tag!r}"))
    return version, checks


def check_artifact(
    *,
    data: dict[str, Any],
    key: str,
    version: str,
    extension: str,
    artifact_root: Path,
    require_under_root: bool,
    require_relative_path: bool,
) -> list[Check]:
    value = data.get(key)
    if not isinstance(value, dict):
        return [fail_check(f"manifest:{key}", f"expected object, got {value!r}")]

    checks: list[Check] = []
    raw_path = value.get("path")
    if not isinstance(raw_path, str) or not raw_path:
        return [fail_check(f"manifest:{key}.path", f"missing string path: {raw_path!r}")]

    raw_artifact_path = Path(raw_path)
    if require_relative_path:
        if raw_artifact_path.is_absolute():
            checks.append(
                fail_check(
                    f"manifest:{key}.path",
                    "must be relative for portable release metadata",
                )
            )
        elif raw_artifact_path.name != raw_path:
            checks.append(
                fail_check(
                    f"manifest:{key}.path",
                    "must be an artifact filename without directory components",
                )
            )
        else:
            checks.append(pass_check(f"manifest:{key}.path", raw_path))

    artifact_path = resolve_artifact_path(raw_path, artifact_root)
    expected_name = f"{APP_NAME}-{version}.{extension}"
    if artifact_path.name == expected_name:
        checks.append(pass_check(f"manifest:{key}.name", expected_name))
    else:
        checks.append(
            fail_check(f"manifest:{key}.name", f"expected {expected_name}, got {artifact_path.name}")
        )

    if require_under_root:
        if is_relative_to(artifact_path, artifact_root):
            checks.append(pass_check(f"manifest:{key}.root", str(artifact_root)))
        else:
            checks.append(
                fail_check(
                    f"manifest:{key}.root",
                    f"{artifact_path} is outside artifact root {artifact_root}",
                )
            )

    if artifact_path.exists():
        checks.append(pass_check(f"manifest:{key}.file", str(artifact_path)))
    else:
        checks.append(fail_check(f"manifest:{key}.file", f"missing {artifact_path}"))
        return checks

    expected_sha = value.get("sha256")
    if not isinstance(expected_sha, str) or not SHA256_PATTERN.fullmatch(expected_sha.lower()):
        checks.append(fail_check(f"manifest:{key}.sha256", f"invalid sha256: {expected_sha!r}"))
        return checks

    actual_sha = sha256_for_file(artifact_path)
    if actual_sha == expected_sha.lower():
        checks.append(pass_check(f"manifest:{key}.sha256", actual_sha))
    else:
        checks.append(
            fail_check(
                f"manifest:{key}.sha256",
                f"expected {expected_sha.lower()}, got {actual_sha}",
            )
        )
    return checks


def collect_checks(
    *,
    manifest_path: Path,
    artifact_root: Path,
    expected_kind: str,
    expected_public_release: bool | None,
    expected_notarized: bool | None,
    require_artifacts_under_root: bool,
    require_relative_artifact_paths: bool,
) -> list[Check]:
    data, checks = load_manifest(manifest_path)
    if data is None:
        return checks

    checks.extend(check_string_field(data, "app", APP_NAME))
    if expected_kind:
        checks.extend(check_string_field(data, "kind", expected_kind))
    checks.extend(check_bool_field(data, "public_release", expected_public_release))
    checks.extend(check_bool_field(data, "notarized", expected_notarized))

    version, version_checks = check_version_and_build(data)
    checks.extend(version_checks)
    if version:
        checks.extend(
            check_artifact(
                data=data,
                key="dmg",
                version=version,
                extension="dmg",
                artifact_root=artifact_root,
                require_under_root=require_artifacts_under_root,
                require_relative_path=require_relative_artifact_paths,
            )
        )
        checks.extend(
            check_artifact(
                data=data,
                key="zip",
                version=version,
                extension="zip",
                artifact_root=artifact_root,
                require_under_root=require_artifacts_under_root,
                require_relative_path=require_relative_artifact_paths,
            )
        )
    return checks


def print_text(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--artifact-root", default="")
    parser.add_argument("--expect-kind", default="")
    parser.add_argument("--expect-public-release", type=parse_expected_bool, default=None)
    parser.add_argument("--expect-notarized", type=parse_expected_bool, default=None)
    parser.add_argument("--allow-artifacts-outside-root", action="store_true")
    parser.add_argument("--require-relative-artifact-paths", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    artifact_root = Path(args.artifact_root).resolve() if args.artifact_root else manifest_path.parent.resolve()
    checks = collect_checks(
        manifest_path=manifest_path,
        artifact_root=artifact_root,
        expected_kind=args.expect_kind,
        expected_public_release=args.expect_public_release,
        expected_notarized=args.expect_notarized,
        require_artifacts_under_root=not args.allow_artifacts_outside_root,
        require_relative_artifact_paths=args.require_relative_artifact_paths,
    )

    if args.json:
        print(json.dumps({"checks": [check.to_json() for check in checks]}, indent=2))
    else:
        print_text(checks)

    return 1 if any(check.status == "fail" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
