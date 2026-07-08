#!/usr/bin/env python3
"""Verify release notes shared by GitHub Releases and Sparkle appcasts."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path


APP_NAME = "HoldType"
PLACEHOLDER_PATTERN = re.compile(
    r"\b(TODO|TBD|FIXME|CHANGEME)\b|"
    r"<(?:version|summary|notes?|date|sha256|owner|repo|url)[^>\n]*>",
    re.IGNORECASE,
)


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


def normalize_text(text: str) -> str:
    return text.replace("\r\n", "\n").strip()


def collect_checks(notes_path: Path, version: str) -> list[Check]:
    if not notes_path.exists():
        return [fail_check("release-notes:file", f"missing {notes_path}")]

    text = normalize_text(notes_path.read_text())
    checks: list[Check] = [pass_check("release-notes:file", str(notes_path))]
    if text:
        checks.append(pass_check("release-notes:not-empty", "present"))
    else:
        checks.append(fail_check("release-notes:not-empty", "missing"))
        return checks

    lines = [line.strip() for line in text.splitlines() if line.strip()]
    expected_heading = f"# {APP_NAME} {version}"
    first_line = lines[0] if lines else ""
    if first_line == expected_heading:
        checks.append(pass_check("release-notes:heading", expected_heading))
    else:
        checks.append(
            fail_check("release-notes:heading", f"expected {expected_heading!r}, got {first_line!r}")
        )

    body_lines = lines[1:]
    body = "\n".join(body_lines).strip()
    if body:
        checks.append(pass_check("release-notes:body", "present"))
    else:
        checks.append(fail_check("release-notes:body", "missing"))

    placeholder = PLACEHOLDER_PATTERN.search(text)
    if placeholder is None:
        checks.append(pass_check("release-notes:placeholders", "absent"))
    else:
        checks.append(fail_check("release-notes:placeholders", f"found {placeholder.group(0)!r}"))
    return checks


def print_text(checks: list[Check]) -> None:
    for check in checks:
        print(f"[{check.status}] {check.name}: {check.message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notes-file", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    checks = collect_checks(Path(args.notes_file), args.version)
    failures = [check for check in checks if check.status == "fail"]

    if args.json:
        print(json.dumps({"checks": [check.to_json() for check in checks]}, indent=2))
    elif args.quiet:
        if failures:
            print_text(failures)
    else:
        print_text(checks)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
