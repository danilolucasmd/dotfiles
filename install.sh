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

# On a btrfs root this script REPLACES THE BOOTLOADER: archinstall leaves you on
# systemd-boot, and the snapshot section installs Limine over it so that btrfs
# snapshots become boot entries (see README.md section 10). The systemd-boot EFI
# binary and its NVRAM entry are left in place as a fallback, but this is the
# one step here that can cost you a reboot, so it is worth knowing up front.
echo "==> Note: on btrfs, this migrates the bootloader to Limine. See README.md section 10."

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
# faces the bar glyphs come from -- and hyprlock's fingerprint indicator, which
# names "Symbols Nerd Font Mono" outright because the text face draws that
# glyph wider than its own cell. The `nerd-fonts` group is 69 packages and
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
  usbutils \
  ttf-jetbrains-mono-nerd \
  ttf-nerd-fonts-symbols \
  ttf-nerd-fonts-symbols-mono \
  stow

############################################################
# NAME RESOLUTION (prefer IPv4)                            #
############################################################

# aur.archlinux.org resolves to both A and AAAA records, glibc prefers the
# IPv6 one by default, and on a connection whose IPv6 path to the AUR does not
# work every `git clone` and every yay build dies with "Recv failure:
# Connection reset by peer". That is not hypothetical -- it is what this
# machine does, and it takes the whole AUR half of the install with it.
#
# This used to be `sysctl -w net.ipv6.conf.all.disable_ipv6=1` immediately
# before each AUR step, which fixed nothing: `-w` does not persist, and
# `all.disable_ipv6` does not retract an address an interface already holds, so
# the machine kept its global IPv6 address and kept preferring it.
#
# The supported fix is to change the resolver's precedence rather than to
# switch the protocol off: RFC 3484 says the highest-precedence match wins, so
# giving the IPv4-mapped range a higher label than the default 10 for ::/0 puts
# IPv4 first everywhere -- git, curl, pacman, yay -- while leaving IPv6 working
# for anything that reaches it successfully.
echo "==> Preferring IPv4 in name resolution"
sudo tee /etc/gai.conf >/dev/null <<'GAI'
# Managed by dotfiles/install.sh
#
# Prefer IPv4 over IPv6. See the NAME RESOLUTION section of install.sh for why;
# the short version is that the AUR is unreachable over IPv6 from here and the
# default precedence made every AUR build fail.
#
# Everything else is glibc's default and is left implicit on purpose: this file
# replaces /etc/gai.conf wholesale, and listing the defaults would only create
# something to drift.
precedence ::ffff:0:0/96  100
GAI

############################################################
# AUR HELPER (yay)                                         #
############################################################

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay (yay-bin)"

  pac base-devel git

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

# The charge threshold -- the percentage the firmware stops charging at, which
# the battery panel's slider sets -- is a root-owned sysfs attribute, so without
# this every move of that slider is a polkit password prompt. The rule hands
# write access to `wheel` on every pack that has the attribute, at every plug
# and unplug, so the panel can set it directly. Reading it never needed the
# rule; only writing does.
echo "==> Letting wheel set the battery charge threshold"
sudo tee /etc/udev/rules.d/99-charge-threshold.rules >/dev/null <<'THRESHOLD'
# Managed by dotfiles/install.sh -- see quickshell/.config/quickshell/scripts/charge-limit.sh
ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT*", RUN+="/bin/sh -c 'chgrp wheel /sys%p/charge_control_end_threshold /sys%p/charge_control_start_threshold 2>/dev/null; chmod g+w /sys%p/charge_control_end_threshold /sys%p/charge_control_start_threshold 2>/dev/null'"
THRESHOLD
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply

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
# entry in the clipboard history, or an emoji in the quickshell picker, pastes
# it rather than only refilling the clipboard.
#
# cliphist and libqalculate are the two halves of the launcher that are not
# quickshell's own: cliphist is the clipboard store the `wl-paste --watch` pair
# in hyprland.conf feeds, and libqalculate brings `qalc`, which answers the `=`
# prefix. Both replaced an elephant provider, and both are in the official
# repos where those were three AUR builds.
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
  cliphist \
  libqalculate \
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

