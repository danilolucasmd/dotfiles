#!/usr/bin/env python3
"""Waybar module: show the active Hyprland keyboard layout (US vs US intl).

Event-driven: listens on Hyprland's socket2 and emits JSON on every layout
change, so it updates instantly (no polling). Output is one JSON object per
line, consumed by a custom/* module with "return-type": "json".
"""
import json
import os
import socket
import subprocess
import sys


def render(keymap: str) -> str:
    name = (keymap or "").lower()
    if "intl" in name:
        text, cls, tip = "󰌌 BR", "intl", "US International (dead keys)"
    else:
        text, cls, tip = "󰌌 US", "us", "US"
    return json.dumps({"text": text, "class": cls, "tooltip": tip})


def initial_keymap() -> str:
    try:
        out = subprocess.run(
            ["hyprctl", "devices", "-j"], capture_output=True, text=True, check=True
        ).stdout
        kbs = json.loads(out).get("keyboards", [])
        main = next((k for k in kbs if k.get("main")), kbs[0] if kbs else {})
        return main.get("active_keymap", "")
    except Exception:
        return ""


def emit(keymap: str) -> None:
    print(render(keymap), flush=True)


def main() -> int:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not sig or not runtime:
        emit("")  # not in a Hyprland session; show default and exit
        return 0

    emit(initial_keymap())

    sock_path = os.path.join(runtime, "hypr", sig, ".socket2.sock")
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)

    with s.makefile("r") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("activelayout>>"):
                # payload: KEYBOARDNAME,LAYOUTNAME
                emit(line.split(",", 1)[-1])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, BrokenPipeError):
        pass
