#!/usr/bin/env python3
"""Keybind cheatsheet, as JSON for the quickshell panel.

Reads the live bind table out of `hyprctl binds -j`, so nothing here is a
second copy of the config that could drift: adding a bind to hyprland.conf is
all it takes for it to show up. Each bind carries its own label because they
are all written as `bindd` -- the description is the third field:

    bindd = $mainMod, T, Open terminal, exec, $terminal

A bind without one still lists; it falls back to `dispatcher arg`, which is a
hint to go and give it a description.

This prints and exits. It used to draw the sheet itself, by padding the key
column to a fixed width and piping the lot into `walker --dmenu --index`; the
panel that replaced walker draws each modifier as a keycap of its own, which is
why `keys` here is a list rather than the "SUPER + T" string it once was.
Dispatching is the panel's job too -- it has to close before it fires, because
the bind it is about to run may well be the one that opens a panel.
"""

import json
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
    """One record per bind: the keycaps to draw, the label, and what to run."""
    out = []
    for bind in binds:
        extra = flags(bind)
        if bind["submap"]:
            extra.insert(0, "submap %s" % bind["submap"])
        out.append({
            "keys": pretty_mods(bind["modmask"]) + [pretty_key(bind, codes)],
            "description": label(bind),
            # Rendered as a parenthetical after the label. Empty for all but a
            # handful, which is the point -- see flags().
            "note": ", ".join(extra),
            # What the panel dispatches. A mouse bind has nothing to run and is
            # listed read-only, which is what the empty dispatcher says.
            "dispatcher": "" if bind["mouse"] else bind["dispatcher"],
            "arg": bind["arg"],
        })
    return out


def main():
    binds = json.loads(subprocess.run(
        ["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True).stdout)
    json.dump({"binds": rows(binds, keycode_names())}, sys.stdout)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