# The recovery story for this system, and the reason it can survive a bad
# upgrade without an ISO. snapper takes the snapshots, snap-pac fires a pair
# around every pacman transaction (so `pkg` and `yay` are covered too -- they
# both end up in libalpm), and Limine puts the root snapshots in the boot menu
# with the kernel each one was taken with.
#
# That last clause is why this is Limine and not GRUB. archinstall mounts the
# ESP at /boot, so vmlinuz and the initramfs live outside every btrfs snapshot;
# rolling back with grub-btrfs would boot today's kernel against an old
# /usr/lib/modules. limine-snapper-sync copies each snapshot's boot files onto
# the ESP and pairs them back up. It is also what omarchy does.
#
# Everything machine-specific here is derived at run time -- filesystem UUID,
# root subvolume, the installing user. snapshots/ holds only what is portable.
if [[ "$(findmnt -no FSTYPE /)" == "btrfs" ]]; then
  echo "==> Installing btrfs snapshot tooling"

  pac \
    btrfs-progs \
    snapper \
    snap-pac \
    btrfs-assistant \
    inotify-tools \
    limine

  # create-config fails if the config already exists, which is the re-run case.
  [[ -f /etc/snapper/configs/root ]] ||
    try "snapper root config" sudo snapper -c root create-config /
  [[ -f /etc/snapper/configs/home ]] ||
    try "snapper home config" sudo snapper -c home create-config /home

  # The curated configs are copied over whatever create-config produced, every
  # run, so a re-run re-asserts them. They cannot be stow symlinks: snapper
  # rewrites its own config file whenever anything calls set-config, and that
  # would have it writing into this repo. Same shape as nautilus/dconf.ini.
  #
  # snapperd is stopped first, and ALLOW_USERS is substituted into the file
  # rather than applied afterwards with `snapper set-config`. Both for the same
  # reason: snapperd caches each config in memory and set-config writes the
  # whole file back from that cache, so copying the file and then calling
  # set-config silently reverts everything except the key just set. It is
  # dbus-activated, so stopping it costs nothing -- the next snapper call brings
  # it back, reading the file fresh.
  try "stop snapperd" sudo systemctl stop snapperd.service
  for cfg in root home; do
    if [[ -f "/etc/snapper/configs/$cfg" ]]; then
      sed "s|@@ALLOW_USERS@@|$USER|" "$DOTFILES/snapshots/snapper-$cfg" |
        sudo install -m 640 -o root -g root /dev/stdin "/etc/snapper/configs/$cfg"
    fi
  done

  sudo install -m 644 -o root -g root "$DOTFILES/snapshots/snap-pac.ini" /etc/snap-pac.ini

  # Quota accounting is expensive on a large filesystem and nothing here reads
  # it: snapper's space-aware cleanups use SPACE_LIMIT/FREE_LIMIT, which work
  # off plain statfs. Fails harmlessly when quota was never enabled.
  try "btrfs quota" sudo btrfs quota disable /

  sudo systemctl enable snapper-timeline.timer snapper-cleanup.timer

  # -- Limine ------------------------------------------------------------

  # Where the ESP actually is. /boot on the archinstall systemd-boot layout this
  # repo documents, /boot/efi on the GRUB layout older versions of
  # archinstall.md told you to pick.
  esp_path="$(bootctl --print-esp-path 2>/dev/null || echo /boot)"

  # A machine that genuinely boots GRUB is left alone. Installing Limine there
  # would put it first in NVRAM and quietly replace a working bootloader on a
  # machine nobody is watching -- and that layout usually mounts the ESP at
  # /boot/efi with /boot inside the root subvolume, which is not what any of
  # this was built or tested against. Removing GRUB is a decision to make
  # deliberately, not a side effect of re-running the installer.
  #
  # Note this repo's own history: archinstall.md used to specify GRUB, so a
  # machine set up from these dotfiles before the Limine switch will land here.
  # Snapshots still work on it -- snapper, snap-pac and `snapshot` are all
  # configured above. It is only the boot menu that waits.
  grub_is_live=no
  [[ -f /boot/grub/grub.cfg || -f "$esp_path/grub/grub.cfg" ]] && grub_is_live=yes
  pacman -Qq grub >/dev/null 2>&1 && pacman -Qeq grub >/dev/null 2>&1 && grub_is_live=yes

  if [[ "$grub_is_live" == "yes" && "${DOTFILES_FORCE_LIMINE:-}" != "1" ]]; then
    echo "==> GRUB is this machine's bootloader; leaving it alone"
    echo "    Snapshots are configured and working, but they will not appear in"
    echo "    the boot menu. To switch this machine to Limine deliberately:"
    echo "      sudo pacman -Rns grub grub-btrfs && DOTFILES_FORCE_LIMINE=1 ./install.sh"
  else

  # Both AUR, and both slow: they compile a native image with gradle against a
  # GraalVM their PKGBUILD downloads, so expect a long first run. A failure
  # here costs the boot menu, not the snapshots -- those keep working.
  #
  # They cannot be installed with a plain `yay -S`, because Arch's gradle
  # package is incomplete for this build. Gradle 9 moved its public API into
  # lib/api/ inside the distribution, and `gradle 9.7.0-1` ships no lib/api
  # directory at all, so configuring either project dies with:
  #
  #   Cannot find module 'gradle-public-api-legacy' in distribution directory
  #   '/usr/share/java/gradle'.
  #
  # The official distribution does ship it. So: vendor the official Gradle,
  # and rewrite the hardcoded /usr/bin/gradle in each PKGBUILD to point at it.
  # Nothing pacman owns is touched.
  gradle_version=9.7.0
  gradle_sha256=84fbba45c7f4c64abc77460e1c00f541e9f960e3c7ed2538f1ede19eacd873ae
  gradle_home="$HOME/.local/share/gradle-${gradle_version}"

  if [[ ! -x "$gradle_home/bin/gradle" ]]; then
    echo "==> Vendoring Gradle ${gradle_version} (Arch's package cannot build these)"
    gradle_zip="$(mktemp -d)/gradle.zip"
    if curl -fsSL -o "$gradle_zip" \
      "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip" &&
      echo "${gradle_sha256}  ${gradle_zip}" | sha256sum -c --quiet -; then
      mkdir -p "$HOME/.local/share"
      unzip -q -o "$gradle_zip" -d "$HOME/.local/share"
    else
      echo "!! could not fetch or verify Gradle ${gradle_version}"
    fi
    rm -rf "$(dirname "$gradle_zip")"
  fi

  # Build one AUR package from a PKGBUILD patched to use the vendored Gradle.
  #
  # Two details that are not obvious and that cost an afternoon each:
  #  * GRADLE_HOME must be set explicitly. /etc/profile.d/gradle.sh exports it
  #    as /usr/share/java/gradle, and the official launcher honours it -- so
  #    without this the vendored Gradle politely uses the broken tree anyway.
  #  * --no-daemon, because a daemon already started from Arch's distribution
  #    is reused across builds and fails exactly the same way.
  build_with_vendored_gradle() {
    local pkg="$1"
    local builddir="$HOME/.cache/dotfiles/aur/$pkg"

    pacman -Q "$pkg" >/dev/null 2>&1 && return 0
    [[ -x "$gradle_home/bin/gradle" ]] || return 1

    rm -rf "$builddir"
    mkdir -p "$(dirname "$builddir")"
    git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$builddir" || return 1

    sed -i "s|/usr/bin/gradle|env GRADLE_HOME=\"${gradle_home}\" \"${gradle_home}/bin/gradle\" --no-daemon|" \
      "$builddir/PKGBUILD"
    # If upstream stops calling /usr/bin/gradle the substitution is a no-op and
    # the build would silently use the broken one. Fail loudly instead.
    grep -q "${gradle_home}/bin/gradle" "$builddir/PKGBUILD" || {
      echo "!! ${pkg}: PKGBUILD no longer calls /usr/bin/gradle; patch needs revisiting"
      return 1
    }

    (cd "$builddir" && makepkg -si --noconfirm --needed)
  }

  for pkg in limine-mkinitcpio-hook limine-snapper-sync; do
    try "AUR: $pkg" build_with_vendored_gradle "$pkg"
  done

  if pacman -Q limine-snapper-sync >/dev/null 2>&1; then
    # Both limine tools and the `snapshot` command must agree on where the ESP
    # is, so the detected value is written into both configs rather than
    # auto-detected separately by each of them.
    sed -e "s|@@ESP_PATH@@|${esp_path}|" \
      "$DOTFILES/snapshots/limine-snapper-sync.conf" |
      sudo install -m 644 -o root -g root /dev/stdin /etc/limine-snapper-sync.conf

    # A read-only snapshot cannot be booted by a system that expects to write
    # to /, so btrfs-overlayfs gives it a writable overlay. Derived from the
    # live HOOKS rather than shipped as a fixed line, so it composes with
    # whatever else a given machine needs, and re-running is idempotent.
    #
    # kms is dropped on NVIDIA machines only. The hook pulls the in-tree
    # nouveau driver's firmware into the early CPIO -- GSP blobs for every
    # chip, ~107 MiB of it -- which is dead weight when the proprietary driver
    # is in use, and it is charged against the ESP once per kernel generation
    # that limine-snapper-sync has to keep. On amdgpu/intel, early KMS is
    # wanted and the firmware is a fraction of the size, so it stays.
    hooks="$(sed -nE 's/^HOOKS=\((.*)\)$/\1/p' /etc/mkinitcpio.conf | tail -1)"
    # One package at a time: `pacman -Q a b c` exits non-zero when *any* of them
    # is missing, so querying the whole list at once would never match.
    drop_kms=no
    for driver in nvidia-open-dkms nvidia-open nvidia-dkms nvidia; do
      pacman -Qq "$driver" >/dev/null 2>&1 && drop_kms=yes && break
    done
    new_hooks=""
    for hook in $hooks; do
      [[ "$hook" == "kms" && "$drop_kms" == "yes" ]] && continue
      [[ "$hook" == "btrfs-overlayfs" ]] && continue
      new_hooks+="$hook "
      [[ "$hook" == "filesystems" ]] && new_hooks+="btrfs-overlayfs "
    done
    sudo mkdir -p /etc/mkinitcpio.conf.d
    sudo tee /etc/mkinitcpio.conf.d/btrfs-snapshots.conf >/dev/null <<HOOKSCONF
