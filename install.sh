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

############################################################
# DIRECTORY STRUCTURE                                      #
############################################################

echo "==> Creating directories"
mkdir -p \
  "$HOME/Downloads" \
  "$HOME/Pictures/Screenshots"

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
# CORE SYSTEM TOOLS                                        #
############################################################

echo "==> Installing core tools"
sudo pacman -Syu --needed --noconfirm \
  base-devel \
  git \
  sudo \
  curl \
  fcitx5 \
  fastfetch \
  nerd-fonts \
  stow

############################################################
# AUR HELPER (yay)                                         #
############################################################

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay (yay-bin)"

  sudo pacman -S --needed --noconfirm base-devel git

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
# HYPRLAND + WAYLAND STACK + WAYBAR                        #
############################################################

echo "==> Installing Hyprland and Wayland stack"

sudo pacman -S --needed --noconfirm \
  hyprland \
  wayland \
  xorg-xwayland \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  qt5-wayland \
  qt6-wayland \
  pipewire \
  wireplumber \
  grim \
  slurp \
  polkit \
  polkit-gnome \
  waybar \
  mako

############################################################
# DISPLAY MANAGER (SDDM)                                   #
############################################################

echo "==> Installing and enabling SDDM"

sudo chmod o+x /home
sudo chmod o+x /home/danilolucasmd
sudo chmod o+x ~/dotfiles
sudo chmod o+x ~/dotfiles/sddm
sudo chmod o+x ~/dotfiles/sddm/usr
sudo chmod o+x ~/dotfiles/sddm/usr/share
sudo chmod o+x ~/dotfiles/sddm/usr/share/sddm
sudo chmod o+x ~/dotfiles/sddm/usr/share/sddm/themes
sudo chmod o+x ~/dotfiles/sddm/usr/share/sddm/themes/minimal-input

sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm

############################################################
# CORE / DEV / CLI PACKAGES                                #
############################################################

echo "==> Installing pacman packages"

sudo pacman -S --needed --noconfirm \
  stow \
  tmux \
  neovim \
  lazygit \
  fzf \
  ripgrep \
  fd \
  wl-clipboard \
  wf-recorder \
  unzip \
  yazi \
  ffmpeg \
  p7zip \
  jq \
  poppler \
  zoxide \
  imagemagick \
  hyprpaper \
  hyprlock \
  hypridle \
  hyprshot \
  hyprpicker \
  nautilus \
  sushi \
  gvfs-mtp \
  pika-backup \
  adw-gtk-theme \
  qt5ct \
  qt6ct \
  kdeconnect

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

sudo pacman -S --needed --noconfirm \
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

sudo pacman -S --needed --noconfirm \
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
# AUR PACKAGES                                             #
############################################################

echo "==> Installing AUR packages"

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

yay -S --needed --noconfirm \
  ghostty \
  rtl8188gu-dkms-git \
  hunk-bin \
  herdr-bin \
  elephant-bin \
  elephant-desktopapplications-bin \
  elephant-clipboard-bin \
  walker-bin \
  ttf-joypixels \
  1password \
  brave-bin \
  orca-slicer-bin \
  bluetui \
  wiremix \
  btop \
  localsend-bin

############################################################
# NODE SETUP                                               #
############################################################

echo "==> Installing Node.js and packages"

sudo pacman -S --needed --noconfirm nodejs npm
sudo npm install -g tree-sitter-cli

############################################################
# SYSTEM DOTFILES                                          #
############################################################

echo "==> Applying system dotfiles"
cd "$HOME/dotfiles"
sudo stow -t / sddm

############################################################
# USER DOTFILES                                            #
############################################################

echo "==> Applying user dotfiles"
stow \
  elephant \
  ghostty \
  herdr \
  hypr \
  mako \
  nvim \
  sounds \
  steam \
  tmux \
  walker \
  wallpapers \
  waybar \
  yazi \
  zsh

############################################################
# ZSH + on-my-zsh                                          #
############################################################

sudo pacman -S --needed --noconfirm zsh

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
# Nvidia drivers                                           #
############################################################

sudo pacman -S --needed --noconfirm \
  nvidia-dkms \
  nvidia-utils \
  lib32-nvidia-utils \
  egl-wayland \
  nvidia-settings

############################################################
# FILE PERMISSIONS                                         #
############################################################

echo "==> Fixing executable permissions"

chmod +x \
  "$HOME/.config/waybar/scripts/mic.sh" \
  "$HOME/.config/sounds/scripts/toggle-mic.sh" \
  "$HOME/.config/scripts/screen-record.sh"

############################################################
# DEFAULT APPLICATIONS                                     #
############################################################

echo "==> Setting default applications"
xdg-mime default ghostty.desktop inode/directory
chsh -s /bin/zsh

############################################################
# BRAVE WEB APPS                                           #
############################################################

# Generate toolbar-free Brave web-app launchers (--app=URL)
# from webapps/apps.conf. See webapps/README.md.
echo "==> Generating Brave web app launchers"
"$HOME/dotfiles/webapps/generate.sh"

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
echo " Setup complete."
echo " Reboot and log into the Hyprland session."
echo " Review README.md for remaining manual steps."
echo "========================================================"
