#!/usr/bin/env bash
set -euo pipefail

SECONDS=0
trap 'echo; echo "Install finished in $((SECONDS / 60))m $((SECONDS % 60))s"' EXIT

############################################################
#                                                          #
#              ARCH LINUX FRESH INSTALL SETUP              #
#                                                          #
############################################################

############################################################
# PRE-FLIGHT CHECKS                                        #
############################################################

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script as root."
  exit 1
fi

command -v sudo >/dev/null || {
  echo "sudo is required."
  exit 1
}

# Everything below assumes the repo is checked out here: hyprland.conf, the
# stow invocations and the sddm theme permissions all refer to it by path.
DOTFILES="$HOME/dotfiles"
[[ -d "$DOTFILES" ]] || {
  echo "Expected the repo at $DOTFILES, but it is not there."
  exit 1
}

# Steps that must never take the whole install down on their own -- a dead AUR
# package, a network blip mid-clone, a repo that has not caught up yet. The run
# stops and asks rather than deciding: skipping is nearly always right, but
# "the graphics driver failed to build" is not something to find out after the
# reboot, and only the person watching knows which case this is. With no
# terminal attached (piped, CI) it skips without asking. Either way the summary
# at the end lists everything that was skipped.
FAILED=()
try() {
  local what="$1"
  shift
  "$@" && return 0
  echo "!! failed: $what"
  # Ask on the terminal rather than on stdin: this script is also run piped
  # (`curl ... | bash`), where stdin is the script itself and reading from it
  # would eat the rest of the install. Opening /dev/tty is the test -- the node
  # exists in containers that have no controlling terminal to attach to.
  if { exec 3</dev/tty; } 2>/dev/null; then
    local answer=""
    read -rp "   Skip it and continue the install? [Y/n] " answer <&3 || true
    exec 3<&-
    if [[ "$answer" == [nN]* ]]; then
      echo "Aborting at your request."
      exit 1
    fi
  fi
  echo "!! skipped: $what"
  FAILED+=("$what")
}

# Every pacman install goes through here. The batch runs as one transaction,
# because forty invocations is forty database reads and forty sudo timestamps.
# But a batch is all-or-nothing -- one unresolvable name or one conflict and
# pacman installs none of the forty -- so a failed batch is retried package by
# package. That turns "the whole list failed, skip it?" into one question about
# the one package that is actually broken, with the other thirty-nine landing.
pac() {
  sudo pacman -S --needed --noconfirm "$@" && return 0
  echo "!! that pacman batch failed; retrying one package at a time"
  local pkg
  for pkg in "$@"; do
    try "pacman: $pkg" sudo pacman -S --needed --noconfirm "$pkg"
  done
}

# stow refuses to replace a real file, and several of these apps write their
# own config the first time they run -- Claude Code's settings.json, hunk's
# config.toml. Ask stow what it would collide with and move those aside so the
# repo's copy wins, keeping the original next to it as .pre-stow.
resolve_stow_conflicts() {
  local target
  while read -r target; do
    [[ -n "$target" && -f "$HOME/$target" && ! -L "$HOME/$target" ]] || continue
    mv "$HOME/$target" "$HOME/$target.pre-stow"
    echo "==> Moved existing ~/$target aside as ~/$target.pre-stow"
  done < <(stow -n -v 2 "$@" 2>&1 |
    sed -n 's/^  \* cannot stow .* over existing target \(.*\) since.*/\1/p')
}

############################################################
# DIRECTORY STRUCTURE                                      #
############################################################

# Screenshots is where screenshot.sh writes and Videos is where
# screen-record.sh does; Code is where the repos live and what the Nautilus
# sidebar points at.
echo "==> Creating directories"
mkdir -p \
  "$HOME/Downloads" \
  "$HOME/Pictures/Screenshots" \
  "$HOME/Videos" \
  "$HOME/Code"

############################################################
# DEBLOAT DEFAULT PACKAGES                                 #
############################################################

echo "==> Removing unwanted packages"
sudo pacman -Rns --noconfirm \
  kitty \
  dolphin \
  wofi ||
  true