# Managed by dotfiles/install.sh -- see snapshots/README.md
# Derived from HOOKS in /etc/mkinitcpio.conf; re-run install.sh to regenerate.
HOOKS=(${new_hooks% })
HOOKSCONF

    # Writing the drop-in changes nothing until the images are rebuilt: the
    # running initramfs keeps whatever HOOKS it was born with, so without this
    # a read-only snapshot has no btrfs-overlayfs to give it a writable layer
    # and the ESP keeps paying for firmware nobody loads. Regenerating also
    # fires limine-mkinitcpio-hook, which is what puts the kernel entries in
    # limine.conf in the first place.
    try "regenerate initramfs" sudo mkinitcpio -P

    # The kernel command line, built from the running system. A committed
    # PARTUUID would boot the wrong disk on the next machine.
    root_uuid="$(findmnt -no UUID /)"
    root_subvol="$(findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's/^subvol=\/\?//p' | head -1)"
    # Everything the running kernel was given except what the bootloader
    # supplies itself -- so zswap.enabled=0 and friends survive the migration.
    extra_cmdline="$(tr ' ' '\n' </proc/cmdline |
      grep -vE '^(BOOT_IMAGE|initrd|root|rootflags|rootfstype|ro|rw)(=|$)' |
      tr '\n' ' ' | sed 's/ *$//')"
    cmdline="rw root=UUID=${root_uuid} rootfstype=btrfs rootflags=subvol=${root_subvol}${extra_cmdline:+ $extra_cmdline}"

    sed -e "s|@@CMDLINE@@|${cmdline}|" -e "s|@@ESP_PATH@@|${esp_path}|" \
      "$DOTFILES/snapshots/limine-entry-tool.conf" |
      sudo install -m 644 -o root -g root /dev/stdin /etc/limine-entry-tool.conf

    # Writes the boot entries and installs the EFI binary. Non-fatal: a machine
    # whose ESP is somewhere unexpected should report that and carry on rather
    # than take the whole install down.
    try "limine boot entries" sudo limine-update

    sudo systemctl enable limine-snapper-sync.service
  fi

  fi

  # grub-btrfs was this repo's previous answer, and on an archinstall layout it
  # never worked: the bootloader is not GRUB, so grub-btrfsd regenerated a
  # grub.cfg that nothing read. Removed rather than left running, and `grub`
  # goes with it -- but only when it was an orphaned dependency, which `-Rns`
  # decides. On a machine that really does boot GRUB, grub-btrfs is doing its
  # job and both stay: that is the same machine the guard above left alone.
  if [[ "$grub_is_live" != "yes" ]] && pacman -Q grub-btrfs >/dev/null 2>&1; then
    echo "==> Removing grub-btrfs (superseded by limine-snapper-sync)"
    sudo systemctl disable --now grub-btrfsd.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/grub-btrfsd.service
    try "remove grub-btrfs" sudo pacman -Rns --noconfirm grub-btrfs
  fi
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

