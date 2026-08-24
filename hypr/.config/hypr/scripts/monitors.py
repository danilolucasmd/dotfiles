#!/usr/bin/env python3
"""Keep the external monitor the main screen, with the laptop panel mirroring it.

  * External connected -> it is the whole desktop, at 0x0 and its highest
                          refresh rate. The laptop panel mirrors it.
  * No external        -> the laptop panel is the desktop again, at the 1.5
                          scale that makes 1920x1080 readable on a 14".

Hyprland's monitor rules are static, so the mirror cannot live in
hyprland.conf: the rule has to name the source monitor, and a rule pointing at
a monitor that is not plugged in leaves the panel mirroring nothing. This
daemon listens on socket2 and re-applies the whole layout on every hotplug
instead. Applying is idempotent -- both monitors are always set explicitly --
so a spurious event costs nothing.
"""
import json
import os
import socket
import subprocess
import sys

LAPTOP = "eDP-1"
# 1920x1080 on a 310x170mm panel: unscaled text is too small to read.
LAPTOP_SOLO_SCALE = "1.5"
# Mirroring copies the source's framebuffer, so the panel has to run unscaled
# for the image to land 1:1 instead of being resampled.
LAPTOP_MIRROR_SCALE = "1"


def hyprctl(*args) -> str:
    try:
        return subprocess.run(
            ["hyprctl", *args], capture_output=True, text=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"hyprctl {' '.join(args)} failed: {e}", file=sys.stderr)
        return ""


def external() -> str:
    """Name of the external to treat as the main screen, "" if there is none."""
    try:
        # `all` so that a monitor a previous rule disabled is still considered.
        monitors = json.loads(hyprctl("monitors", "all", "-j"))
    except json.JSONDecodeError:
        return ""
    # Any non-internal output. Sorted so that two externals pick the same one
    # every time rather than following whatever order the kernel probed in.
    names = sorted(m.get("name", "") for m in monitors if m.get("name") != LAPTOP)
    return next((n for n in names if n), "")


def apply() -> None:
    ext = external()
    if ext:
        # Both rules in one --batch request, so they land in the same event
        # loop iteration. Sent as two requests, the first one moves the
        # external onto 0x0 while the panel is still a real monitor sitting
        # there, and Hyprland's layout check -- which runs once at the end of
        # every iteration -- catches that intermediate state and pops the
        # "monitor layout is set up incorrectly" warning about eDP-1, even
        # though the mirror a moment later makes the overlap moot.
        hyprctl(
            "--batch",
            f"keyword monitor {ext},highrr,0x0,1;"
            f"keyword monitor {LAPTOP},preferred,0x0,{LAPTOP_MIRROR_SCALE},mirror,{ext}",
        )
    else:
        hyprctl("keyword", "monitor", f"{LAPTOP},preferred,0x0,{LAPTOP_SOLO_SCALE}")


def main() -> int:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not sig or not runtime:
        print("not in a Hyprland session", file=sys.stderr)
        return 1

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(os.path.join(runtime, "hypr", sig, ".socket2.sock"))

    # The session may already have started with an external attached.
    apply()

    with s.makefile("r") as f:
        for line in f:
            event, _, _payload = line.rstrip("\n").partition(">>")
            # monitoraddedv2/monitorremovedv2 carry the same events with richer
            # payloads; matching the short names would double every hotplug.
            #
            # configreloaded matters as much as the hotplugs: `hyprctl reload`
            # re-applies hyprland.conf, which only knows the baseline rules, so
            # any reload silently drops the mirror and puts the external back to
            # its default refresh rate until we set it again.
            if event in ("monitoradded", "monitorremoved", "configreloaded"):
                apply()

    return 0


if __name__ == "__main__":
    sys.exit(main())
