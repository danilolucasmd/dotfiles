#!/usr/bin/env python3
"""Drive the script-driven Waybar workspace buttons, fast.

Runs as a hidden Waybar custom module (lifecycle tied to the bar). It listens to
Hyprland's event socket and, on a relevant change, computes every workspace's
state ONCE (two hyprctl calls total, not two per button), writes a ready-to-emit
JSON file per workspace, then signals Waybar (SIGRTMIN+1) so each custom/wsN
button simply cats its file. Rapid bursts (fast workspace switching) are
coalesced so refreshes can't pile up and lag behind.

A flock keeps it a singleton in case Waybar ever spawns a second copy.
"""
import fcntl
import json
import os
import select
import socket
import subprocess
import sys
import time

SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
if not SIG:
    sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set")

SOCK2 = f"{RUNTIME}/hypr/{SIG}/.socket2.sock"
WORKSPACES = range(1, 6)   # the persistent set 1..5
COOLDOWN = 0.03            # min seconds between refreshes (coalesce bursts)

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


def _hypr(cmd):
    out = subprocess.run(["hyprctl", "-j", cmd], capture_output=True, text=True)
    return json.loads(out.stdout)


def compute_and_write():
    """One query for all workspaces; write each button's ready JSON."""
    try:
        workspaces = _hypr("workspaces")
        active = _hypr("activeworkspace").get("id", -1)
    except Exception:
        return
    by_id = {w.get("id"): w for w in workspaces}
    for n in WORKSPACES:
        w = by_id.get(n)
        classes = []
        if n == active:
            classes.append("active")
        if w and w.get("hasfullscreen"):
            classes.append("fullscreen")
        if not w or w.get("windows", 0) == 0:
            classes.append("empty")
        path = f"{RUNTIME}/waybar-ws-{n}.json"
        tmp = f"{path}.tmp"
        with open(tmp, "w") as f:
            f.write(json.dumps({"text": str(n), "class": classes}))
        os.replace(tmp, path)  # atomic


def refresh():
    compute_and_write()
    subprocess.run(["pkill", "-RTMIN+1", "waybar"])


def main():
    lock = open(f"{RUNTIME}/waybar-ws-events.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)

    refresh()  # publish initial state

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK2)
    s.setblocking(False)

    buf = ""
    pending = False   # a change is waiting to be flushed after the cooldown
    last = 0.0        # monotonic time of the last refresh
    while True:
        timeout = None
        if pending:
            timeout = max(0.0, (last + COOLDOWN) - time.monotonic())
        ready, _, _ = select.select([s], [], [], timeout)

        if not ready:
            # Cooldown elapsed with a change queued -> trailing refresh.
            if pending:
                refresh()
                last = time.monotonic()
                pending = False
            continue

        try:
            data = s.recv(65536)
        except BlockingIOError:
            continue
        if not data:
            return  # socket closed; Waybar restarts us

        buf += data.decode("utf-8", "replace")
        lines = buf.split("\n")
        buf = lines[-1]
        hit = any(line.split(">>", 1)[0] in TRIGGERS for line in lines[:-1])
        if not hit:
            continue

        now = time.monotonic()
        if now - last >= COOLDOWN:
            refresh()          # leading edge: first change is immediate
            last = now
            pending = False
        else:
            pending = True     # within cooldown: collapse into a trailing flush


if __name__ == "__main__":
    main()
