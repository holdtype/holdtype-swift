#!/usr/bin/env python3
"""Run a command with a hard timeout.

macOS does not provide GNU timeout by default. Release automation uses this
wrapper for Xcode, notarization, disk image, and verification commands so
external operations never wait forever.
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time


def terminate(process: subprocess.Popen[bytes]) -> None:
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGTERM)
            return
        except ProcessLookupError:
            return
    process.terminate()


def kill(process: subprocess.Popen[bytes]) -> None:
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGKILL)
            return
        except ProcessLookupError:
            return
    process.kill()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a command with a timeout.")
    parser.add_argument("timeout_seconds", type=float)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("missing command")

    started_at = time.monotonic()
    process = subprocess.Popen(command, start_new_session=(os.name == "posix"))
    try:
        return process.wait(timeout=args.timeout_seconds)
    except subprocess.TimeoutExpired:
        elapsed = time.monotonic() - started_at
        print(
            f"timed out after {elapsed:.1f}s: {' '.join(command)}",
            file=sys.stderr,
        )
        terminate(process)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            kill(process)
            process.wait()
        return 124


if __name__ == "__main__":
    raise SystemExit(main())