############################################################
# MULTILIB REPOSITORY                                      #
############################################################

# archinstall leaves [multilib] commented out, and steam lives nowhere else --
# this is why `pacman -S steam` came back "target not found" and steam got
# pulled from the list rather than fixed. It has to happen before the first
# -Syu so the database is there when the package list below is resolved.
# The anchored pattern will not touch [multilib-testing] just above it.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  echo "==> Enabling the multilib repository"
  sudo sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
fi

############################################################
# CORE SYSTEM TOOLS                                        #
############################################################

# Only the nerd font actually referenced by the configs (ghostty, quickshell
# and hyprlock all ask for "JetBrainsMono Nerd Font") plus the symbol-only
# faces the bar glyphs come from. The `nerd-fonts` group is 69 packages and
# several GB for fonts nothing here names.
echo "==> Installing core tools"

# The one pacman step that is deliberately fatal and not routed through pac():
# a full -Syu that cannot complete means the mirrors, the keyring or the disk
# are wrong, and every package step below would fail the same way. Better to
# stop here than to ask forty times.
sudo pacman -Syu --noconfirm

pac \
  base-devel \
  git \
  openssh \
  sudo \
  curl \
  python \
  fcitx5 \
  fastfetch \
  ttf-jetbrains-mono-nerd \
  ttf-nerd-fonts-symbols \
  ttf-nerd-fonts-symbols-mono \
  stow

############################################################
# AUR HELPER (yay)                                         #
############################################################

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay (yay-bin)"

  pac base-devel git

  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"

  (
    cd "$tmpdir" || exit 1
    makepkg -si --noconfirm --needed
  )

  rm -rf "$tmpdir"
fi

############################################################
# AUR SIGNING KEYS                                         #
############################################################

# The 1password PKGBUILD pins validpgpkeys, so makepkg refuses to build until
# the key is in the user keyring. --noconfirm cannot answer the import prompt,
# so an unimported key fails the build and, without this, took the rest of the
# install down with it.
echo "==> Importing AUR signing keys"
try "1Password signing key" gpg --keyserver keyserver.ubuntu.com \
  --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22

############################################################
# HYPRLAND + WAYLAND STACK + QUICKSHELL                    #
############################################################

echo "==> Installing Hyprland and Wayland stack"

pac \
  hyprland \
  wayland \
  xorg-xwayland \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-utils \
  qt5-wayland \
  qt6-wayland \
  pipewire \
  pipewire-pulse \
  pipewire-alsa \
  pipewire-jack \
  wireplumber \
  libpulse \
  playerctl \
  brightnessctl \
  upower \
  power-profiles-daemon \
  grim \
  slurp \
  polkit \
  polkit-kde-agent \
  quickshell \
  breeze-icons

# power-profiles-daemon is D-Bus activated, but the quickshell battery panel
# asks systemd whether it is active before offering the profile buttons -- an
# activatable-but-never-started daemon would leave them showing a profile
# nothing had chosen. Enabling it settles that.
sudo systemctl enable power-profiles-daemon.service

# Hand the lid to Hyprland. Closing it can mean lock, blank, suspend, or
# nothing at all depending on the external monitor and the power adapter --
# a decision only the compositor has the facts for, and logind would beat it
# to the suspend. See hypr/.config/hypr/scripts/lid.sh.
echo "==> Handing lid-switch handling to Hyprland"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-lid.conf >/dev/null <<'LID'
# Managed by dotfiles/install.sh -- see ~/.config/hypr/scripts/lid.sh
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
LID

############################################################
# DISPLAY MANAGER (SDDM)                                   #
############################################################

# The sddm theme is stowed out of this repo rather than copied, so the sddm
# user has to be able to traverse every directory down to it -- including
# $HOME, which archinstall creates as 700.
echo "==> Installing and enabling SDDM"

pac sddm

sudo chmod o+x /home "$HOME"
theme_path="$DOTFILES"
for segment in sddm usr share sddm themes minimal-input; do
  theme_path="$theme_path/$segment"
  sudo chmod o+x "$theme_path"
