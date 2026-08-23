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
swapping back is a one-line change to that `exec-once` plus restoring the
`$mainMod, N` binding to `~/.config/waybar/scripts/notifications-menu.sh`.
Nothing else in the repo depends on which one is running.

Most modules that were shell scripts under waybar are now native: workspaces,
keyboard layout, media, volume, microphone, bluetooth, network, battery, tray
and the notification badge all read Hyprland / PipeWire / BlueZ /
NetworkManager / UPower / MPRIS directly, so the polling loops, the Hyprland
event daemon and every `pkill -RTMIN+N waybar` signal are gone.

Four scripts survive in `quickshell/.config/quickshell/scripts/` because they do
work no service exposes: weather, package updates, screen-recording state and
Claude Code usage.

`env = QS_ICON_THEME,breeze-dark` in `hyprland.conf` is what gives the tray its
icons — Qt has no icon theme configured on this system, and breeze-dark is the
one that ships light symbolic icons for a dark bar.

---

## 6. General Notes

- install.sh is safe to re-run
- System-level dotfiles live in dotfiles/system/
- User dotfiles are applied via standard stow
- All non-deterministic or GUI-based steps are documented here on purpose

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
