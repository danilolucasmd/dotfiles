#!/usr/bin/env python3
"""Refresh the script-driven Waybar workspace buttons on Hyprland changes.

Runs as a hidden Waybar custom module (its lifecycle is tied to the bar). It
listens to Hyprland's event socket and, on any event that can change what a
workspace button should show (focus, fullscreen, window add/remove/move,
workspace create/destroy), sends SIGRTMIN+1 to Waybar. Every custom/wsN button
is configured with "signal": 1, so they all re-run their state script at once.

A flock keeps it a singleton in case Waybar ever spawns a second copy.
"""
import fcntl
import os
import socket
import subprocess
import sys

SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
if not SIG:
    sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set")

SOCK2 = f"{RUNTIME}/hypr/{SIG}/.socket2.sock"

# Events after which a workspace button may need to change.
TRIGGERS = {
    "workspace", "workspacev2",
    "focusedmon", "focusedmonv2",
    "fullscreen",
    "openwindow", "closewindow",
    "movewindow", "movewindowv2",
    "createworkspace", "createworkspacev2",
    "destroyworkspace", "destroyworkspacev2",
    "moveworkspace", "moveworkspacev2",
    "activespecial", "activespecialv2",
    "renameworkspace",
}


def refresh():
    subprocess.run(["pkill", "-RTMIN+1", "waybar"])


def main():
    lock = open(f"{RUNTIME}/waybar-ws-events.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK2)
    with s.makefile("r", encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if line.split(">>", 1)[0] in TRIGGERS:
                refresh()


if __name__ == "__main__":
    main()
