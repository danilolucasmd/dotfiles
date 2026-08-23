# Arch Linux Fresh Install – Manual & System Notes

This repository provides a reproducible setup for a fresh Arch Linux installation
using:

- pacman + yay for packages
- GNU Stow for dotfiles (user and system)
- A single `install.sh` bootstrap script

Most of the system is fully automated.
This document describes what is intentionally manual and what requires
special attention over time.
 
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e086451d-e5fe-48d8-bd4f-c63ac52cff3c" />

<img width="1920" height="1079" alt="image" src="https://github.com/user-attachments/assets/9160ed21-6f24-4511-8e8b-94888a4214c0" />

---

### Archinstall

If Arch is not installed yet you can follow the [Arch Linux Installation Guide](https://github.com/danilolucasmd/dotfiles/blob/arch/archinstall.md).

---

## 1. Nautilus Sidebar

Add the following directories to Nautilus’ left sidebar manually:

- Code
- Downloads
- Pictures

---

## 2. Brave Browser Language Settings

In Brave settings:

1. Add Portuguese (Brazil) to Languages
2. Enable spell check for:
   - English
   - Portuguese (Brazil)

---

## 3. 1Password

After installation:

- Open 1Password
- Sign in
- Enable SSH agent

---

## 4. Proton VPN

After installation:

- Open the Proton VPN app and sign in
- `install.sh` enables NetworkManager and masks `systemd-networkd`;
  the app cannot connect if `systemd-networkd` is running instead

---

## 5. Status Bar

The bar is [quickshell](https://quickshell.org) (`quickshell/.config/quickshell`),
launched by `exec-once = qs` in `hyprland.conf`.

It replaced waybar. The waybar config is still in the repo and still stowed, so
swapping back is a one-line change to that `exec-once` — but it is no longer a
clean swap, because quickshell is now the notification daemon as well (below).
Under waybar the bell reads a history file that only mako writes, so going back
means reinstalling mako and restoring `exec-once = mako` and the `$mainMod, N`
binding to `~/.config/waybar/scripts/notifications-menu.sh` too.

Most modules that were shell scripts under waybar are now native: workspaces,
keyboard layout, media, volume, microphone, bluetooth, network, battery, tray
and the notification badge all read Hyprland / PipeWire / BlueZ /
NetworkManager / UPower / MPRIS directly, so the polling loops, the Hyprland
event daemon and every `pkill -RTMIN+N waybar` signal are gone.

Five scripts survive in `quickshell/.config/quickshell/scripts/` because they do
work no service exposes: weather, package updates, screen-recording state,
Claude Code usage, and matching a notification against the window list to find
the app that sent it.

The right cluster is split in two. Media, keyboard layout, microphone, volume,
bluetooth, Claude usage, updates and notifications are always on screen; the
recording indicator, network, battery and the tray fold away behind a chevron
that stays the leftmost thing in the cluster. Clicking it slides them out
rightward from the chevron, with a hairline marking where they end and the
always-visible modules begin; those never shift.

Moving the pointer off the bar folds them away after a second, and coming
back restarts that countdown — a hand on its way to a tray icon dips off the bar
constantly. An open tray menu holds them regardless, since reaching one means
leaving the bar.

`env = QS_ICON_THEME,breeze-dark` in `hyprland.conf` is what gives the tray its
icons — Qt has no icon theme configured on this system, and breeze-dark is the
one that ships light symbolic icons for a dark bar.

---

## 6. Notifications

Quickshell is the notification daemon. It owns `org.freedesktop.Notifications`
outright: the popups, the bell in the bar and the history panel (`super+N`, or
click the bell) are one thing rather than three.

**mako is gone** — package, config and stow entry. Only one process can own the
bus name, so this was an either/or, and mako had no history of its own: keeping
it meant keeping the `on-notify` hook that shelled out to `makoctl list -j` to
append JSONL, and the walker menu that read the file back. Both are deleted. If
mako is still installed from an earlier run, `sudo pacman -Rns mako` removes it;
`install.sh` no longer pulls it in.

What carried over unchanged: the popups sit in the same corner with the same
per-urgency border colours (low grey, normal peach, critical red), critical ones
stay up until they are dealt with, timeouts apps ask for are ignored in favour
of ours, and track-change notifications get two seconds and no history entry.

Clicking a notification — or hitting enter on it in the panel — still jumps to
the app that sent it, through `focus-sender.sh`, which is mako's old hook with
the `makoctl` half removed. The matching got better than mako's in the process,
because notifications say more than their app name does:

- **Web apps.** Brave stamps `desktop-entry=brave-browser` on everything and its
  own default action raises the *browser*, so a WhatsApp message used to land on
  whatever tab was last open. But Brave puts the origin on the first line of the
  body (`web.whatsapp.com`), and `webapps/generate.sh` builds the launcher
  classes from the same host (`brave-web.whatsapp.com__-Default`), so that is
  matched first and the message goes to its own window.
- **The app's own action is the fallback, not the first choice.** If the origin
  names a site with no web-app window open, the script bows out and the
  notification's default action runs instead — Brave opens the tab, which is the
  right answer there. That path needs `misc:focus_on_activate = true` in
  `hyprland.conf`.
- **Anonymous senders.** herdr notifies through a bare `notify-send`: no desktop
  entry, app name "notify-send", and the project in the body ("dotfiles · 1 · 1
  agent"). With nothing to identify the app, the script scores windows by the
  words their titles share with the notification, which finds the ghostty
  window titled `danilo-pc: dotfiles` — and picks the right terminal when
  several projects are open.

What is new: notifications can carry action buttons now, the popups use the
bar's palette instead of mako's hardcoded Nord one, and the history is a panel
with a keyboard (`j`/`k` to move, `enter` to open, `d` to dismiss, `D` to clear)
rather than a dmenu whose only verb was "dismiss".

History lives in `~/.local/state/quickshell/notifications.jsonl`, capped at 200
entries, and survives reboots. The old mako store at
`~/.local/state/mako-history/` was migrated into it and can be deleted.

---

## 7. Nautilus Video Previews (NVIDIA)

Fully automated by `install.sh` — nothing to do by hand. Noted here because the
failure is baffling if the override ever goes missing.

Pressing <kbd>Space</kbd> on a video in Nautilus opens **sushi**, whose GL video
sink (`gtkglsink`) is broken on NVIDIA: it either errors with "Failed to
initialize OpenGL with Gtk" or renders a solid dark green rectangle. The `dbus`
stow package ships a D-Bus activation override setting
`SUSHI_USE_GST_GTKSINK=1`, which forces the working software sink.

Full write-up, including how to verify it: `dbus/README.md`.

---

## 8. General Notes

- install.sh is safe to re-run
- System-level dotfiles live in dotfiles/system/
- User dotfiles are applied via standard stow
- `dbus` is stowed with `--no-folding`, everything else with plain stow
- All non-deterministic or GUI-based steps are documented here on purpose

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
