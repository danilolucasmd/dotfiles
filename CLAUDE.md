# dotfiles

Arch + Hyprland, reproduced on a new machine by `git clone` + `./install.sh`.
Each top-level directory is a GNU stow package whose inner path mirrors `$HOME`
(`quickshell/.config/quickshell` -> `~/.config/quickshell`). Not every directory
is a package: `webapps/` is a generator run from `install.sh` and `snapshots/`
is a set of curated `/etc` files it installs, and a package may carry a
`README.md` of its own, which stow's default ignore list keeps out of `$HOME`.

`README.md` is the long-form documentation, kept current and written as prose.
When a change alters something it describes, update it in the same turn.

Not everything the system needs is a file. Desktop preferences live in dconf, a
binary database that cannot be symlinked, so `nautilus/dconf.ini` keeps them as
a curated keyfile that `install.sh` applies with `dconf load /` -- a merge, not
a replace. Anything else that turns out to be dconf-shaped belongs there too.

`snapshots/` is the same idea for a different reason: snapper rewrites its own
config file whenever anything calls `set-config`, so symlinking it into the repo
would have snapper writing into git. Those files are copied, not linked, and the
machine-specific values in them -- filesystem UUID, root subvolume, the
installing user -- are derived by `install.sh` at run time rather than committed.

## Editing here edits the running system

The live config is a symlink into this repo, so there is no deploy step and no
copy to keep in sync. Two consequences worth holding onto:

- Most packages are folded -- `~/.config/quickshell` and `~/.config/hypr` are
  single symlinks to the directory here -- so a **new**
  file appears live the moment it is written. The exceptions are the packages
  stowed `--no-folding` (`panels`, `dbus`, `claude`, `herdr`, `kanata`,
  `nautilus`), where each file is linked individually and a new one needs
  `stow --no-folding <pkg>` before the system can see it.
- **Never run `./install.sh` to test a change.** It is a full system install:
  sudo, pacman, AUR builds, systemd units, `usermod`. Run the single command the
  change is about instead.

## Verifying a change without restarting the session

- **quickshell** hot-reloads on save. `qs log` shows the QML errors (and prints
  `Reloading configuration... / Configuration Loaded` on a good reload);
  `qs ipc show` lists every live IPC target and function; `qs list` / `qs kill`
  if it wedges. Nothing here needs the shell restarted by hand.
- **Hyprland** autoreloads `hyprland.conf`; `hyprctl reload` forces it.
  `hyprctl binds -j` is the live bind table, `hyprctl layers` shows whether a
  panel is actually mapped, `hyprctl monitors -j` the display state.
- **the launcher** is a quickshell panel, so it hot-reloads with the rest of the
  shell and picks up a new desktop entry with nothing to restart.
  `qs ipc call launcher toggle` opens it, and `grim` on the result is the honest
  way to check an entry is found and how it will read -- there is no query
  command to ask instead. `clipboard.sh list` and `keybinds.py` both print the
  JSON their panels draw, which is where to look when a list is wrong.
- **kanata** needs `systemctl --user restart kanata` after a keymap edit.

## Before a destructive system change, take a snapshot

Run `snapshot "<what is about to happen>"` first. Never skip it.

It is one command, it needs no sudo, and it takes about a second: `install.sh`
sets `ALLOW_USERS` and `SYNC_ACL` in the snapper configs precisely so that this
rule is too cheap to argue with. The description is mandatory because it becomes
the label in the Limine boot menu, and a menu of bare timestamps is unreadable
at exactly the hour you need to read it.

Destructive means anything that writes outside this repo and outside `$HOME`:
`/etc` and `/usr` edits, DKMS rebuilds, bootloader or mkinitcpio work, `usermod`,
enabling or masking units -- and `./install.sh` itself, which is all of those at
once.

Two things that look like they need it and do not:

- **`pkg`, `yay` and `pacman` snapshot themselves.** snap-pac's alpm hooks fire a
  pre/post pair around every transaction whoever started it, so a `snapshot`
  beforehand only adds a third, worse-described entry to the boot menu.
- **Editing files in this repo.** That is what git is for.

**`snapshot restore` is not yours to run.** The rule authorises creating restore
points, not replacing the running system with one; the command enforces this by
refusing without a terminal, but the prohibition is the point, not the check.
Tell the user which snapshot to roll back to and let them do it.

## A change is not done until it is portable

Anything a fresh Arch install would need belongs in this repo: the config in a
stow package, and the package / systemd unit / step in `install.sh`. Never leave
it as state that only exists on the running machine. Per-machine and ephemeral
things -- credentials, caches, runtime state, tool-managed files -- stay out. If
a change is deliberately machine-local, say so rather than staying silent.

`install.sh` is re-runnable, and wraps every step that may fail without
deserving to take the install down in `try "<name>" <cmd>`.

## Adding a quickshell panel

A panel is the click-open card the bar modules raise, and it is spread across
more files than it looks. All of these, or it is only half-added:

1. `quickshell/.config/quickshell/<Name>State.qml` -- a `Singleton` holding the
   data and `panelOpen`, with `toggle()` and `close()`. The panel is a window of
   its own, so this cannot live in the bar module.
2. `quickshell/.config/quickshell/modules/<Name>Panel.qml` -- built on
   `components/Panel.qml`, which brings the card, the focus grab and Escape.
3. `quickshell/.config/quickshell/modules/<Name>.qml` -- the bar module, if it
   gets one, added to `bar/Bar.qml`.
4. `quickshell/.config/quickshell/shell.qml` -- instantiate the panel, and add
   an `IpcHandler` so `qs ipc call <target> toggle` reaches it.
5. `hypr/.config/hypr/hyprland.conf` -- a `bindd` running that IPC call.
6. `panels/.local/share/applications/qs-panel-<slug>.desktop` -- the same IPC
   call as an `Exec`, which is what puts the panel in the launcher under its own
   name. See `panels/README.md`.

Scripts a panel needs go in `quickshell/.config/quickshell/scripts/`, reached
through `Paths.scripts`, and print one line of JSON for a `JsonScript`.

## Keybinds are always `bindd`, never `bind`

`super+shift+slash` lists every keybind on the system, and `keybinds-menu.py`
builds that list from `hyprctl binds -j` at open time rather than by parsing the
config. A plain `bind` still lists, but falls back to showing its raw
`dispatcher arg` -- readable to nobody, and the sheet doubles as a command
palette, so the description is what makes the bind findable.

## Style

Comments here carry the *why*, at length, and are the reason this repo can be
picked up months later -- what a hardcoded coordinate is working around, why a
panel toggles rather than opens, which of two plausible approaches was measured
and rejected. Match that density rather than the terse norm; a change that
removes a constraint should remove the comment that explained it. QML is
tab-indented.

## Git

Never run git operations unless explicitly asked -- see the global CLAUDE.md.
Commits are conventional and lowercase: `feat:`, `fix:`, occasionally `arch:`.