done

sudo systemctl enable sddm

############################################################
# CORE / DEV / CLI PACKAGES                                #
############################################################

# bluez/bluez-utils back the quickshell Bluetooth module and panel, bluetui, and
# the `bluetoothctl pair` the panel falls back to for a device that wants a
# passkey confirmed; nothing else here depends on them. pacman-contrib is what provides
# `checkupdates`, which the bar's updates module shells out to. wtype is the
# virtual-keyboard client behind copy-and-paste.sh, which is how picking an
# entry in walker's clipboard history or emoji picker pastes it rather than
# only refilling the clipboard.
echo "==> Installing pacman packages"

pac \
  stow \
  neovim \
  lazygit \
  github-cli \
  fzf \
  ripgrep \
  fd \
  wl-clipboard \
  wtype \
  wf-recorder \
  unzip \
  yazi \
  ffmpeg \
  7zip \
  jq \
  poppler \
  zoxide \
  uv \
  imagemagick \
  tesseract \
  tesseract-data-eng \
  tesseract-data-por \
  pacman-contrib \
  bluez \
  bluez-utils \
  hyprpaper \
  hyprlock \
  hypridle \
  hyprpicker \
  hyprsunset \
  nautilus \
  sushi \
  gvfs-mtp \
  pika-backup \
  video-trimmer \
  adw-gtk-theme \
  qt5ct \
  qt6ct \
  kdeconnect \
  steam

############################################################
# BTRFS SNAPSHOTS                                          #
############################################################

# The disk layout from archinstall.md is btrfs with GRUB, so snapshots are
# available: snapper takes them, snap-pac fires one around every pacman
# transaction, and grub-btrfs puts them in the boot menu so a bad upgrade is
# recoverable without the ISO.
if [[ "$(findmnt -no FSTYPE /)" == "btrfs" ]]; then
  echo "==> Installing btrfs snapshot tooling"

  pac \
    btrfs-progs \
    snapper \
    snap-pac \
    grub-btrfs \
    btrfs-assistant \
    inotify-tools

  # create-config fails if the config already exists, which is the re-run case.
  [[ -f /etc/snapper/configs/root ]] ||
    try "snapper root config" sudo snapper -c root create-config /
  [[ -f /etc/snapper/configs/home ]] ||
    try "snapper home config" sudo snapper -c home create-config /home

  sudo systemctl enable snapper-timeline.timer snapper-cleanup.timer
  sudo systemctl enable grub-btrfsd.service
else
  echo "==> Root is not btrfs, skipping snapshot tooling"
fi

############################################################
# WIFI DONGLE (Realtek RTL8188GU)                          #
############################################################

# The RTL8188GU dongle boots in USB CD-ROM mode and has no
# in-kernel driver. usb_modeswitch flips it into wifi mode,
# and the rtl8188gu-dkms-git driver (in the AUR list below)
# provides the kernel module. dkms + linux-headers are
# required to build that module against the running kernel.
# NetworkManager (next section) drives the dongle via
# wpa_supplicant, so no separate wifi backend is enabled here.

echo "==> Installing wifi dongle support (RTL8188GU)"

pac \
  usb_modeswitch \
  dkms \
  linux-headers

############################################################
# NETWORKING (NetworkManager) + PROTON VPN                 #
############################################################

# Proton VPN's Linux app only ships a NetworkManager backend,
# so NetworkManager must own networking. We enable it and mask
# systemd-networkd (set up by archinstall) so the two don't
# fight over interfaces. networkd is socket-activated, so its
# sockets are masked too or it comes back to life. The switch
# takes effect on the reboot at the end of this script, so the
# rest of the install keeps its current network.

echo "==> Installing NetworkManager + Proton VPN"

pac \
  networkmanager \
  wpa_supplicant \
  network-manager-applet \
  networkmanager-openvpn \
  gnome-keyring \
  proton-vpn-gtk-app

sudo systemctl enable NetworkManager

