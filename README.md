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

Then:

```bash
sudo pacman -Syu --needed git
git clone -b arch https://github.com/danilolucasmd/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Two things that are load-bearing:

- **`-b arch`.** The repo's default branch is `omarchy`; a plain `git clone`
  checks that out instead and none of this applies.
- **`~/dotfiles`.** `install.sh` refuses to run anywhere else, and
  `hyprland.conf` and the SDDM theme refer to the path directly.

`install.sh` is safe to re-run. Steps that can fail on their own — an AUR
package that stopped building, a clone that timed out — are reported and skipped
rather than aborting the run, and the script prints what it skipped at the end.

---

## 1. Nautilus Sidebar

Add the following directories to Nautilus' left sidebar manually:

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

Vimium's exported settings live in `vimium/`. They are not stowed — the
extension keeps its options in browser storage — so import them by hand from
the extension's options page after signing in.

---

## 3. 1Password

After installation:

- Open 1Password
- Sign in
- Enable SSH agent

`install.sh` imports 1Password's code-signing key before the AUR run, because
its PKGBUILD pins `validpgpkeys` and `makepkg --noconfirm` cannot answer the
import prompt on its own.

Note the ordering: the SSH agent is not available until you have signed in, so
everything `install.sh` clones is cloned over HTTPS.

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

It replaced waybar, which has since been deleted from the repo along with its
config and its stow entry. Every module that was a polling shell script under
waybar is now native — workspaces, keyboard layout, media, volume, microphone,
bluetooth, network, battery, tray and the notification badge read Hyprland /
PipeWire / BlueZ / NetworkManager / UPower / MPRIS directly — so the polling
loops, the Hyprland event daemon and every `pkill -RTMIN+N waybar` signal are
gone with it.

`playerctl` and `upower` are installed explicitly for this reason: they used to
arrive as waybar dependencies, and the media keys and the battery module need
them regardless.

Five scripts survive in `quickshell/.config/quickshell/scripts/` because they do
work no service exposes: weather, package updates, screen-recording state,
Claude Code usage, and matching a notification against the window list to find
the app that sent it. `updates.sh` shells out to `checkupdates`, which is why
`pacman-contrib` is in the package list.

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
bus name, so this was an either/or, and mako had no history of its own. If mako
is still installed from an earlier run, `sudo pacman -Rns mako` removes it;
`install.sh` no longer pulls it in.

The popups sit in the corner with per-urgency border colours (low grey, normal
peach, critical red), critical ones stay up until they are dealt with, timeouts
apps ask for are ignored in favour of ours, and track-change notifications get
two seconds and no history entry.

Clicking a notification — or hitting enter on it in the panel — jumps to the app
that sent it, through `focus-sender.sh`. The matching is better than mako's,
because notifications say more than their app name does:

- **Web apps.** Brave stamps `desktop-entry=brave-browser` on everything and its
  own default action raises the *browser*, so a WhatsApp message used to land on
  whatever tab was last open. But Brave puts the origin on the first line of the
  body (`web.whatsapp.com`), and the generated launchers carry a matching class,
  so that is matched first and the message goes to its own window.
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

Notifications can carry action buttons, the popups use the bar's palette, and
the history is a panel with a keyboard (`j`/`k` to move, `enter` to open, `d` to
dismiss, `D` to clear).

History lives in `~/.local/state/quickshell/notifications.jsonl`, capped at 200
entries, and survives reboots.

Claude Code's own notifications go through `preferredNotifChannel: "ghostty"` in
`claude/.claude/settings.json` — ghostty's native channel, which needs no
forwarding. herdr's toasts go to the system with `[ui.toast] delivery = "system"`
in its config.

---

## 7. Terminal Multiplexer

[herdr](https://herdr.dev) is the multiplexer (`herdr/.config/herdr/config.toml`).

**tmux is gone** — package, config, plugin list and stow entry. Anything that
integrated with it went with it:

- `nvim/.config/nvim/lua/util/herdr-nav.lua` is the old `tmux-nav.lua`
  retargeted at `herdr pane focus`. Ctrl+hjkl still moves between nvim splits
  and hands off to the neighbouring pane at the edge; `herdr pane edges` gives
  the same no-wrap guard `#{pane_at_left}` used to.
- `claudecode.nvim`'s "jump to the Claude pane" binding uses `herdr pane focus`
  the same way.
- The fzf-tab completion menu renders inline. `ftb-tmux-popup` drew it in a
  floating tmux popup and hangs outside tmux rather than falling back.
- Claude Code's tmux hooks — fourteen events routed into `tmux-agent-sidebar`,
  plus two that rang the pane tty directly — are all removed. herdr tracks agent
  panes natively.

herdr's own Claude Code integration is installed by `install.sh` with
`herdr integration install claude`. It writes
`~/.claude/hooks/herdr-agent-state.sh` and owns that file — the header says as
much, and herdr rewrites it on update — so it is deliberately not tracked here.
The `SessionStart` hook entry that calls it *is* tracked, in
`claude/.claude/settings.json`.

`herdr/.config/herdr/` is stowed with `--no-folding` for the same reason
`~/.claude` is: herdr keeps its session layout, logs, sockets and installed
plugins in there, and a folded `~/.config/herdr` symlink would write all of that
into this repo. Only `config.toml` is tracked.

