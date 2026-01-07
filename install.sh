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
  waybar

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
  pika-backup \
  adw-gtk-theme \
  qt5ct \
  qt6ct

############################################################
# AUR PACKAGES                                             #
############################################################

echo "==> Installing AUR packages"

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

yay -S --needed --noconfirm \
  ghostty \
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
  btop

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
  hypr \
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
  "$HOME/.config/sounds/scripts/toggle-mic.sh"

############################################################
# DEFAULT APPLICATIONS                                     #
############################################################

echo "==> Setting default applications"
xdg-mime default ghostty.desktop inode/directory
chsh -s /bin/zsh

############################################################
# GIT CONFIGURATION                                        #
############################################################

echo "==> Configuring git"

git config --global core.editor nvim
git config --global pull.rebase false
git config --global user.name "Danilo de Lucas"
git config --global user.email "danilolucasmd@gmail.com"

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