sudo systemctl mask \
  systemd-networkd.service \
  systemd-networkd.socket \
  systemd-networkd-varlink.socket \
  systemd-networkd-varlink-metrics.socket \
  systemd-networkd-resolve-hook.socket

# Auto-unlock the GNOME keyring at login so Proton VPN can store
# its session/credentials (via libsecret) without a separate
# prompt. pam_gnome_keyring is optional, so a missing module
# never blocks login.
if ! grep -q pam_gnome_keyring /etc/pam.d/sddm; then
  echo "==> Enabling GNOME keyring auto-unlock in SDDM PAM"
  echo 'auth       optional     pam_gnome_keyring.so' |
    sudo tee -a /etc/pam.d/sddm >/dev/null
  echo 'session    optional     pam_gnome_keyring.so auto_start' |
    sudo tee -a /etc/pam.d/sddm >/dev/null
fi

############################################################
# DOCKER                                                   #
############################################################

echo "==> Installing Docker"

# Only the engine here. docker-buildx (and compose, debug, mcp, scout) are
# *provided by* the docker-desktop AUR package installed further down, and
# pacman treats provider and provided as a hard conflict -- asking for
# docker-buildx by name aborts the transaction on a machine that already has
# docker-desktop, and on a fresh one it wins the race and makes the later
# docker-desktop build the casualty instead. Let docker-desktop supply them.
pac docker

sudo systemctl enable docker.service
# Takes effect at the next login, which the reboot at the end covers.
sudo usermod -aG docker "$USER"

############################################################
# AUR PACKAGES                                             #
############################################################

# One package at a time: the AUR moves, and a single dead or unbuildable
# target used to abort the whole script -- taking the dotfiles, the shell and
# the graphics drivers down with it. Now a casualty is reported and skipped.
echo "==> Installing AUR packages"

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

aur_packages=(
  ghostty
  rtl8188gu-dkms-git
  hunk-bin
  herdr-bin
  elephant-bin
  elephant-desktopapplications-bin
  elephant-clipboard-bin
  elephant-symbols-bin # super+E emoji picker (elephant/symbols.toml)
  elephant-calc-bin    # `calc` is in walker's default provider list
  walker-bin
  gh-dash-bin
  ttf-joypixels
  1password
  brave-bin
  orca-slicer-bin
  bluetui
  wifitui
  wiremix
  btop
  docker-desktop
  kanata-bin
  tensaku # the screenshot annotation editor clicking a screenshot notification opens
)

for pkg in "${aur_packages[@]}"; do
  try "AUR: $pkg" yay -S --needed --noconfirm "$pkg"
done

# docker-desktop ships a user unit; enabling it here rather than checking the
# .wants symlink into the repo keeps systemd's bookkeeping out of the dotfiles.
if pacman -Q docker-desktop >/dev/null 2>&1; then
  systemctl --user enable docker-desktop.service
fi

############################################################
# NODE SETUP                                               #
############################################################

echo "==> Installing Node.js and packages"

pac nodejs npm
sudo npm install -g tree-sitter-cli

############################################################
# RUST TOOLCHAIN                                           #
############################################################

# Not what installs pkg any more -- since v0.1.2 it ships prebuilt binaries for
# all four linux/macOS targets and the block below downloads one. It stays
# because this box is where pkg gets worked on: pointing it at a clone means
# `cargo install --path ~/Code/pkg --root ~/.local` (README section 13), and
# that needs cargo on a machine that has never had it.
#
# Not for the installer's cargo fallback, which sounds like a second reason and
# is not -- it runs `cargo install --git` against the same GitHub the release
# download just failed to reach, so it only rescues a target with no published
# asset, and all four are published.
#
# rustup rather than the `rust` package so the toolchain can be updated
# independently of the distro, and the pacman build of rustup rather than the
# one from rustup.rs because that installer appends `. "$HOME/.cargo/env"` to
# .zshenv, .profile, .bashrc and .bash_profile -- none of which are in this
# repo. The pacman package puts its shims in /usr/bin, so nothing here has to
# touch PATH.
echo "==> Installing Rust"

