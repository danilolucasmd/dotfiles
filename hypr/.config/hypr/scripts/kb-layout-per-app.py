#!/usr/bin/env python3
"""Remember the keyboard layout per application, Hyprland-wide.

Hyprland has no per-window xkb layout: alt+space flips one global group. This
daemon listens on socket2 and gives every window class its own memory instead.

  * Focus a class we have seen before -> its remembered layout is restored.
  * Toggle with alt+space            -> the new layout is stored for the class
                                        that is focused, and for that one only.
  * Focus a class we have not seen   -> it inherits the current layout, which
                                        then becomes its memory.

The map is written to disk on every change, so it survives logout and reboot.
"""
import json
import os
import socket
import subprocess
import sys
import tempfile

STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "hypr",
    "kb-layout-per-app.json",
)
# Keep the file from growing forever on throwaway dialogs; oldest entry first.
MAX_ENTRIES = 100


def load() -> dict:
    try:
        with open(STATE) as f:
            data = json.load(f)
        return {k: int(v) for k, v in data.items() if isinstance(k, str)}
    except (OSError, ValueError, AttributeError):
        return {}


def save(layouts: dict) -> None:
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    try:
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(STATE), suffix=".tmp")
        with os.fdopen(fd, "w") as f:
            json.dump(layouts, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp, STATE)  # atomic: never leave a half-written map behind
    except OSError as e:
        print(f"cannot save {STATE}: {e}", file=sys.stderr)


def hyprctl(*args) -> str:
    try:
        return subprocess.run(
            ["hyprctl", *args], capture_output=True, text=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return ""


def active_index() -> int:
    """Layout index of the main keyboard."""
    try:
        kbs = json.loads(hyprctl("devices", "-j")).get("keyboards", [])
    except json.JSONDecodeError:
        return 0
    main = next((k for k in kbs if k.get("main")), kbs[0] if kbs else {})
    return int(main.get("active_layout_index", 0))


def active_class() -> str:
    try:
        return json.loads(hyprctl("activewindow", "-j")).get("class", "") or ""
    except json.JSONDecodeError:
        return ""


def main() -> int:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not sig or not runtime:
        print("not in a Hyprland session", file=sys.stderr)
        return 1

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(os.path.join(runtime, "hypr", sig, ".socket2.sock"))

    layouts = load()
    current = active_index()
    focused = active_class()

    def apply(index: int) -> None:
        nonlocal current
        if index != current:
            hyprctl("switchxkblayout", "all", str(index))
            current = index

    def remember(cls: str, index: int) -> None:
        # No-op when nothing changed, so focus churn does not hit the disk.
        if not cls or layouts.get(cls) == index:
            return
        layouts[cls] = index
        while len(layouts) > MAX_ENTRIES:
            layouts.pop(next(iter(layouts)))
        save(layouts)

    def focus(cls: str) -> None:
        nonlocal focused
        focused = cls
        if not cls:  # a layer surface (walker, lock screen); leave the layout be
            return
        if cls in layouts:
            apply(layouts[cls])
        else:
            remember(cls, current)

    focus(focused)

    with s.makefile("r") as f:
        for line in f:
            event, _, payload = line.rstrip("\n").partition(">>")

            if event == "activewindow":
                # payload: CLASS,TITLE  (empty class when nothing is focused)
                focus(payload.split(",", 1)[0])

            elif event == "activelayout":
                # payload: KEYBOARDNAME,LAYOUTNAME. Every device reports, plus
                # fcitx5's virtual keyboard, which tracks a layout of its own.
                if payload.partition(",")[0].startswith("hl-virtual-keyboard"):
                    continue
                current = active_index()
                # Echo of our own switch, or a real alt+space: either way the
                # focused class now wants this layout.
                remember(focused, current)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, BrokenPipeError, ConnectionError):
        pass
