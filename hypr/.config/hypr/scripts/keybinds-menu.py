#!/usr/bin/env python3
"""Keybind cheatsheet, in Walker.

Reads the live bind table out of `hyprctl binds -j`, so nothing here is a
second copy of the config that could drift: adding a bind to hyprland.conf is
all it takes for it to show up. Each bind carries its own label because they
are all written as `bindd` — the description is the third field:

    bindd = $mainMod, T, Open terminal, exec, $terminal

A bind without one still lists; it falls back to `dispatcher arg`, which is a
hint to go and give it a description.

Selecting a row runs the bind, so the sheet doubles as a command palette.
Mouse binds have nothing to dispatch and are listed read-only.
"""

import json
import os
import re
import subprocess
import sys

# Hyprland's modmask, which is the wlroots/xkb one. MOD2/MOD3/MOD5 are the
# leftovers nobody binds; they are here so an unexpected bit is still named.
MODS = [
    (64, "SUPER"),
    (4, "CTRL"),
    (8, "ALT"),
    (1, "SHIFT"),
    (2, "CAPS"),
    (16, "MOD2"),
    (32, "MOD3"),
    (128, "MOD5"),
]

# Keys whose Hyprland/xkb name is not what you would read off the keycap.
KEY_NAMES = {
    "SPACE": "Space",
    "RETURN": "Enter",
    "ESCAPE": "Esc",
    "GRAVE": "`",
    "MINUS": "-",
    "EQUAL": "=",
    "BRACKETLEFT": "[",
    "BRACKETRIGHT": "]",
    "BACKSLASH": "\\",
    "SEMICOLON": ";",
    "APOSTROPHE": "'",
    "COMMA": ",",
    "PERIOD": ".",
    "DOT": ".",
    "SLASH": "/",
    "PRIOR": "PgUp",
    "NEXT": "PgDn",
    "BACKSPACE": "Backspace",
    "DELETE": "Del",
}

# Media/laptop keys arrive as their XF86 keysym, which is unreadable in a list.
XF86_NAMES = {
    "AudioRaiseVolume": "Vol+",
    "AudioLowerVolume": "Vol-",
    "AudioMute": "Mute",
    "AudioMicMute": "MicMute",
    "AudioPlay": "Play",
    "AudioPause": "Pause",
    "AudioNext": "Next",
    "AudioPrev": "Prev",
    "AudioStop": "Stop",
    "MonBrightnessUp": "Bright+",
    "MonBrightnessDown": "Bright-",
}

MOUSE_BUTTONS = {"272": "LMB", "273": "RMB", "274": "MMB", "275": "Back", "276": "Forward"}


def keycode_names():
    """evdev keycode -> keycap name, read from the kernel's own header.

    Binds written as `code:59` come back from hyprctl with an empty key and the
    raw code, and a cheatsheet that says "code:59" helps nobody. Hyprland's
    `code:` is the xkb keycode, which is the evdev one plus 8.
    """
    names = {}
    try:
        with open("/usr/include/linux/input-event-codes.h") as fh:
            for line in fh:
                m = re.match(r"#define\s+KEY_(\w+)\s+(\d+)\b", line)
                if m:
                    names.setdefault(int(m.group(2)), m.group(1))
    except OSError:
        pass
    return names


def pretty_key(bind, codes):
    key = bind["key"]

    if bind["mouse"] or key.startswith("mouse:"):
        button = key.split(":", 1)[-1]
        return MOUSE_BUTTONS.get(button, key)

    if not key and bind["keycode"]:
        name = codes.get(bind["keycode"] - 8)
        if not name:
            return "code:%d" % bind["keycode"]
        key = KEY_NAMES.get(name, name.title() if len(name) > 1 else name)
        return key

    if key.startswith("XF86"):
        return XF86_NAMES.get(key[4:], key[4:])

    upper = key.upper()
    if upper in KEY_NAMES:
        return KEY_NAMES[upper]
    if len(key) == 1:
        return upper
    return key


def pretty_mods(modmask):
    return [name for bit, name in MODS if modmask & bit]


def label(bind):
    if bind["description"]:
        return bind["description"]
    arg = bind["arg"].strip()
    return ("%s %s" % (bind["dispatcher"], arg)).strip()


def flags(bind):
    """Only the flags that change how you press the key.

    `repeat` and `locked` are deliberately not here: every volume and
    brightness bind carries both, so annotating them says nothing about that
    bind and costs a line of noise on a third of the sheet.
    """
    out = []
    if bind["release"]:
        out.append("on release")
    if bind["longPress"]:
        out.append("long press")
    return out


def rows(binds, codes):
    """(keys, description, bind) per bind, submaps folded into the keys column."""
    out = []
    for bind in binds:
        keys = pretty_mods(bind["modmask"]) + [pretty_key(bind, codes)]
        text = label(bind)
        extra = flags(bind)
        if bind["submap"]:
            extra.insert(0, "submap %s" % bind["submap"])
        if extra:
            text = "%s  (%s)" % (text, ", ".join(extra))
        out.append((" + ".join(keys), text, bind))
    return out


def dispatch(bind):
    if bind["mouse"]:
        return
    args = ["hyprctl", "dispatch", bind["dispatcher"]]
    if bind["arg"]:
        args.append(bind["arg"])
    subprocess.run(args, stdout=subprocess.DEVNULL)


def main():
    binds = json.loads(subprocess.run(
        ["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True).stdout)
    table = rows(binds, keycode_names())
    if not table:
        return 0

    # The Walker theme sets JetBrainsMono for the whole window, so padding the
    # key column to the widest entry actually lines the descriptions up.
    width = max(len(keys) for keys, _, _ in table)
    menu = "".join("%-*s   %s\n" % (width, keys, text) for keys, text, _ in table)

    # --index hands back the row number rather than its text, so the lookup
    # below is exact and the padding above cannot confuse it.
    walker = subprocess.run(
        ["walker", "--dmenu", "--index", "--placeholder", "Search keybinds"],
        input=menu, capture_output=True, text=True)
    picked = walker.stdout.strip()
    if walker.returncode != 0 or not picked.isdigit():
        return 0

    index = int(picked)
    if 0 <= index < len(table):
        dispatch(table[index][2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