aur_packages=(
  ghostty
  rtl8188gu-dkms-git
  hunk-bin
  herdr-bin
  gh-dash-bin
  ttf-joypixels # the colour emoji font, and what gen-emoji-data.py checks coverage against
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
# FINGERPRINT READER                                       #
############################################################

# Unlocks hyprlock and nothing else. hyprlock speaks to fprintd over DBus
# rather than through PAM, so none of this touches /etc/pam.d and sddm, sudo
# and a TTY login keep asking for the password -- README section 17 for why
# that split is the point rather than an oversight.
#
# Written to survive meeting a reader that is not this ThinkPad's. `fprintd` is
# the part that is always right: it owns the DBus name hyprlock talks to, and
# libfprint behind it drives most readers on the market. So it goes on first,
# and then *it* is asked whether it found anything -- a better oracle than any
# table of USB ids kept here, because it covers sensors that never appear in
# `lsusb` at all (the SPI ones) and it stays correct as libfprint gains
# drivers between releases.
#
# Only when the daemon comes up empty does the machine-specific part begin, and
# that is one `case` arm per family libfprint cannot drive. Teaching this
# script a new reader is adding an arm. A reader that matches none of them is
# reported by id and left for a human rather than silently doing nothing --
# see README section 17, which is where the families are written down.
echo "==> Installing fingerprint reader support"

# "found 1 devices" from the client is the whole test, and it is deliberately
# the client rather than a probe of our own: it asks the same daemon over the
# same bus that hyprlock will, so a yes here means the lock screen will work.
#
# Captured into a variable and matched, rather than piped into `grep -q`: this
# script runs under `set -o pipefail`, and `grep -q` exits at the first match,
# which kills fprintd-list with SIGPIPE and hands the pipeline a 141. The test
# then reports "no reader" on exactly the machines where there is one.
fingerprint_reader_ready() {
  local listing
  listing="$(fprintd-list "$USER" 2>/dev/null || true)"
  grep -qE '^found [1-9]|^Device at ' <<<"$listing"
}

# The USB id of an attached reader as "vvvv:pppp", or nothing.
#
# libfprint ships a hwdb naming every device any of its drivers claims -- 400
# odd ids, regenerated on each upgrade -- which is a far better list than one
# maintained here, and it is already on disk because fprintd pulled libfprint
# in. It answers "is this thing a fingerprint reader" even for the devices
# libfprint turns out not to actually drive, which is precisely the case this
# function exists to name. The product-string match is the fallback for a
# sensor too new to be in it.
fingerprint_reader_id() {
  local hwdb=/usr/lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb
  local id name vid pid

  command -v lsusb >/dev/null || return 1

  while read -r _ _ _ _ _ id name; do
    vid=${id%:*}
    pid=${id#*:}
    # -i because the hwdb writes ids in uppercase and lsusb in lowercase.
    if [[ -r $hwdb ]] && grep -qiE "^usb:v${vid}p${pid}\*" "$hwdb"; then
      echo "$id"
      return 0
    fi
    if [[ $name == *[Ff]inger* || $name == *[Bb]iometric* ]]; then
      echo "$id"
      return 0
    fi
  done < <(lsusb 2>/dev/null)

  return 1
}

# Unconditionally, even on a machine with no reader at all -- 900 KiB that
# never runs, against a hardware probe that would have to happen before the
# library that knows what the hardware is. The exception is a machine already
# on a replacement for it: open-fprintd's client package conflicts with
# fprintd, so a re-run must not try to put it back.
if ! pacman -Q fprintd-clients-git >/dev/null 2>&1; then
  pac fprintd
fi

if fingerprint_reader_ready; then
  echo "==> Fingerprint reader is answering, nothing more to install"
else
  fp_id="$(fingerprint_reader_id || true)"

  case "$fp_id" in
  138a:0090 | 138a:0097 | 06cb:009a)
    # The Validity 009x family, 06cb:009a being the one in this T480. libfprint
    # does carry a vfs7552 driver that claims these ids, and it does not work:
    # the sensor is enumerated by nobody and fprintd answers `fprintd-enroll`
    # with "No devices available". uunicorn's pair is what drives them --
    # python-validity as the driver, open-fprintd as a drop-in for the daemon,
    # same DBus name, so hyprlock never learns the difference.
    echo "==> Validity 009x sensor ($fp_id), installing python-validity"

    # fprintd-clients-git named explicitly because it is the package carrying
    # the conflict with fprintd: naming it makes the replacement part of this
    # transaction rather than something yay discovers halfway through.
    try "AUR: validity fingerprint stack" yay -S --needed --noconfirm \
      fprintd-clients-git open-fprintd python-validity

    # python-validity's udev rule starts the driver when the sensor appears,
    # but a machine that booted with it already attached gets no add event,
    # which is every boot -- so the unit is enabled too. open-fprintd itself is
    # Type=dbus and deliberately not enabled: the first call activates it.
    try "fingerprint driver" sudo systemctl enable --now python3-validity.service

    # This laptop suspends itself on battery (hypr/scripts/lid.sh), and a
    # Validity sensor comes back from suspend dead until the driver *and* the
    # daemon are restarted -- open-fprintd's own resume.py only re-opens
    # devices, so the AUR package's hotfix unit is the half that matters. No
    # --now on any of them: they are sleep hooks, and starting one now would
    # fire its restart at install time for nothing.
    try "fingerprint sleep hooks" sudo systemctl enable \
      open-fprintd-suspend.service \
      open-fprintd-resume.service \
      python3-validity-suspend-hotfix.service

    # The driver brings the sensor up over USB before the daemon has a device
    # to hand out, and on a cold machine that takes a few seconds -- asking the
    # instant after `enable --now` reports a failure that fixes itself while
    # you read it.
    for _ in {1..10}; do
      if fingerprint_reader_ready; then break; fi
      sleep 2
    done

    fingerprint_reader_ready ||
      FAILED+=("fingerprint: $fp_id still silent after python-validity, see README section 17")
    ;;
  "")
    echo "==> No fingerprint reader found, nothing more to install"
    ;;
  *)
    # Attached, recognisably a reader, and libfprint will not drive it. The
    # driver depends on the family -- Goodix wants libfprint-2-tod plus a
    # per-model blob, Egis wants something else again -- and guessing wrong
    # installs a proprietary driver for the wrong sensor, so this stops and
    # says so. Appended to FAILED directly rather than through try(): nothing
    # ran and failed, but this belongs in the same summary at the end, which is
    # the one place anybody reads.
    echo "!! Fingerprint reader $fp_id is attached and libfprint cannot drive it."
    echo "   README section 17 lists the families and what each one needs."
    FAILED+=("fingerprint: $fp_id needs a driver this script has no arm for, see README section 17")
    ;;
  esac
