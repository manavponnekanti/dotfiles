#!/usr/bin/python3
"""Flowmodoro state machine and Alfred Script Filter."""

from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from contextlib import contextmanager
from pathlib import Path


BUNDLE_ID = "com.mbp.alfred.flowmodoro"
CALENDAR_NAME = os.environ.get("FLOWMODORO_CALENDAR", "Studying")
BREAK_SHORTCUT_NAME = "Flowmodoro Break"
MIN_SESSION_SECONDS = 10 * 60


def data_dir() -> Path:
    override = os.environ.get("FLOWMODORO_DATA_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library/Application Support/Alfred/Workflow Data" / BUNDLE_ID


def state_path() -> Path:
    return data_dir() / "state.json"


def idle_state() -> dict:
    return {"phase": "idle", "accumulated_seconds": 0}


@contextmanager
def locked_state():
    directory = data_dir()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "state.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def load_state() -> dict:
    try:
        state = json.loads(state_path().read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return idle_state()

    phase = state.get("phase")
    if phase == "running" and isinstance(state.get("started_at"), (int, float)):
        state["accumulated_seconds"] = max(0, float(state.get("accumulated_seconds", 0)))
        return state
    if phase == "paused":
        state["accumulated_seconds"] = max(0, float(state.get("accumulated_seconds", 0)))
        return state
    return idle_state()


def save_state(state: dict) -> None:
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(state, separators=(",", ":")) + "\n")
    temporary.replace(path)


def elapsed_seconds(state: dict, timestamp: float | None = None) -> float:
    timestamp = timestamp if timestamp is not None else time.time()
    elapsed = max(0, float(state.get("accumulated_seconds", 0)))
    if state.get("phase") == "running":
        elapsed += max(0, timestamp - float(state["started_at"]))
    return elapsed


def format_duration(seconds: float) -> str:
    total = max(0, int(seconds + 0.5))
    return f"{total // 60}:{total % 60:02d}"


def finish_focus_block(elapsed: float, ended_at: float, break_seconds: int) -> None:
    if os.environ.get("FLOWMODORO_TEST"):
        return
    started_at = ended_at - elapsed
    started_text = datetime.fromtimestamp(started_at).astimezone().isoformat(timespec="seconds")
    ended_text = datetime.fromtimestamp(ended_at).astimezone().isoformat(timespec="seconds")
    payload = f"{break_seconds}\n{started_text}\n{ended_text}\n{CALENDAR_NAME}\n"
    result = run_shortcut(BREAK_SHORTCUT_NAME, payload, timeout=15)
    if result.returncode != 0:
        detail = result.stderr.strip() or "unknown Shortcuts error"
        raise RuntimeError(f"could not start {BREAK_SHORTCUT_NAME}: {detail}")


def run_shortcut(name: str, payload: str, timeout: int) -> subprocess.CompletedProcess[str]:
    """Run a Shortcut with a documented file-backed Shortcut Input value."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".txt") as input_file:
        input_file.write(payload)
        input_file.flush()
        return subprocess.run(
            [
                "/usr/bin/shortcuts",
                "run",
                name,
                "--input-path",
                input_file.name,
            ],
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )


def command(action: str) -> str:
    action = action.strip().lower()
    timestamp = time.time()
    elapsed = 0.0
    break_minutes = 0

    with locked_state():
        state = load_state()

        if action == "start":
            if state["phase"] == "running":
                return f"Already running · {format_duration(elapsed_seconds(state, timestamp))}"
            accumulated = state.get("accumulated_seconds", 0) if state["phase"] == "paused" else 0
            save_state({
                "phase": "running",
                "accumulated_seconds": accumulated,
                "started_at": timestamp,
            })
            return "Flowmodoro resumed" if accumulated else "Flowmodoro started"

        if action == "pause":
            if state["phase"] != "running":
                return "Already paused" if state["phase"] == "paused" else "Flowmodoro is not running"
            elapsed = elapsed_seconds(state, timestamp)
            save_state({"phase": "paused", "accumulated_seconds": elapsed})
            return f"Flowmodoro paused · {format_duration(elapsed)}"

        if action == "break":
            if state["phase"] not in ("running", "paused"):
                return "No focused time to convert"
            elapsed = elapsed_seconds(state, timestamp)
            save_state(idle_state())
            if elapsed < MIN_SESSION_SECONDS:
                return (
                    f"Session discarded · {format_duration(elapsed)} · "
                    f"minimum {format_duration(MIN_SESSION_SECONDS)}"
                )
            break_minutes = int((elapsed / 300) + 0.5)
        elif action == "reset":
            save_state(idle_state())
            return "Flowmodoro reset"
        else:
            raise ValueError("Use start, pause, break, or reset")

    finish_focus_block(elapsed, timestamp, break_minutes * 60)
    if break_minutes < 1:
        return f"Stopped · {format_duration(elapsed)} · no break earned"
    return f"Stopped · {format_duration(elapsed)} · {break_minutes} min break"


def script_filter(query: str) -> int:
    state = load_state()
    query = query.strip().lower()
    descriptions = {
        "start": "Start a new focus block or resume the paused one",
        "pause": "Pause the current focus stopwatch",
        "break": "Stop work and take 1 minute per 5 focused minutes",
        "reset": "Discard the current focus block",
    }
    actions = [name for name in descriptions if not query or name.startswith(query)]
    if not actions:
        actions = list(descriptions)
    items = []
    if not query and state["phase"] in ("running", "paused"):
        phase = state["phase"].upper()
        items.append({
            "title": f"Elapsed · {format_duration(elapsed_seconds(state))}",
            "subtitle": f"{phase} · Flowmodoro session in progress",
            "valid": False,
        })
    for action in actions:
        items.append({
            "title": f"fl {action}",
            "subtitle": descriptions[action],
            "arg": action,
            "autocomplete": action,
            "valid": True,
        })
    result = {"items": items}
    if state["phase"] == "running":
        result["rerun"] = 1
    print(json.dumps(result, separators=(",", ":")))
    return 0


def main(argv: list[str]) -> int:
    mode = argv[1] if len(argv) > 1 else "filter"
    try:
        if mode == "filter":
            return script_filter(argv[2] if len(argv) > 2 else "")
        if mode == "run":
            message = command(argv[2] if len(argv) > 2 else "")
            print(message)
            return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
        message = f"Flowmodoro error: {error}"
        print(message)
        return 1
    print("Usage: flowmodoro.py filter [query] | run ACTION", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