pac rustup

# The package ships the shims only. Until a default toolchain is chosen every
# `cargo` call fails with "no default toolchain configured"; this both picks
# stable and downloads it, and is a no-op once it is in place.
try "rust stable toolchain" rustup default stable

############################################################
# TOOLS INSTALLED OUTSIDE PACMAN                           #
############################################################

# Claude Code has no Arch package; its installer drops a versioned binary in
# ~/.local/share/claude and links it into ~/.local/bin, which .zshrc puts on
# PATH. The bar's agent-usage module reads the state this writes.
if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
  echo "==> Installing Claude Code"
  try "Claude Code" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

# The three blocks below install our own projects the way a stranger would --
# from GitHub over HTTPS, not from ~/Code. A fresh machine has no checkouts yet
# and the 1Password SSH agent is not signed in at this point, so nothing here
# can be an editable install. Swapping one for a working copy later is a single
# command, noted in each block.

# buds-tui: `buds` in a terminal, for the earbud readings BlueZ does not carry
# -- battery per bud, noise-cancelling mode, equaliser. The quickshell Bluetooth
# module used to launch it on a click and opens its own panel now, so nothing in
# the shell depends on this being installed. For development, clone it and
# `uv tool install --force --python /usr/bin/python3 --editable ~/Code/buds-tui`.
#
# --python is not optional: without it uv builds the tool against a standalone
# interpreter that has no Bluetooth sockets, and buds cannot reach the earbuds.
if [[ ! -x "$HOME/.local/bin/buds" ]]; then
  echo "==> Installing buds-tui"
  try "buds-tui" uv tool install --python /usr/bin/python3 \
    git+https://github.com/danilolucasmd/buds-tui.git
fi

# pkg: one set of verbs over pacman, yay and flatpak. Its installer downloads
# the prebuilt binary for this platform from the latest GitHub release and puts
# it in ~/.local/bin, building from source with cargo only if that fails -- the
# rust toolchain above is what makes that fallback a fallback rather than an
# error. For development, clone it and
# `cargo install --path ~/Code/pkg --root ~/.local`.
#
# PKG_NO_MODIFY_PATH because .zshrc is a stow symlink into this repo: left to
# itself the installer appends its own PATH line straight into the dotfiles.
# ~/.local/bin is already exported there.
if [[ ! -x "$HOME/.local/bin/pkg" ]]; then
  echo "==> Installing pkg"
  try "pkg" bash -c 'set -o pipefail
    curl -fsSL https://raw.githubusercontent.com/danilolucasmd/pkg/main/install.sh |
      PKG_NO_MODIFY_PATH=1 sh'
fi

############################################################
# SYSTEM DOTFILES                                          #
############################################################

echo "==> Applying system dotfiles"
cd "$DOTFILES"
sudo stow -t / sddm

############################################################
# USER DOTFILES                                            #
############################################################

echo "==> Applying user dotfiles"
resolve_stow_conflicts \
  btop elephant fastfetch ghostty git hunk hypr lazygit nvim scripts sounds \
  quickshell tensaku walker wallpapers yazi zsh
stow \
  btop \
  elephant \
  fastfetch \
  ghostty \
  git \
  hunk \
  hypr \
  lazygit \
  nvim \
  scripts \
  sounds \
  quickshell \
  tensaku \
  walker \
  wallpapers \
  yazi \
  zsh

# dbus, claude and herdr are stowed with --no-folding so that
# ~/.local/share/dbus-1/services, ~/.claude and ~/.config/herdr stay real
# directories. Each of them is written into by something other than this repo --
# Claude Code keeps its credentials, history and caches in ~/.claude, and herdr
# keeps its session layout, logs, sockets and installed plugins (clone-layout,
# below) in ~/.config/herdr -- and letting stow fold any of them into a single
# symlink would send all of that into this repo.
#
# dbus carries one file: a D-Bus activation override for sushi (Nautilus'
# spacebar quick preview) that sets SUSHI_USE_GST_GTKSINK=1, because
# GStreamer's gtkglsink is broken on NVIDIA. See dbus/README.md.
stow --no-folding dbus