fi

# Enrolling is manual on every path and has to be: it writes per-user biometric
# templates and needs the finger in the room. `fprintd-enroll`, README
# section 17.

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
  btop fastfetch ghostty git hunk hypr lazygit nvim scripts sounds \
  quickshell tensaku wallpapers yazi zsh
stow \
  btop \
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
  wallpapers \
  yazi \
  zsh

# The wallpaper is addressed through one stable path, ~/.local/state/hypr/wallpaper,
# which hyprland.conf exports as $ACTIVE_WALLPAPER_PATH and both hyprpaper and
# hyprlock read. The link is runtime state and deliberately not in the repo --
# it is what the quickshell picker retargets when a wallpaper is chosen -- so a
# fresh machine has to be given one, and only a fresh machine: a link that is
# already there points at whatever was last picked and must survive a re-run.
# Repointed rather than left alone when it dangles, which is what a wallpaper
# deleted from the repo leaves behind.
if [[ ! -e "$HOME/.local/state/hypr/wallpaper" ]]; then
  mkdir -p "$HOME/.local/state/hypr"
  ln -sfn "$HOME/.config/wallpapers/Pablo Garcia Saldana.jpg" \
    "$HOME/.local/state/hypr/wallpaper"
fi

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
# launcher by name. --no-folding so that ~/.local/share/applications stays a real
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