One of those plugins is ours — [herdr-clone-layout](https://github.com/danilolucasmd/herdr-clone-layout),
installed by `install.sh` with `herdr plugin install
danilolucasmd/herdr-clone-layout --yes` (section 13). Every new workspace or
worktree opens with the tab and pane geometry of the one it was created from. It
needs `jq`, which is in the pacman list.

---

## 8. Claude Code

`claude/.claude/` is stowed with `--no-folding`, so `~/.claude` stays a real
directory. Claude Code keeps credentials, history, caches and file state in
there; folding it into a single symlink would send all of that into this repo.

Only two files are tracked: `CLAUDE.md` and `settings.json`. Deliberately not
tracked:

- `autoMode.environment`, a per-repo analysis cache Claude Code rewrites itself.
- `hooks/herdr-agent-state.sh`, which herdr owns (section 7).

`statusLine` runs `quickshell/.config/quickshell/scripts/agent-usage-statusline.sh`.
That is not cosmetic — it is the freshest source the bar's usage module has.
Claude Code hands `.rate_limits` to every status-line render, so the module gets
near-live numbers for free, without touching the OAuth usage endpoint (which
rate-limits hard: ~20 requests in 30s earns a multi-minute 429). Without the
entry the module falls back to polling and goes stale between sessions.

Claude Code itself has no Arch package. `install.sh` runs the official installer,
which drops a versioned binary in `~/.local/share/claude` and links it into
`~/.local/bin` — which `.zshrc` puts on `PATH` (rather than relying on
`~/.profile`, which the installer writes and which is not in this repo).

---

## 9. Nautilus Video Previews (NVIDIA)

Fully automated by `install.sh` — nothing to do by hand. Noted here because the
failure is baffling if the override ever goes missing.

Pressing <kbd>Space</kbd> on a video in Nautilus opens **sushi**, whose GL video
sink (`gtkglsink`) is broken on NVIDIA: it either errors with "Failed to
initialize OpenGL with Gtk" or renders a solid dark green rectangle. The `dbus`
stow package ships a D-Bus activation override setting
`SUSHI_USE_GST_GTKSINK=1`, which forces the working software sink.

Full write-up, including how to verify it: `dbus/README.md`.

---

## 10. Btrfs Snapshots

The disk layout in `archinstall.md` is btrfs with GRUB, so `install.sh` installs
snapper, snap-pac and grub-btrfs and enables the timeline/cleanup timers. A
snapshot is taken around every pacman transaction and appears in the GRUB menu,
so a bad upgrade is recoverable without reaching for the ISO.

The whole section is skipped if `/` is not btrfs, so the script still works on
an ext4 install — you just get no snapshots.

`snapper create-config` runs only when the config does not already exist, which
is what makes re-running the script safe.

---

## 11. GTK Cedilla Fix

`post-install.sh` makes `'` + `c` produce ç rather than ć on the us-intl layout.
`install.sh` calls it, so a fresh install needs nothing.

It patches files owned by **gtk2, gtk3 and libx11**, so a package upgrade
reverts it. Re-run `./post-install.sh` when the cedilla stops working.

---

## 12. Manual Development Toolchains

`.zshrc` puts these on `PATH`, but nothing installs them — they are large,
versioned by project, and better managed by their own tooling:

- `~/.local/share/jdks/current` (`JAVA_HOME`)
- `~/Android/Sdk` (`ANDROID_HOME`) — platform-tools, emulator, cmdline-tools
- `~/.opencode/bin`

A missing directory on `PATH` is harmless, so a fresh install works without
them.

---

## 13. Our Own Projects

Three of the tools this setup depends on are ours. `install.sh` installs all
three **from GitHub over HTTPS**, not from `~/Code` — a fresh machine has no
checkouts, and the 1Password SSH agent is not signed in that early in the run.
So none of them starts out as a development install:

| Project | Installed as | Point it at a clone |
| --- | --- | --- |
| [buds-tui](https://github.com/danilolucasmd/buds-tui) | `uv tool install --python /usr/bin/python3 git+https://…` | `uv tool install --force --python /usr/bin/python3 --editable ~/Code/buds-tui` |
| [pkg](https://github.com/danilolucasmd/pkg) | its own installer, `curl … \| sh` | `cargo install --path ~/Code/pkg --root ~/.local` |
| [herdr-clone-layout](https://github.com/danilolucasmd/herdr-clone-layout) | `herdr plugin install danilolucasmd/herdr-clone-layout --yes` | `herdr plugin link ~/Code/herdr-clone-layout` |

Details that are easy to get wrong:

- **buds-tui's `--python` is not optional.** Without it `uv` builds the tool
  against a standalone interpreter that has no Bluetooth sockets, and `buds`
  fails the moment it reaches for the earbuds. The quickshell Bluetooth module
  opens it with `ghostty -e ~/.local/bin/buds`.
- **`pkg` runs with `PKG_NO_MODIFY_PATH=1`.** Its installer offers to append a
  `PATH` line to your shell startup file, and `.zshrc` is a stow symlink into
  this repo — left alone it would write into the dotfiles. `~/.local/bin` is
  already exported there.
- **`pkg` has no prebuilt binary fallback here.** If the release download fails
  the installer builds with cargo, and nothing in `install.sh` installs a rust
  toolchain, so that path reports and skips instead of succeeding.
- **`herdr plugin link` needs a running herdr server**; `herdr plugin install`
  does not.

---

## 14. General Notes

- `install.sh` is safe to re-run
- System-level dotfiles (`sddm`) are stowed with `sudo stow -t /`
- `dbus`, `claude` and `herdr` are stowed with `--no-folding`, everything else
  plainly
- When an app has already written a config that stow wants to own, `install.sh`
  moves the original aside as `<name>.pre-stow` rather than failing
- All non-deterministic or GUI-based steps are documented here on purpose

### Leftovers worth removing

Superseded packages that may still be installed from earlier runs. Nothing
depends on them and `install.sh` no longer pulls them in:

```bash
sudo pacman -Rns mako dunst rofi rofi-calc anyrun cliphist pcmanfm tmux waybar
```

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