# nautilus carries the sidebar bookmarks, ~/.config/gtk-3.0/bookmarks, which
# GTK 4 still reads from the gtk-3.0 path and which the Open/Save dialogs share
# with Nautilus. --no-folding so that ~/.config/gtk-3.0 stays a real directory:
# folding it would pull the whole GTK 3 config dir into this repo, and theme
# tools like nwg-look write a settings.ini in there. --ignore keeps dconf.ini,
# which is loaded below rather than symlinked, out of $HOME; it adds to stow's
# built-in ignore list rather than replacing it, so README.md is still skipped.
resolve_stow_conflicts --no-folding --ignore='^dconf\.ini$' nautilus
stow --no-folding --ignore='^dconf\.ini$' nautilus

# The rest of what Nautilus remembers -- list view instead of icon grid, hidden
# files in the file dialogs -- lives in dconf, a binary database the whole
# desktop shares, so it is the one thing here that cannot be a stow symlink.
# `dconf load` merges: it writes the keys in the keyfile and leaves every other
# key alone, which is what makes loading at `/` safe and re-runnable. Only keys
# that differ from the GSettings schema defaults are in there; see
# nautilus/README.md for how to add one. Needs a dconf the user can write, so
# it is deliberately not sudo.
try "nautilus/GTK preferences" dconf load / < "$DOTFILES/nautilus/dconf.ini"

# panels carries the desktop entries that put every quickshell panel in the
# walker launcher. --no-folding so that ~/.local/share/applications stays a real
# directory -- webapps/generate.sh writes the Brave web-app launchers in there,
# and folding would send those into this repo. See panels/README.md.
stow --no-folding panels

# kanata carries two files: the keymap and a systemd user unit. --no-folding so
# that ~/.config/systemd/user stays a real directory -- `systemctl --user
# enable` writes its default.target.wants symlink in there, and folding would
# put systemd's bookkeeping inside this repo.
resolve_stow_conflicts --no-folding kanata
stow --no-folding kanata

# kanata reads the built-in keyboard from /dev/input/event* (group `input`) and
# writes the remapped stream to /dev/uinput. logind already grants the active
# seat's user an ACL on /dev/uinput, so `input` is the only group needed. Takes
# effect at the next login.
sudo usermod -aG input "$USER"

# /dev/uinput only exists once the module is loaded; on a fresh boot nothing
# else pulls it in.
echo uinput | sudo tee /etc/modules-load.d/uinput.conf >/dev/null

if pacman -Q kanata-bin >/dev/null 2>&1; then
  systemctl --user enable kanata.service
fi

resolve_stow_conflicts --no-folding claude
stow --no-folding claude

# caveman is a Claude Code plugin that swaps Claude's prose for clipped,
# telegraphic answers -- same technical content, far fewer output tokens. The
# marketplace it comes from and its enabled state are both declared in the
# settings.json stowed just above, but those declarations do not install
# anything on their own: the plugin CLI still has to clone the marketplace into
# ~/.claude/plugins and register the plugin. That is all these two commands do,
# and they write back into the same stowed settings.json, so the entries this
# repo already tracks are rewritten identically and the file stays clean.
#
# Deliberately after the stow: run before it and the CLI would create a real
# ~/.claude/settings.json, which resolve_stow_conflicts would then shove aside
# as .pre-stow. Upstream: https://github.com/JuliusBrussee/caveman
#
# `claude` is in ~/.local/bin, which .zshrc puts on PATH -- but this script is
# bash and never sources it, so the binary is addressed by path when the
# command is not already visible.
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
if [[ -x "$CLAUDE_BIN" ]]; then
  if ! "$CLAUDE_BIN" plugin marketplace list 2>/dev/null |
    grep -q 'JuliusBrussee/caveman'; then
    try "caveman marketplace" \
      "$CLAUDE_BIN" plugin marketplace add JuliusBrussee/caveman
  fi

  if ! "$CLAUDE_BIN" plugin list 2>/dev/null | grep -q 'caveman@caveman'; then
    try "caveman plugin" \
      "$CLAUDE_BIN" plugin install caveman@caveman --scope user
  fi
