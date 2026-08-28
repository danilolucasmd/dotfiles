# Quickshell panel launchers

Desktop entries that put every quickshell panel in the launcher, so a panel can
be reached by name as well as by its keybind. The launcher indexes
`~/.local/share/applications` through Quickshell's `DesktopEntries`, which is
the same set of files any launcher would read -- these were written for walker
and needed nothing done to them when it went.

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
correct from a launcher: the launcher holds a `HyprlandFocusGrab` of its own
while it is up, which clears the one any open panel was holding, so the panel is
already closed by the time the entry runs. A toggle from here therefore always
opens.

There is no entry for the launcher itself. It would list, and picking it would
close the launcher and reopen it, which is a no-op with extra steps.

Icons are symbolic names. The `-symbolic` suffix is required, not a style
choice: the themes in play ship almost nothing but symbolic icons now, and the
full-colour `weather-clear`, `battery`, `audio-speakers` and friends are all
gone. The launcher resolves them with `Quickshell.iconPath(name, true)`, and the
`true` is what makes a name the theme does not have come back empty rather than
as a broken-image path: a row with no icon draws a blank slot, which is quieter
than a placeholder.

The theme a name is resolved *against* is breeze-dark, not Adwaita —
`env = QS_ICON_THEME,breeze-dark` in `hyprland.conf` sets it for the tray, and
the launcher is the same process. That is why several entries here draw a blank
slot: `bluetooth-symbolic`, `x-office-calendar-symbolic` and
`night-light-symbolic` are Adwaita names breeze-dark does not carry. A new entry
that wants an icon which actually appears should be checked against
`/usr/share/icons/breeze-dark` first.

Changing the `Icon=` of an entry that already resolved once is the one edit here
that a re-stow and a `qs` reload will not show: the resolved path is cached for
the life of the process, and only `qs kill` and starting it again picks the new
one up. Everything else about an entry — its name, its comment, its `Exec` — is
re-read the moment the file is touched.

`StartupNotify=false` matters: a panel is a layer-shell surface and never
answers a startup notification, so leaving it on would hang a launch cursor for
the full timeout every time.

## Adding one

Add the `IpcHandler` in `shell.qml`, then drop a `qs-panel-<slug>.desktop` in
here next to the others and `stow --no-folding panels` again. Nothing needs
restarting after that -- `DesktopEntries` watches the directory. The `--no-folding`
is what keeps `~/.local/share/applications` a real directory: it is shared with
the Brave web-app launchers that `webapps/generate.sh` writes, and folding it
into a single symlink would send those into this repo.
