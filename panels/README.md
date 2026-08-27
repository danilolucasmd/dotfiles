# Quickshell panel launchers

Desktop entries that put every quickshell panel in the walker launcher, so a
panel can be reached by name as well as by its keybind.

`qs-night-light.desktop` and `qs-keep-awake.desktop` are the odd ones out and
are named without the `panel` infix on purpose: they open nothing. Both are
settings rather than cards. For the night light the launcher is not a second way
in but the *only* way in — the bar glyph it turns on can only turn it off again.
Keep awake can be toggled either way from its mug, but it has no keybind, so the
launcher is the only thing here that reaches it without the bar.

Each one is a one-line `Exec=qs ipc call <target> <function>` — exactly what the
matching `bindd` in `hyprland.conf` runs. There is no second copy of the panel
here and nothing to keep in sync beyond the command itself; `qs ipc` finds the
running instance on its own, so an entry works whether the panel was last opened
from the bar, from a keybind or from here.

`toggle` rather than an `open` of its own is deliberate and turns out to be
correct from a launcher: walker takes the keyboard when it opens, which clears
the `HyprlandFocusGrab` any open panel is holding, so the panel is already
closed by the time the entry runs. A toggle from here therefore always opens.

Icons are Adwaita symbolic names, because Adwaita is the GTK icon theme and
walker is GTK4. Adwaita ships almost nothing but symbolic icons now — the
full-colour `weather-clear`, `battery`, `audio-speakers` and friends are all
gone — so the `-symbolic` suffix is required, not a style choice.

`StartupNotify=false` matters: a panel is a layer-shell surface and never
answers a startup notification, so leaving it on would hang a launch cursor for
the full timeout every time.

## Adding one

Add the `IpcHandler` in `shell.qml`, then drop a `qs-panel-<slug>.desktop` in
here next to the others and `stow --no-folding panels` again. The `--no-folding`
is what keeps `~/.local/share/applications` a real directory: it is shared with
the Brave web-app launchers that `webapps/generate.sh` writes, and folding it
into a single symlink would send those into this repo.