fi

# caveman resolves its default mode from, in order: $CAVEMAN_DEFAULT_MODE, a
# checked-in .caveman.json in the repo being worked on, this user config, and
# finally its own built-in default -- which happens to be `full` today, so
# without this file the mode every session opens in is whatever upstream last
# decided. Pinning it here makes the choice ours and survives that changing.
#
# --no-folding so ~/.config/caveman stays a real directory: the caveman CLI
# writes its own state (login token, cavemem) alongside this file, and none of
# that belongs in the repo.
resolve_stow_conflicts --no-folding caveman
stow --no-folding caveman

resolve_stow_conflicts --no-folding herdr
stow --no-folding herdr

# herdr writes ~/.claude/hooks/herdr-agent-state.sh and owns it -- the file says
# so in its header, and herdr overwrites it on every update. The hook entry that
# calls it is in the settings.json above; this puts the script itself in place.
try "herdr Claude integration" herdr integration install claude

# Our own herdr plugin: every new workspace or worktree opens with the tab and
# pane geometry of the one it was created from. Fetched from GitHub into
# ~/.config/herdr/plugins, which the --no-folding stow above keeps out of this
# repo. Needs jq, installed with the pacman packages. For development, clone it
# and `herdr plugin link ~/Code/herdr-clone-layout` against a running server.
try "herdr clone-layout plugin" herdr plugin install \
  danilolucasmd/herdr-clone-layout --yes

############################################################
# ZSH + on-my-zsh                                          #
############################################################

pac zsh

export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

############################################################
# ZSH PLUGINS (oh-my-zsh custom)                           #
############################################################

echo "==> Installing zsh plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  git clone https://github.com/Aloxaf/fzf-tab \
    "$ZSH_CUSTOM/plugins/fzf-tab"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

############################################################
# SERVICES                                                 #
############################################################

echo "==> Enabling services"
sudo systemctl enable bluetooth.service

############################################################
# DEFAULT APPLICATIONS                                     #
############################################################

# Nautilus owns directories. This used to name `ghostty.desktop`, which does
# not exist -- ghostty ships com.mitchellh.ghostty.desktop -- and xdg-mime
# writes whatever it is given without checking, so the bad entry sat in
# mimeapps.list doing nothing but shadowing the real handler.
echo "==> Setting default applications"
xdg-mime default org.gnome.Nautilus.desktop inode/directory

if [[ "$SHELL" != *zsh ]]; then
  chsh -s /usr/bin/zsh
fi

############################################################
# GTK CEDILLA FIX                                          #
############################################################

# Makes ' + c produce ç rather than ć on the us-intl layout. Patches files
# owned by gtk2/gtk3 and libx11, so it has to run again after those packages
# are upgraded. See post-install.sh.
echo "==> Applying GTK cedilla fix"
try "cedilla fix" "$DOTFILES/post-install.sh"

############################################################
# BRAVE WEB APPS                                           #
############################################################

# Generate toolbar-free Brave web-app launchers (--app=URL)
# from webapps/apps.conf. See webapps/README.md.
echo "==> Generating Brave web app launchers"
try "Brave web apps" "$DOTFILES/webapps/generate.sh"

############################################################
# SANITY CHECKS                                            #
############################################################

command -v Hyprland >/dev/null || {
  echo "ERROR: Hyprland not found."
  exit 1
}

ls /usr/share/wayland-sessions/hyprland.desktop >/dev/null || {
  echo "ERROR: Hyprland session file missing."
  exit 1
}

############################################################
# DONE                                                     #
############################################################

echo "========================================================"
if ((${#FAILED[@]})); then
  echo " Setup complete, but these steps were skipped:"
  printf '   - %s\n' "${FAILED[@]}"
  echo
fi
echo " Reboot and log into the Hyprland session."
echo " Review README.md for remaining manual steps."
echo "========================================================"
