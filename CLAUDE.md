# dotfiles

Arch + Hyprland setup, reproduced on a new machine by `git clone` +
`./install.sh`. Each top-level directory is a GNU stow package whose inner path
mirrors `$HOME` (`quickshell/.config/quickshell` -> `~/.config/quickshell`), so
the live config is a symlink into this repo and edits here are edits to the
running system. Not every directory is a package -- `webapps/` is a generator
run from `install.sh` -- and a package may carry a `README.md` of its own, which
stow's default ignore list keeps out of `$HOME`.

`README.md` is the long-form documentation and is kept current -- when a change
alters something it describes, update the prose there too.

## A change is not done until it is portable

Anything a fresh Arch install would need belongs in this repo: the config in a
stow package, and the package / systemd unit / step in `install.sh`. Never leave
it as state that only exists on the running machine. Per-machine and ephemeral
things -- credentials, caches, runtime state, tool-managed files -- stay out.

## Adding a quickshell panel

A panel is spread across more files than it looks. All of these, or it is only
half-added:

1. `quickshell/.config/quickshell/<Name>State.qml` -- a `Singleton` holding the
   data and `panelOpen`, with `toggle()` and `close()`. The panel is a window of
   its own, so the state cannot live in the bar module.
2. `quickshell/.config/quickshell/modules/<Name>Panel.qml` -- built on
   `components/Panel.qml`, which brings the card, the focus grab and Escape.
3. `quickshell/.config/quickshell/modules/<Name>.qml` -- the bar module, if it
   gets one, added to `bar/Bar.qml`.
4. `quickshell/.config/quickshell/shell.qml` -- instantiate the panel, and add
   an `IpcHandler` so `qs ipc call <target> toggle` reaches it.
5. `hypr/.config/hypr/hyprland.conf` -- a `bindd` running that IPC call. Use
   `bindd`, not `bind`: the description is what `super+shift+slash` lists.
6. `panels/.local/share/applications/qs-panel-<slug>.desktop` -- the same IPC
   call as an `Exec`, which is what puts the panel in the walker launcher under
   its own name. See `panels/README.md`; new files need `stow --no-folding
   panels` to appear.

Scripts a panel needs go in `quickshell/.config/quickshell/scripts/` and are
reached through `Paths.scripts`.

## Git

Never run git operations unless explicitly asked -- see the global CLAUDE.md.
